#!/usr/bin/env bash
# Manual matchmaking pairing tests (service role — never ship this key in the app).
#
# Usage:
#   export SUPABASE_URL="https://<project-ref>.supabase.co"
#   export SUPABASE_SERVICE_ROLE_KEY="<service_role_jwt>"
#   export MATCH_SEARCH_REQUEST_ID="<uuid>"
#   ./scripts/matchmaking-pair-test.sh
#
# Or pass the UUID as the first argument.

set -euo pipefail

REQ_ID="${1:-${MATCH_SEARCH_REQUEST_ID:-}}"
if [[ -z "${REQ_ID}" ]]; then
  echo "Set MATCH_SEARCH_REQUEST_ID or pass UUID as first argument." >&2
  exit 1
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY." >&2
  exit 1
fi

echo "--- POST matchmaking-pairing (internal / same as DB trigger) ---"
curl -sS -X POST "${SUPABASE_URL}/functions/v1/matchmaking-pairing" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"match_search_request_id\":\"${REQ_ID}\"}" | jq .

echo ""
echo "--- Optional: call RPC directly (Dashboard SQL) ---"
echo "SELECT public.matchmaking_pair_atomic('${REQ_ID}'::uuid);"
