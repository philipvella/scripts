#!/usr/bin/env bash
# suggest_meds.sh
# Usage: ./suggest_meds.sh "amoxcillin" ["ADHD"] [--debug]    # example misspelling of amoxicillin for ADHD

set -euo pipefail

# Parse arguments
INPUT=""
CONDITION=""
DEBUG_MODE=false

# Process arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug|-d)
      DEBUG_MODE=true
      shift
      ;;
    *)
      if [ -z "$INPUT" ]; then
        INPUT="$1"
      elif [ -z "$CONDITION" ]; then
        CONDITION="$1"
      else
        echo "ERROR: Too many arguments"
        echo "Usage: $0 \"<medicine name>\" [\"<condition>\"] [--debug]"
        exit 2
      fi
      shift
      ;;
  esac
done

# Debug logging function
debug_log() {
  if [ "$DEBUG_MODE" = true ]; then
    echo "DEBUG: $1"
  fi
}

# Enable debug logging
debug_log "Script started at $(date)"
debug_log "Script arguments: $*"
debug_log "Raw input received: '$INPUT'"
debug_log "Medical condition/use: '$CONDITION'"
debug_log "Debug mode: $DEBUG_MODE"

if [ -z "$INPUT" ]; then
  echo "Usage: $0 \"<possibly misspelt medicine name>\" [\"<medical condition or use>\"] [--debug]"
  echo "Example: $0 \"amoxcillin\" \"ADHD\""
  echo "Example: $0 \"amoxcillin\" \"ADHD\" --debug"
  exit 2
fi

debug_log "Input validation passed"

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "ERROR: Please set OPENAI_API_KEY environment variable."
  exit 3
fi

debug_log "OpenAI API key is set (length: ${#OPENAI_API_KEY} characters)"

# Build prompt asking for JSON-only response (candidates with confidence 0.0-1.0)
debug_log "About to create PROMPT variable"

if [ -n "$CONDITION" ]; then
  CONDITION_TEXT=" for treating or managing $CONDITION"
  CONDITION_CONTEXT="The user is looking for medications specifically for: $CONDITION"
else
  CONDITION_TEXT=""
  CONDITION_CONTEXT="No specific medical condition was provided."
fi

PROMPT="You are a helpful assistant that corrects or suggests likely medicine names for a possibly misspelt user input.

$CONDITION_CONTEXT

Task:
  - Given the input: \"$INPUT\"$CONDITION_TEXT
  - Return ONLY valid JSON (no extra explanation or markdown).
  - JSON structure must be:
    {
      \"input\": \"<original input>\",
      \"condition\": \"<condition if provided, otherwise null>\",
      \"candidates\": [
        {\"name\": \"<medicine name>\", \"confidence\": <0.0-1.0>, \"note\": \"<short reason or context>\"},
        ...
      ]
    }

Requirements:
  - Provide up to 10 candidate medicine names (fewer is fine).
  - If a condition was provided, prioritize medications commonly used for that condition.
  - Confidence between 0.0 and 1.0 (higher = more likely).
  - \"note\" should be brief (max ~30 words), e.g. \"common antibiotic\", \"similar spelling\", \"ADHD stimulant\", \"antidepressant\".
  - When unsure, include common alternatives and mark confidence lower.
  - Consider both the spelling similarity AND the medical condition when ranking candidates.
  - Do NOT provide medical advice, dosing, or instructions — only possible name matches.

Return the JSON only."

debug_log "Prompt created successfully"
debug_log "Prompt length: ${#PROMPT} characters"
debug_log "First 100 chars of prompt: ${PROMPT:0:100}..."

# Call OpenAI Chat Completions (Chat API). Model chosen for general use; change if needed.
API_URL="https://api.openai.com/v1/chat/completions"
MODEL="gpt-4o-mini"   # change to another model if you prefer

debug_log "Using API URL: $API_URL"
debug_log "Using model: $MODEL"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed or not in PATH"
    exit 6
fi

debug_log "jq is available"

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is not installed or not in PATH"
    exit 7
fi

debug_log "curl is available"

# Prepare the JSON payload
JSON_PAYLOAD=$(cat <<-JSON
{
  "model": "$MODEL",
  "temperature": 0.0,
  "max_tokens": 400,
  "messages": [
    {"role": "system", "content": "You are an assistant that returns ONLY JSON following the schema described by the user."},
    {"role": "user", "content": $(
        printf '%s' "$PROMPT" | jq -Rs .
      )}
  ]
}
JSON
)

debug_log "JSON payload prepared"
debug_log "JSON payload length: ${#JSON_PAYLOAD} characters"
debug_log "JSON payload (first 200 chars): ${JSON_PAYLOAD:0:200}..."

# Validate JSON payload
if ! echo "$JSON_PAYLOAD" | jq . >/dev/null 2>&1; then
    echo "ERROR: Invalid JSON payload generated"
    echo "DEBUG: Full payload:"
    echo "$JSON_PAYLOAD"
    exit 8
fi

debug_log "JSON payload is valid"

echo "Making API call to OpenAI..."

response=$(curl -sS \
  -w "HTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}\n" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD" \
  "$API_URL" 2>&1)

echo "API call completed."
debug_log "Raw response length: ${#response} characters"

# Extract HTTP status code and timing info
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
time_total=$(echo "$response" | grep "TIME_TOTAL:" | cut -d: -f2)

debug_log "HTTP status code: $http_code"
debug_log "Total time: ${time_total}s"

# Remove the debug info from response
response_body=$(echo "$response" | grep -v "HTTP_CODE:" | grep -v "TIME_TOTAL:")

debug_log "Response body length: ${#response_body} characters"
debug_log "First 200 chars of response: ${response_body:0:200}..."

# Check for HTTP errors
if [[ "$http_code" != "200" ]]; then
    echo "ERROR: API returned HTTP $http_code"
    if [ "$DEBUG_MODE" = true ]; then
        echo "DEBUG: Full response body:"
        echo "$response_body"
    fi
    exit 9
fi

# Check if response is valid JSON
if ! echo "$response_body" | jq . >/dev/null 2>&1; then
    echo "ERROR: API response is not valid JSON"
    if [ "$DEBUG_MODE" = true ]; then
        echo "DEBUG: Full response body:"
        echo "$response_body"
    fi
    exit 10
fi

debug_log "Response is valid JSON"

# Extract text content (robustly handle typical chat completions response)
content=$(printf '%s' "$response_body" | jq -r '.choices[0].message.content // ""')

debug_log "Extracted content length: ${#content} characters"
debug_log "Content preview: ${content:0:100}..."

if [ -z "$content" ]; then
  echo "ERROR: No response from API or unexpected response format."
  if [ "$DEBUG_MODE" = true ]; then
    echo "DEBUG: Full API response:"
    printf '%s\n' "$response_body" | jq . || echo "$response_body"
  fi
  exit 4
fi

debug_log "Content extraction successful"

# Try to pretty-print JSON if the model returned JSON (validate it)
if echo "$content" | jq . >/dev/null 2>&1; then
  debug_log "Content is valid JSON, formatting output..."
  echo "$content" | jq .
  debug_log "Script completed successfully"
else
  # If not valid JSON, print a warning and the raw content
  echo "WARNING: model response was not valid JSON. Raw output below:"
  if [ "$DEBUG_MODE" = true ]; then
    echo "DEBUG: Raw content:"
  fi
  echo "$content"
  exit 5
fi
