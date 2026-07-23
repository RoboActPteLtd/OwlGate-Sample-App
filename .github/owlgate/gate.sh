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
#
#    `escalate: true` asks the agent to record a durable human-approval request when
#    the verdict needs sign-off. Without it the agent returns "skipped: escalation
#    disabled" and a held PR leaves no approval record anywhere — the merge is blocked
#    but nobody is actually asked to decide. The agent only escalates when
#    needs_human is true, so this is a no-op for a clean PR.
CAT_FILE="${UIPATH_CATALOGUE_FILE:-owlgate-catalogue.json}"
if [ -f "$CAT_FILE" ]; then
  INPUT_JSON=$(jq -c --slurpfile c "$CAT_FILE" '. + {catalogue: $c[0].suites, escalate: true}' "$DIFF_FILE")
  echo "using catalogue $CAT_FILE ($(jq '.suites | length' "$CAT_FILE") suites)"
else
  INPUT_JSON=$(jq -c '. + {escalate: true}' "$DIFF_FILE")
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
# What the agent did about the human gate: "queued" means a durable approval record
# exists in the owlgate-changes queue; "action-center-failed" is expected on tenants
# without the Actions service and is not fatal.
ESCALATION=$(printf '%s' "$OUT" | jq -r '.escalation // "n/a"')
echo "OwlGate verdict: $VERDICT  (needs_human=$NEEDS)"
echo "Human gate: $ESCALATION"

# Decide the outcome before printing anything, because the gate has *three* states,
# not two: a change can be low-risk on its own and still be held for a person. Saying
# "go ... blocking this PR" in that case reads like a bug — name the state instead.
if [ "$VERDICT" = "go" ] && [ "$NEEDS" != "true" ]; then
  ICON="✅"; HEADLINE="GO — safe to merge"; EXIT_CODE=0
  DETAIL="No blocking issues, and no human sign-off required."
elif [ "$NEEDS" = "true" ]; then
  ICON="⏸️"; HEADLINE="HOLD — human sign-off required"; EXIT_CODE=1
  DETAIL="This change touches a high-severity area, so OwlGate will not decide alone. Merge stays blocked until a person approves or overrides. (Risk verdict: \`$VERDICT\`.)"
  case "$ESCALATION" in
    *queued*) DETAIL="$DETAIL"$'\n\n'"An approval record was written to the \`owlgate-changes\` queue in UiPath Orchestrator — that is the request a human acts on." ;;
  esac
else
  ICON="❌"; HEADLINE="NO-GO — blocking"; EXIT_CODE=1
  DETAIL="The gate returned \`$VERDICT\`."
fi

# The exact code OwlGate wants a human to look at (function + line range).
TARGETS=$(printf '%s' "$OUT" | jq -r '.report.risk.review_targets // [] | .[] | "  • \(.function)  [\(.file):\(.lines)]"')
TARGETS_MD=$(printf '%s' "$OUT" | jq -r '.report.risk.review_targets // [] | .[] | "- `\(.function)` — `\(.file):\(.lines)`"')

# Verdict headline first, then the code to review — this block is what a reviewer
# actually reads on the PR page, so lead with the decision.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### $ICON OwlGate: $HEADLINE"
    echo ""
    echo "$DETAIL"
    if [ -n "$TARGETS_MD" ]; then
      echo ""
      echo "**Code to review**"
      echo ""
      printf '%s\n' "$TARGETS_MD"
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ -n "$TARGETS" ]; then
  echo "Review these:"
  printf '%s\n' "$TARGETS"
fi

echo "$ICON OwlGate: $HEADLINE"
exit "$EXIT_CODE"
