#!/bin/bash

# Define the old and new product versions
OLD_PROD=c662718b96b07c062194df18dd5cbff8230d5007
NEW_PROD=4c9d2a97fe022b323930580af3caa71f6eafd58b

# Change the current directory to the kingmakers-frontend directory
cd ~/work/OTHER/kingmakers-frontend

git fetch
git pull

# Use git log to get the commit messages between the old and new product versions
# Filter these messages to only include those that contain 'PAY-'
# Extract the 'PAY-' followed by four digits from these messages
# Sort these extracted strings and remove any duplicates
git log --grep='PAY-' $OLD_PROD..$NEW_PROD --pretty=format:"%B" | grep -o 'PAY-\d\d\d\d' | sort | uniq
