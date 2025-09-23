#!/usr/bin/env bash
# List Cloudflare Workers matching a substring via API (not Wrangler)

# Required:
#   MY_CLOUDFLARE_ACCOUNT_ID
#   MY_CLOUDFLARE_API_TOKEN  (needs Workers Scripts: Read)
# Optional:
#   MY_WORKER_NAME  (substring to match, default "bff-")
#   OUTPUT_FILE     (default /tmp/<name>.json)

set -euo pipefail

: "${MY_CLOUDFLARE_ACCOUNT_ID:?Missing MY_CLOUDFLARE_ACCOUNT_ID}"
: "${MY_CLOUDFLARE_API_TOKEN:?Missing MY_CLOUDFLARE_API_TOKEN}"

#MY_WORKER_NAME="${MY_WORKER_NAME:-bff-}"
MY_WORKER_NAME="request-handler-staging"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/${MY_WORKER_NAME}.json}"

API="https://api.cloudflare.com/client/v4"
PAGE=1
PER_PAGE=100
TMP="$(mktemp)"

echo "🔎 Listing Workers in account ${MY_CLOUDFLARE_ACCOUNT_ID} matching: ${MY_WORKER_NAME}"
> "$TMP"

while : ; do
  RESP="$(curl -sS -H "Authorization: Bearer ${MY_CLOUDFLARE_API_TOKEN}" \
               -H "Content-Type: application/json" \
               "${API}/accounts/${MY_CLOUDFLARE_ACCOUNT_ID}/workers/scripts?page=${PAGE}&per_page=${PER_PAGE}")"

 echo "This is the raw curl command with secrets exposed:"
  echo "curl -sS -H \"Authorization: Bearer ${MY_CLOUDFLARE_API_TOKEN}\" \\
               -H \"Content-Type: application/json\" \\
               \"${API}/accounts/${MY_CLOUDFLARE_ACCOUNT_ID}/workers/scripts?page=${PAGE}&per_page=${PER_PAGE}\""
  # Break on API error
  echo "$RESP" | jq -e '.success == true' >/dev/null || { echo "$RESP" | jq; exit 1; }

  # Append results; stop when empty
  COUNT=$(echo "$RESP" | jq '.result | length')
  if [[ "$COUNT" -eq 0 ]]; then break; fi
  echo "$RESP" | jq '.result[]' >> "$TMP"
  (( PAGE++ ))
done

# Build final JSON array and filter by substring
jq -s "[.[] | select(.id | contains(\"${MY_WORKER_NAME}\"))]" "$TMP" | tee "$OUTPUT_FILE" | jq
rm -f "$TMP"

echo "📄 Saved to: $OUTPUT_FILE"
