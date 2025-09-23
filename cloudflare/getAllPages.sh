#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${MY_CLOUDFLARE_ACCOUNT_ID}"
TOKEN="${MY_CLOUDFLARE_API_TOKEN}"
BASE="https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects"

echo "🔎 Discovering total_pages (using default page size)..."
FIRST_PAGE_JSON=$(
  curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$BASE?page=1"
)

SUCCESS=$(jq -r '.success' <<<"$FIRST_PAGE_JSON")
if [[ "$SUCCESS" != "true" ]]; then
  echo "❌ Discovery call failed:" >&2
  echo "$FIRST_PAGE_JSON" | jq >&2
  exit 1
fi

TOTAL_PAGES=$(jq -r '.result_info.total_pages' <<<"$FIRST_PAGE_JSON")
TOTAL_COUNT=$(jq -r '.result_info.total_count' <<<"$FIRST_PAGE_JSON")
if [[ "$TOTAL_PAGES" == "null" || "$TOTAL_COUNT" == "null" ]]; then
  echo "❌ Could not read pagination info:" >&2
  echo "$FIRST_PAGE_JSON" | jq >&2
  exit 1
fi

echo "✅ total_count=$TOTAL_COUNT • total_pages=$TOTAL_PAGES (page size = default)"
echo "— Fetching all project names —"
echo "📄 Page 1/$TOTAL_PAGES..."
jq -r '.result[]?.name // empty' <<<"$FIRST_PAGE_JSON"

for page in $(seq 2 "$TOTAL_PAGES"); do
  echo "📄 Page $page/$TOTAL_PAGES..."
  PAGE_JSON=$(
    curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      "$BASE?page=$page"
  )
  SUCCESS=$(jq -r '.success' <<<"$PAGE_JSON")
  if [[ "$SUCCESS" != "true" ]]; then
    echo "❌ Error on page $page:" >&2
    echo "$PAGE_JSON" | jq >&2
    exit 1
  fi
  jq -r '.result[]?.name // empty' <<<"$PAGE_JSON"
done

echo "🎉 Done. Listed $TOTAL_COUNT Pages projects."
