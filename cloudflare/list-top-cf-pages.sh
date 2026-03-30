#!/usr/bin/env bash
set -euo pipefail

if [ -z "${MY_CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  echo "Error: MY_CLOUDFLARE_ACCOUNT_ID is not set" >&2
  exit 1
fi

if [ -z "${MY_CLOUDFLARE_API_TOKEN_READ_ALL:-}" ]; then
  echo "Error: MY_CLOUDFLARE_API_TOKEN_READ_ALL is not set" >&2
  exit 1
fi

echo "==> Fetching Cloudflare Pages projects..."

RESPONSE="$(curl --silent --show-error \
  "https://api.cloudflare.com/client/v4/accounts/$MY_CLOUDFLARE_ACCOUNT_ID/pages/projects" \
  -H "Authorization: Bearer $MY_CLOUDFLARE_API_TOKEN_READ_ALL" \
  -H "Content-Type: application/json")"

SUCCESS="$(echo "$RESPONSE" | jq -r '.success // false')"

if [ "$SUCCESS" != "true" ]; then
  echo "Error: Cloudflare API call failed" >&2
  echo "$RESPONSE" | jq .
  exit 1
fi

TOTAL="$(echo "$RESPONSE" | jq '.result | length')"

echo
echo "==> Total Pages projects left: $TOTAL"
echo
echo "==> Project names:"
echo "$RESPONSE" | jq -r '.result[]?.name'

echo
echo "==> Detailed stocktake:"
echo "$RESPONSE" | jq -r '
  .result[]
  | [
      .name,
      .subdomain,
      (.production_branch // ""),
      (.source.config.owner // ""),
      (.source.config.repo_name // "")
    ]
  | @tsv
' | awk -F '\t' 'BEGIN {
    printf "%-28s %-40s %-20s %-20s %-30s\n", "PROJECT", "SUBDOMAIN", "BRANCH", "OWNER", "REPO"
    printf "%-28s %-40s %-20s %-20s %-30s\n", "-------", "---------", "------", "-----", "----"
  }
  {
    printf "%-28s %-40s %-20s %-20s %-30s\n", $1, $2, $3, $4, $5
  }'