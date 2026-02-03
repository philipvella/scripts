#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

cd "$TMP_DIR"
git init -q

echo "hello" > file.txt
mkdir -p scoped
echo "a" > scoped/scoped.txt

git add file.txt scoped/scoped.txt
git commit -q -m "init"
FROM=$(git rev-parse HEAD)

# Change both files
echo "hello world" > file.txt
echo "b" > scoped/scoped.txt

git add file.txt scoped/scoped.txt
git commit -q -m "update"
TO=$(git rev-parse HEAD)

# Run in stub mode so it never calls the network
OUT=$(UNIT_TEST_MODE=1 OPENAI_API_KEY="test" "$ROOT_DIR/describe_commits.sh" "$FROM" "$TO" "$TMP_DIR")

echo "$OUT" | grep -q "^- "

# Also ensure pathspec argument is accepted (still stubbed output)
OUT_SCOPED=$(UNIT_TEST_MODE=1 OPENAI_API_KEY="test" "$ROOT_DIR/describe_commits.sh" "$FROM" "$TO" "$TMP_DIR" "scoped/")

echo "$OUT_SCOPED" | grep -q "^- "

# In UNIT_TEST_MODE the output doesn't include file names, so we validate the git scoping directly.
SCOPED_ONLY=$(git diff --name-only "$FROM".."$TO" -- scoped/)
ALL_CHANGED=$(git diff --name-only "$FROM".."$TO")

echo "$SCOPED_ONLY" | grep -q "^scoped/scoped.txt$"
# Ensure unscoped changes exist
echo "$ALL_CHANGED" | grep -q "^file.txt$"

echo "smoke test passed"
