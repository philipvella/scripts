#!/bin/bash

usage() {
  echo "Usage: ./describe.sh"
  echo "       ./describe.sh --branch <branch-name> --repo <repo-path> [--model <model>] [--base <base-branch>]"
  echo "       ./describe.sh <branch-name> <repo-path> [--model <model>] [--base <base-branch>]"
  echo ""
  echo "Named options can be passed in any order."
  echo "Missing values are prompted for. Repositories and their base branches are saved"
  echo "in \${XDG_CONFIG_HOME:-\$HOME/.config}/generate-pull-request-description/repos.json."
  echo "Use --base to update a repository's saved base branch."
  echo "Choose saved repositories with Up/Down and Enter, or type a menu number."
  echo "At the branch prompt, Enter uses the repository's current branch."
  echo "Examples:"
  echo "  ./describe.sh --branch chore/PAY-8073 --repo /Users/philipvella/work/BFF"
  echo "  ./describe.sh --repo /Users/philipvella/work/BFF --model gpt-4o-mini --branch chore/PAY-8073"
  echo "  ./describe.sh --base origin/main --branch chore/PAY-8073 --repo /Users/philipvella/work/BFF"
  echo ""
  echo "Models: gpt-4o-mini (default), gpt-4o, gpt-4-turbo"
  echo "Base branch: saved per repository; prompted for on first use"
}

BRANCH=""
REPO_PATH=""
BASE_BRANCH=""
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
PY="$SCRIPT_DIR/.venv/bin/python"

if [ ! -x "$PY" ]; then
  echo "Python venv not found at $SCRIPT_DIR/.venv. Run: $SCRIPT_DIR/setup.sh" >&2
  exit 1
fi

if ! SETTINGS=$("$PY" "$SCRIPT_DIR/repo_config.py" --repo "$REPO_PATH" --base "$BASE_BRANCH" --branch "$BRANCH"); then
  exit 1
fi
{
  IFS= read -r REPO_PATH
  IFS= read -r BASE_BRANCH
  IFS= read -r BRANCH
} <<< "$SETTINGS"

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
if ! DIFF=$(git diff "$BASE_BRANCH...$BRANCH"); then
  echo "Could not generate the diff for $BASE_BRANCH...$BRANCH." >&2
  exit 1
fi

if [ -z "$DIFF" ]; then
  echo "No changes found."
  exit 1
fi

# Pass the diff AND the environment variable to the Python script
if ! "$PY" -c "import openai" >/dev/null 2>&1; then
  echo "Python deps not installed in $SCRIPT_DIR/.venv. Run: $SCRIPT_DIR/setup.sh" >&2
  exit 1
fi

echo "Using model: $OPENAI_MODEL" >&2
export OPENAI_MODEL
echo "$DIFF" | "$PY" "$SCRIPT_DIR/generate_pr.py" "$OPENAI_API_KEY" "$TICKET"
