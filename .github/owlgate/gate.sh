#!/usr/bin/env bash
#
# OwlGate release gate — called by .github/workflows/owlgate-gate.yml.
# Sends the PR diff to the OwlGate coded agent on UiPath, waits for the verdict,
# and exits non-zero on a no-go (so the PR check fails and the merge is blocked).
#
# Uses the folder id + release key directly so the only scope needed is OR.Jobs
# (no OR.Folders.Read / OR.Execution.Read). Update UIPATH_RELEASE_KEY if you
# redeploy the agent. Inputs: $1 = diff json like {"diff":[{"path":..,"lines":..}]}.
#
set -euo pipefail

DIFF_FILE="${1:?usage: gate.sh <diff.json>}"
: "${UIPATH_CLIENT_ID:?missing UIPATH_CLIENT_ID}"
: "${UIPATH_CLIENT_SECRET:?missing UIPATH_CLIENT_SECRET}"
BASE="${UIPATH_BASE:-https://staging.uipath.com}"
ACCT="${UIPATH_ACCOUNT:?missing UIPATH_ACCOUNT}"
TEN="${UIPATH_TENANT:?missing UIPATH_TENANT}"
FOLDER_ID="${UIPATH_FOLDER_ID:?missing UIPATH_FOLDER_ID}"
RKEY="${UIPATH_RELEASE_KEY:?missing UIPATH_RELEASE_KEY}"
SCOPE="${UIPATH_SCOPE:-OR.Jobs}"
ORCH="$BASE/$ACCT/$TEN/orchestrator_"

# curl that captures body + HTTP status; on >=400 it prints the UiPath error.
req() { # req DESC METHOD URL [json-body]
  local desc="$1" method="$2" url="$3" data="${4:-}"
  local args=(-sS -w $'\n%{http_code}' -X "$method" "$url" "${HDR[@]}")
  [ -n "$data" ] && args+=(-H "Content-Type: application/json" -d "$data")
  local resp code body
  resp=$(curl "${args[@]}")
  code=$(printf '%s' "$resp" | tail -n1)
  body=$(printf '%s' "$resp" | sed '$d')
  if [ "$code" -ge 400 ] 2>/dev/null; then
    echo "::error::OwlGate $desc failed (HTTP $code): $(printf '%s' "$body" | head -c 400)"
    exit 1
  fi
  printf '%s' "$body"
}

# 1. authenticate (client credentials — secrets go in the form body, never the URL)
resp=$(curl -sS -w $'\n%{http_code}' "$BASE/identity_/connect/token" \
  -d grant_type=client_credentials \
  --data-urlencode "client_id=$UIPATH_CLIENT_ID" \
  --data-urlencode "client_secret=$UIPATH_CLIENT_SECRET" \
  --data-urlencode "scope=$SCOPE")
code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')
[ "$code" = "200" ] || { echo "::error::auth failed (HTTP $code): $(printf '%s' "$body" | head -c 300)"; exit 1; }
TOKEN=$(printf '%s' "$body" | jq -r '.access_token // empty')
[ -n "$TOKEN" ] || { echo "::error::no access_token returned"; exit 1; }
HDR=(-H "Authorization: Bearer $TOKEN" -H "X-UIPATH-OrganizationUnitId: $FOLDER_ID")
echo "authenticated"

# 2. build the agent input: the diff + (if present) this app's test catalogue,
#    so file→suite risk mapping (incl. the high-severity `auth` suite) travels with
#    the request — no agent redeploy needed when the catalogue changes.
CAT_FILE="${UIPATH_CATALOGUE_FILE:-owlgate-catalogue.json}"
if [ -f "$CAT_FILE" ]; then
  INPUT_JSON=$(jq -c --slurpfile c "$CAT_FILE" '. + {catalogue: $c[0].suites}' "$DIFF_FILE")
  echo "using catalogue $CAT_FILE ($(jq '.suites | length' "$CAT_FILE") suites)"
else
  INPUT_JSON=$(jq -c . "$DIFF_FILE")
fi

# start the gate job, passing the input as a JSON string
START_BODY=$(jq -n --arg rk "$RKEY" --arg input "$INPUT_JSON" \
  '{startInfo:{ReleaseKey:$rk,Strategy:"ModernJobsCount",JobsCount:1,InputArguments:$input}}')
JID=$(req "start-job" POST "$ORCH/odata/Jobs/UiPath.Server.Configuration.OData.StartJobs" "$START_BODY" | jq -r '.value[0].Id // empty')
[ -n "$JID" ] || { echo "::error::no job id returned"; exit 1; }
echo "started job $JID — waiting for the verdict..."

# 3. poll until terminal
STATE=""; JOB="{}"
for _ in $(seq 1 60); do
  JOB=$(req "read-job" GET "$ORCH/odata/Jobs($JID)")
  STATE=$(printf '%s' "$JOB" | jq -r '.State')
  if [[ "$STATE" =~ ^(Successful|Faulted|Stopped)$ ]]; then break; fi
  sleep 5
done

if [ "$STATE" != "Successful" ]; then
  echo "::error::job did not succeed (state=$STATE): $(printf '%s' "$JOB" | jq -r '.Info // empty')"
  exit 1
fi

# 4. read the verdict and gate the PR
OUT=$(printf '%s' "$JOB" | jq -r '.OutputArguments // "{}"')
VERDICT=$(printf '%s' "$OUT" | jq -r '.verdict // "unknown"')
NEEDS=$(printf '%s' "$OUT" | jq -r '.needs_human // false')
echo "OwlGate verdict: $VERDICT  (needs_human=$NEEDS)"

# The exact code OwlGate wants a human to look at (function + line range).
TARGETS=$(printf '%s' "$OUT" | jq -r '.report.risk.review_targets // [] | .[] | "  • \(.function)  [\(.file):\(.lines)]"')
if [ -n "$TARGETS" ]; then
  echo "Review these:"
  printf '%s\n' "$TARGETS"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo "### 🦉 OwlGate — code to review"; printf '%s\n' "$TARGETS" | sed 's/^  • /- /'; } >> "$GITHUB_STEP_SUMMARY"
  fi
fi

if [ "$VERDICT" = "go" ] && [ "$NEEDS" != "true" ]; then
  echo "✅ OwlGate: GO — safe to merge."
  exit 0
fi
echo "❌ OwlGate: $VERDICT (needs_human=$NEEDS) — blocking this PR."
exit 1
