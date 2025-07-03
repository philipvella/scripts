#!/bin/bash

# Hardcoded URL
URL="https://m.betking.com/?blockExternalScripts=true"
TMPFILE=$(mktemp)

# Function to fetch resource size using curl
fetch_size() {
  RESOURCE_URL=$1
  SIZE=$(curl -sI "$RESOURCE_URL" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
  echo ${SIZE:-0}  # Return 0 if size is empty
}

# Get the main HTML page size
MAIN_SIZE=$(fetch_size "$URL")
echo "Main page size: $MAIN_SIZE bytes"

# Download the HTML content to parse
curl -s "$URL" -o $TMPFILE

# Extract resources (CSS, JS, images)
RESOURCES=$(grep -Eo '(http|https)://[^"]+' $TMPFILE)

# Initialize total size
TOTAL_SIZE=$MAIN_SIZE

# Iterate through each resource and get its size
for RESOURCE in $RESOURCES; do
  RESOURCE_SIZE=$(fetch_size "$RESOURCE")
  TOTAL_SIZE=$((TOTAL_SIZE + RESOURCE_SIZE))
  echo "Resource: $RESOURCE - Size: $RESOURCE_SIZE bytes"
done

# Clean up the temp file
rm -f $TMPFILE

# Print total size
echo "Total page load size: $TOTAL_SIZE bytes"
