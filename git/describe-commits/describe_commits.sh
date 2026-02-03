#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: ./describe_commits.sh <from-commit> <to-commit> <repo-path> [pathspec]"
  echo
  echo "Args:"
  echo "  from-commit  git commit-ish (sha/tag/branch)"
  echo "  to-commit    git commit-ish (sha/tag/branch)"
  echo "  repo-path    path to the git repo"
  echo "  pathspec     optional repo-relative path to limit changes (e.g. src/ or package.json)"
  echo
  echo "Environment:"
  echo "  OPENAI_API_KEY   required"
  echo "  OPENAI_MODEL     optional (default: gpt-4o)"
  echo "  DIFF_MAX_CHARS   optional (default: 120000)"
  echo "  DIFF_CONTEXT     optional (default: 3)"
  echo
  echo "Notes:"
  echo "  - Summarizes changes between two commits in simple product/human terms. Make sure to always mention the area updated so that it is not generic."
  echo "  - Uses: git diff <from>..<to> (compact diff by default)"
}

if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "${1-}" ] || [ -z "${2-}" ] || [ -z "${3-}" ]; then
  usage
  exit 1
fi

FROM_COMMIT=$1
TO_COMMIT=$2
REPO_PATH=$3
PATHSPEC=${4-}

if [ -z "${OPENAI_API_KEY-}" ]; then
  echo "OPENAI_API_KEY is not set"
  exit 1
fi

cd "$REPO_PATH" || { echo "Directory not found: $REPO_PATH"; exit 1; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $REPO_PATH"
  exit 1
fi

# Validate commits (accepts hashes, tags, branch names, etc.)
if ! git rev-parse --verify "$FROM_COMMIT^{commit}" >/dev/null 2>&1; then
  echo "Invalid from-commit: $FROM_COMMIT"
  exit 1
fi

if ! git rev-parse --verify "$TO_COMMIT^{commit}" >/dev/null 2>&1; then
  echo "Invalid to-commit: $TO_COMMIT"
  exit 1
fi

# Create a summary-friendly diff to reduce tokens:
# - smaller context (-U)
# - ignore whitespace-only changes
# - include file stats header
DIFF_CONTEXT=${DIFF_CONTEXT:-3}

if [ -n "$PATHSPEC" ]; then
  # Use a pathspec to restrict diff scope; requires `--` separator.
  DIFF=$( (git diff --stat "$FROM_COMMIT".."$TO_COMMIT" -- "$PATHSPEC"; echo; git diff -U"$DIFF_CONTEXT" -w "$FROM_COMMIT".."$TO_COMMIT" -- "$PATHSPEC") )
else
  DIFF=$( (git diff --stat "$FROM_COMMIT".."$TO_COMMIT"; echo; git diff -U"$DIFF_CONTEXT" -w "$FROM_COMMIT".."$TO_COMMIT") )
fi

if [ -z "$DIFF" ]; then
  echo "No changes found between $FROM_COMMIT and $TO_COMMIT."
  exit 1
fi

# Guardrail against huge diffs.
DIFF_MAX_CHARS=${DIFF_MAX_CHARS:-120000}
if [ ${#DIFF} -gt "$DIFF_MAX_CHARS" ]; then
  DIFF=${DIFF:0:$DIFF_MAX_CHARS}
  DIFF="$DIFF\n\n[Diff truncated to ${DIFF_MAX_CHARS} characters to keep the summary within model limits.]"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "$DIFF" | python3 "$SCRIPT_DIR/summarize_commits.py" "$OPENAI_API_KEY"
