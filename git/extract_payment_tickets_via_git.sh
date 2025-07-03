#!/bin/bash

# Define the old and new product versions (tags)
#PROD
OLD_TAG=4fd0a5361d37057b2fb8822cfc2e2eeb9b92e63f
#UAT
NEW_TAG=4fa528811443b4b50f711177590e16508e8c31d5

# Define branch names based on tags
OLD_BRANCH=branch_from_$OLD_TAG
NEW_BRANCH=branch_from_$NEW_TAG

# Change the current directory to the target directory
cd ~/work/OTHER/kingmakers-frontend

git checkout master
git fetch
git pull

# Delete branches if they already exist
git branch -D $OLD_BRANCH
git branch -D $NEW_BRANCH

# Create branches from the given tags

git branch $OLD_BRANCH $OLD_TAG
git branch $NEW_BRANCH $NEW_TAG

# Use git log to get the commit messages between the old and new branches
# Filter these messages to only include those that contain any alphabetic characters (A-Z, a-z) between 1 to 6 characters, followed by a hyphen and four digits
# Sort these extracted strings and remove any duplicates

git log $OLD_BRANCH..$NEW_BRANCH --pretty=format:"%B" | grep -o '[A-Za-z]\{1,6\}-[0-9]\{4\}' | sort | uniq
# > /tmp/commit_messages.txt
# subl /tmp/commit_messages.txt

# Clean up branches after comparison (optional)
# git branch -D $OLD_BRANCH
# git branch -D $NEW_BRANCH
