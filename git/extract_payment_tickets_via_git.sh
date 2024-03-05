#!/bin/bash

# Define the old and new product versions
OLD_PROD=a05faaf46d6e5c2f039fa29a6ba2d639e2f24b0a
NEW_PROD=22e3b870be90d87f05376a351358f2e4804be120

# Change the current directory to the kingmakers-frontend directory
cd ~/work/kingmakers-frontend/

# Use git log to get the commit messages between the old and new product versions
# Filter these messages to only include those that contain 'PAY-'
# Extract the 'PAY-' followed by four digits from these messages
# Sort these extracted strings and remove any duplicates
git log --grep='PAY-' $OLD_PROD..$NEW_PROD --pretty=format:"%B" | grep -o 'PAY-\d\d\d\d' | sort | uniq
