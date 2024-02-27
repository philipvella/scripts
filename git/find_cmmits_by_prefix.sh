#!/bin/bash

# Check if an argument was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 PATTERN"
    exit 1
fi

PATTERN=$1

cd ~/work/kingmakers-frontend/

# Use git log to extract commits, then grep for the pattern and following lines,
# and finally filter lines starting with "- [x]"
git log --grep="$PATTERN" --pretty=format:"%B" | grep -E "^\- \[x\]"

# Explanation of commands:
# - `git log --grep="$PATTERN" --pretty=format:"%B"` gets the full commit messages that contain the pattern.
# - `grep -E "^\- \[x\]"` filters those lines starting with "- [x]".

