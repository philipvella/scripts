#!/bin/bash

# Check if an argument was provided
#if [ $# -eq 0 ]; then
#    echo "Usage: $0 PATTERN"
#    exit 1
#fi

#PATTERN=$1
PATTERN=1953

cd ~/work/kingmakers-frontend

# Extract tasks, remove duplicates while preserving order, then reverse the output using tail -r for macOS.
git log --grep="$PATTERN" --pretty=format:"%B" |
grep -E "^\- \[x\]" |
awk '!seen[$0]++' |
tail -r