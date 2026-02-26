#!/bin/sh
# deploy-policies.sh — Push .rego policies to OPA via its REST API.
#
# Runs on the Woodpecker CI agent. Hits OPA via its external ingress.
#
# Required env var:
#   OPA_API_TOKEN  — bearer token (from Woodpecker secret)
set -eu

: "${OPA_API_TOKEN:?Set OPA_API_TOKEN}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

OPA_URL="https://opa-api.metosin.net"
AUTH="Authorization: Bearer ${OPA_API_TOKEN}"

POLICIES_DIR="${REPO_ROOT}/policies"

echo "==> Deploying policies to ${OPA_URL}..."

# Iterate over all .rego files and PUT each one
DEPLOYED=0
FAILED=0

find "${POLICIES_DIR}" -name '*.rego' -type f | sort | while IFS= read -r FILE; do
  # Derive policy ID from relative path: policies/mcp/mcp.rego -> mcp/mcp
  REL_PATH="${FILE#${POLICIES_DIR}/}"
  POLICY_ID="${REL_PATH%.rego}"

  echo "    Uploading ${REL_PATH} as ${POLICY_ID}..."

  RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT \
    "${OPA_URL}/v1/policies/${POLICY_ID}" \
    -H "Content-Type: text/plain" \
    -H "${AUTH}" \
    --data-binary "@${FILE}")

  HTTP_STATUS=$(echo "$RESPONSE" | tail -1 | sed 's/HTTP_STATUS://')
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "    -> OK"
  else
    echo "    -> ERROR (HTTP ${HTTP_STATUS}): ${BODY}"
  fi
done

# Verify policies are loaded
echo ""
echo "==> Verifying loaded policies..."
VERIFY=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  "${OPA_URL}/v1/policies" \
  -H "${AUTH}")

HTTP_STATUS=$(echo "$VERIFY" | tail -1 | sed 's/HTTP_STATUS://')
BODY=$(echo "$VERIFY" | sed '$d')

if [ "$HTTP_STATUS" = "200" ]; then
  POLICY_COUNT=$(echo "$BODY" | sed 's/{"id"/\n{"id"/g' | grep -c '"id"' || echo "0")
  echo "    ${POLICY_COUNT} policies loaded in OPA."
else
  echo "    ERROR verifying policies (HTTP ${HTTP_STATUS}): ${BODY}"
  exit 1
fi

echo ""
echo "==> Deploy complete."
