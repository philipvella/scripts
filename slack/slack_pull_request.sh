#!/bin/bash

# This script sends a curl request with a given URL as a parameter

# Check if a parameter (new URL) was provided
#if [ "$#" -ne 1 ]; then
#  echo "Usage: $0 <new-url>"
#  exit 1
#fi

# The new URL provided as a command-line argument
NEW_URL="https://dev.azure.com/BetagyDevOps/Frontend/_git/kingmakers-frontend/pullrequest/33072"

# Curl command with the new URL
curl --location 'https://hooks.slack.com/triggers/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' \
--header 'Content-Type: application/json' \
--data '{
    "askForReview": "'"$NEW_URL"'"
}'
