#!/usr/bin/env bash
ACCOUNT_ID="YOUR_ACCOUNT_ID"
TOKEN="YOUR_API_TOKEN"
WORKER="bff-jackpotbets-uat"

page=1
per_page=50

while true; do
  resp=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects?per_page=$per_page&page=$page")

  # Stop if empty or error
  count=$(echo "$resp" | jq '.result | length')
  if [ "$count" -eq 0 ] || [ "$count" == "null" ]; then
    break
  fi

  echo "$resp" | jq -r --arg WORKER "$WORKER" '
    .result[] |
    {
      project: .name,
      prod: .deployment_configs.production.services,
      preview: .deployment_configs.preview.services
    } |
    to_entries[] |
    select(.value != null) |
    .key as $env |
    .value[]? |
    select(.service==$WORKER) |
    "Project=\(.binding) Env=\($env) (service=\(.service))"
  '

  # Move to next page
  page=$((page+1))
done
