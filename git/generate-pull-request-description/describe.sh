#!/bin/bash

# Check for both parameters
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./describe.sh <branch-name> <repo-path>"
  exit 1
fi

BRANCH=$1
REPO_PATH=$2
BASE_BRANCH="origin/master"

# Change directory to the repo path
cd "$REPO_PATH" || { echo "Directory not found"; exit 1; }

# Generate the diff
DIFF=$(git diff $(git merge-base $BASE_BRANCH $BRANCH)..$BRANCH)

if [ -z "$DIFF" ]; then
  echo "No changes found."
  exit 1
fi

# Pass the diff AND the environment variable to the Python script
echo "$DIFF" | python3 ~/work/scripts/git/generate-pull-request-description/generate_pr.py "$OPENAI_API_KEY"