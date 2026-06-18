#!/usr/bin/env bash
#
# OwlGate release gate — called by .github/workflows/owlgate-gate.yml.
# Sends the PR diff to the OwlGate coded agent on UiPath, waits for the verdict,
# and exits non-zero on a no-go (so the PR check fails and the merge is blocked).
#
# Inputs: $1 = path to a JSON file shaped like {"diff":[{"path":..,"lines":..}]}
# Env (from the workflow):
#   UIPATH_CLIENT_ID / UIPATH_CLIENT_SECRET  (GitHub secrets)
#   UIPATH_BASE / UIPATH_ACCOUNT / UIPATH_TENANT / UIPATH_FOLDER / UIPATH_PROCESS / UIPATH_SCOPE
#
set -euo pipefail

DIFF_FILE="${1:?usage: gate.sh <diff.json>}"
: "${UIPATH_CLIENT_ID:?missing UIPATH_CLIENT_ID}"
: "${UIPATH_CLIENT_SECRET:?missing UIPATH_CLIENT_SECRET}"
BASE="${UIPATH_BASE:-https://staging.uipath.com}"
ACCT="${UIPATH_ACCOUNT:?missing UIPATH_ACCOUNT}"
TEN="${UIPATH_TENANT:?missing UIPATH_TENANT}"
FOLDER="${UIPATH_FOLDER:-Shared}"
PROCESS="${UIPATH_PROCESS:-owlgate-gate}"
SCOPE="${UIPATH_SCOPE:-OR.Jobs}"
ORCH="$BASE/$ACCT/$TEN/orchestrator_"

die() { echo "::error::OwlGate gate: $*"; exit 1; }

echo "::group::Authenticate (client credentials)"
TOKEN=$(curl -sf "$BASE/identity_/connect/token" \
  -d grant_type=client_credentials \
  -d client_id="$UIPATH_CLIENT_ID" \
  -d client_secret="$UIPATH_CLIENT_SECRET" \
  -d scope="$SCOPE" | jq -r '.access_token // empty') \
  || die "token request failed (check the identity URL / app credentials)"
[ -n "$TOKEN" ] || die "no access_token returned (check the app's Application scopes)"
AUTH=(-H "Authorization: Bearer $TOKEN")
echo "authenticated"
echo "::endgroup::"

# Resolve the Shared folder id (needed as the OrganizationUnit header).
FID=$(curl -sf -G "${AUTH[@]}" "$ORCH/odata/Folders" \
  --data-urlencode "\$filter=FullyQualifiedName eq '$FOLDER'" \
  | jq -r '.value[0].Id // empty') || die "could not list folders (token scope?)"
[ -n "$FID" ] || die "folder '$FOLDER' not found"
FH=(-H "X-UIPATH-OrganizationUnitId: $FID")

# Resolve the release key for the process by name (robust to redeploys).
RKEY=$(curl -sf -G "${AUTH[@]}" "${FH[@]}" "$ORCH/odata/Releases" \
  --data-urlencode "\$filter=Name eq '$PROCESS'" \
  | jq -r '.value[0].Key // empty') || die "could not list releases"
[ -n "$RKEY" ] || die "process '$PROCESS' not found in '$FOLDER' (is it deployed?)"

# Start the job, passing the diff as the agent's input arguments (a JSON string).
BODY=$(jq -n --arg rk "$RKEY" --arg input "$(jq -c . "$DIFF_FILE")" \
  '{startInfo:{ReleaseKey:$rk,Strategy:"ModernJobsCount",JobsCount:1,InputArguments:$input}}')
JID=$(curl -sf "${AUTH[@]}" "${FH[@]}" -H "Content-Type: application/json" \
  -X POST "$ORCH/odata/Jobs/UiPath.Server.Configuration.OData.StartJobs" \
  -d "$BODY" | jq -r '.value[0].Id // empty') || die "StartJobs failed"
[ -n "$JID" ] || die "no job id returned from StartJobs"
echo "started job $JID — waiting for the verdict..."

# Poll until the job reaches a terminal state.
STATE=""
J="{}"
for _ in $(seq 1 60); do
  J=$(curl -sf "${AUTH[@]}" "${FH[@]}" "$ORCH/odata/Jobs($JID)") || die "could not read job"
  STATE=$(echo "$J" | jq -r '.State')
  if [[ "$STATE" =~ ^(Successful|Faulted|Stopped)$ ]]; then break; fi
  sleep 5
done

[ "$STATE" = "Successful" ] || die "job did not succeed (state=$STATE)"

OUT=$(echo "$J" | jq -r '.OutputArguments // "{}"')
VERDICT=$(echo "$OUT" | jq -r '.verdict // "unknown"')
NEEDS=$(echo "$OUT" | jq -r '.needs_human // false')
echo "OwlGate verdict: $VERDICT  (needs_human=$NEEDS)"

if [ "$VERDICT" = "go" ] && [ "$NEEDS" != "true" ]; then
  echo "✅ OwlGate: GO — safe to merge."
  exit 0
fi
echo "❌ OwlGate: $VERDICT (needs_human=$NEEDS) — blocking this PR."
exit 1
