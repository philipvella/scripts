#!/bin/bash

# This script needs two environment variables:
# MY_CLOUDFLARE_ACCOUNT_ID | You can find this in your Cloudflare dashboard under "Account Settings".
# MY_CLOUDFLARE_API_TOKEN | You can create this in your Cloudflare dashboard under "API Tokens". Ensure it has permissions for "Pages: Read".

MY_PROJECT_NAME="sportsbook"
OUTPUT_FILE="/tmp/${MY_PROJECT_NAME}.prod.json"

# Ensure required environment variables are set
if [[ -z "$MY_CLOUDFLARE_ACCOUNT_ID" || -z "$MY_CLOUDFLARE_API_TOKEN" ]]; then
  echo "❌ Environment variables MY_CLOUDFLARE_ACCOUNT_ID or MY_CLOUDFLARE_API_TOKEN are not set."
  exit 1
fi

# Fetch the latest production deployment ID
MY_DEPLOYMENT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${MY_CLOUDFLARE_ACCOUNT_ID}/pages/projects/${MY_PROJECT_NAME}/deployments" \
  -H "Authorization: Bearer ${MY_CLOUDFLARE_API_TOKEN}" \
  | jq -r '.result[] | select(.environment == "production") | .id' | head -n 1)

# if MY_DEPLOYMENT_ID is empty, set it to or default to d25686c1-c744-4d55-884a-a0fafef9b165
if [ -z "$MY_DEPLOYMENT_ID" ]; then
  MY_DEPLOYMENT_ID="d25686c1-c744-4d55-884a-a0fafef9b165"
fi

if [ -z "$MY_DEPLOYMENT_ID" ]; then
  echo "❌ No production deployment found for project '$MY_PROJECT_NAME'."
  exit 1
fi

echo "🔁 Running: wrangler pages deployment tail \"$MY_DEPLOYMENT_ID\" --project-name \"$MY_PROJECT_NAME\" --format json"
echo "📄 Output will be saved to: $OUTPUT_FILE"
echo "---------------------------------------------"

# Run tail command, pipe to jq for formatting, tee to file and stdout
npx wrangler pages deployment tail "$MY_DEPLOYMENT_ID" --project-name "$MY_PROJECT_NAME" --format json \
  | tee "$OUTPUT_FILE" | jq
