#!/bin/bash

# This script updates the modification and access times of files to match their content creation date

# Recursively find all files and loop through them
find . -type f -print0 | while IFS= read -r -d $'\0' file; do
    # Extract the content creation date using mdls
    creationDate=$(mdls -name kMDItemContentCreationDate_Ranking -raw "$file" | cut -d ' ' -f 1)

    # Check if the creationDate is not null or 'null'
    if [ "$creationDate" != "(null)" ]; then
        # Convert creationDate to format suitable for 'touch' command
        formattedDate=$(date -j -f "%Y-%m-%d" "$creationDate" "+%Y%m%d%H%M.%S")

        # Update the file's modification and access times
        touch -t "$formattedDate" "$file"
    fi
done
