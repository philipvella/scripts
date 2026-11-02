#!/bin/bash

usage() {
  echo "Usage: ./describe.sh --branch <branch-name> --repo <repo-path> [--model <model>] [--base <base-branch>]"
  echo "       ./describe.sh <branch-name> <repo-path> [--model <model>] [--base <base-branch>]"
  echo ""
  echo "Named options can be passed in any order."
  echo "Examples:"
  echo "  ./describe.sh --branch chore/PAY-8073 --repo /Users/philipvella/work/BFF"
  echo "  ./describe.sh --repo /Users/philipvella/work/BFF --model gpt-4o-mini --branch chore/PAY-8073"
  echo "  ./describe.sh --base origin/main --branch chore/PAY-8073 --repo /Users/philipvella/work/BFF"
  echo ""
  echo "Models: gpt-4o-mini (default), gpt-4o, gpt-4-turbo"
  echo "Base branch: origin/master (default)"
}

BRANCH=""
REPO_PATH=""
BASE_BRANCH="origin/master" # default
OPENAI_MODEL="gpt-4o-mini"  # default

while [ "$#" -gt 0 ]; do
  case "$1" in
    --branch|--repo|--model|--base)
      if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]; then
        echo "Missing value for $1" >&2
        exit 1
      fi
      case "$1" in
        --branch) BRANCH="$2" ;;
        --repo) REPO_PATH="$2" ;;
        --model) OPENAI_MODEL="$2" ;;
        --base) BASE_BRANCH="$2" ;;
      esac
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -z "$BRANCH" ]; then
        BRANCH="$1"
      elif [ -z "$REPO_PATH" ]; then
        REPO_PATH="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$BRANCH" ] || [ -z "$REPO_PATH" ]; then
  echo "Both --branch and --repo are required (or use <branch-name> <repo-path>)." >&2
  usage >&2
  exit 1
fi

# Extract ticket number from branch name (e.g., "chore/PAY-8073" -> "PAY-8073")
TICKET=$(echo "$BRANCH" | sed 's|.*/||')

# Change directory to the repo path
cd "$REPO_PATH" || { echo "Directory not found"; exit 1; }

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "OPENAI_API_KEY is not set. Export it before running this script." >&2
  exit 1
fi

# Generate the diff against the target branch
# This captures the net code changes to merge, not per-commit messages.
DIFF=$(git diff "$BASE_BRANCH...$BRANCH")

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
