#!/bin/bash

# Check for both parameters
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./describe.sh <branch-name> <repo-path> [--model <model>]"
  echo ""
  echo "Examples:"
  echo "  ./describe.sh chore/PAY-8073 /Users/philipvella/work/BFF"
  echo "  ./describe.sh chore/PAY-8073 /Users/philipvella/work/BFF --model gpt-4-turbo"
  echo ""
  echo "Models: gpt-4-turbo (default, 40k TPM), gpt-4o (30k TPM), gpt-3.5-turbo (90k TPM, cheap)"
  exit 1
fi

BRANCH=$1
REPO_PATH=$2
BASE_BRANCH="origin/master"

# Extract ticket number from branch name (e.g., "chore/PAY-8073" -> "PAY-8073")
TICKET=$(echo "$BRANCH" | sed 's|.*/||')

# Parse optional model parameter
OPENAI_MODEL="gpt-4-turbo"  # default
if [ "$3" = "--model" ] && [ -n "$4" ]; then
  OPENAI_MODEL="$4"
fi

# Change directory to the repo path
cd "$REPO_PATH" || { echo "Directory not found"; exit 1; }

# Generate the diff
DIFF=$(git diff $(git merge-base $BASE_BRANCH $BRANCH)..$BRANCH)

if [ -z "$DIFF" ]; then
  echo "No changes found."
  exit 1
fi

# Pass the diff AND the environment variable to the Python script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/.venv/bin/python"

if [ ! -x "$PY" ]; then
  echo "Python venv not found at $SCRIPT_DIR/.venv. Run: $SCRIPT_DIR/setup.sh" >&2
  exit 1
fi

if ! "$PY" -c "import openai" >/dev/null 2>&1; then
  echo "Python deps not installed in $SCRIPT_DIR/.venv. Run: $SCRIPT_DIR/setup.sh" >&2
  exit 1
fi

echo "Using model: $OPENAI_MODEL" >&2
export OPENAI_MODEL
echo "$DIFF" | "$PY" "$SCRIPT_DIR/generate_pr.py" "$OPENAI_API_KEY" "$TICKET"
