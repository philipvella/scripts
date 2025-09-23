#!/usr/bin/env bash
# Usage:
#   ./find_commits.sh "<pattern>" [branch] [-i]
# Examples:
#   ./find_commits.sh "PAY-\d+"                 # search current branch (regex)
#   ./find_commits.sh "fix login" main -i       # case-insensitive on 'main'
#
# Notes:
# - <pattern> is a regex used by `git --grep`.
# - Add -i as the last argument for case-insensitive matching.
# - Outputs the *full* commit message (subject + body) for each match, separated by lines.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 \"<pattern>\" [branch] [-i]" >&2
  exit 1
fi

pattern="$1"
branch="${2:-HEAD}"
icase_flag=""

# Optional third arg: -i for case-insensitive search
if [ "${3:-}" = "-i" ]; then
  icase_flag="--regexp-ignore-case"
fi

# Print matching commit messages (subject + body), oldest first
# Remove --reverse if you prefer newest first.
git log \
  --reverse \
  "$branch" \
  --grep="$pattern" \
  $icase_flag \
  --pretty=format:'%B%n----'
