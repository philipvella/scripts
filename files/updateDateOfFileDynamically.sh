#!/bin/bash

# DESCRIPTION
# This script updates the modification and access times of files in a directory
# to a new date if the modification date is greater than a target date.

# Directory to process
TARGET_DIR="/Users/philipvella/Downloads/GooglePhotos"

# Find command to iterate over files
find "${TARGET_DIR}" -type f -print0 | while IFS= read -r -d $'\0' file; do
    # Get file's content creation and modification dates using stat
    creationDate=$(stat -f "%SB" -t "%Y%m%d%H%M.%S" "$file")
    modificationDate=$(stat -f "%Sm" -t "%Y%m%d%H%M.%S" "$file")

    # Get the interesting date using mdls
    interestingDate=$(mdls -name kMDItemContentCreationDate -raw "$file" | xargs -I {} date -j -f "%Y-%m-%d %H:%M:%S %z" "{}" "+%Y%m%d%H%M.%S")

    # Convert dates to timestamps for comparison
    creationTimestamp=$(date -j -f "%Y%m%d%H%M.%S" "$creationDate" "+%s")
    modificationTimestamp=$(date -j -f "%Y%m%d%H%M.%S" "$modificationDate" "+%s")
    interestingTimestamp=$(date -j -f "%Y%m%d%H%M.%S" "$interestingDate" "+%s" 2>/dev/null || echo "")

    # Find the smallest timestamp to use as the preferred date
    minTimestamp="$creationTimestamp"
    preferredDate="$creationDate"

    if [ ! -z "$interestingTimestamp" ] && [ "$interestingTimestamp" -lt "$minTimestamp" ]; then
        minTimestamp="$interestingTimestamp"
        preferredDate="$interestingDate"
    fi

    if [ "$modificationTimestamp" -lt "$minTimestamp" ]; then
        preferredDate="$modificationDate"
    fi

    # Get current modification timestamp of the file
    currentModTimestamp=$(stat -f "%m" "$file")

    # Compare if the file's modification timestamp matches the preferred timestamp
    if [ "$(date -j -f "%Y%m%d%H%M.%S" "$preferredDate" "+%s")" -ne "$currentModTimestamp" ]; then
        # Update the file's access and modification times if different
        touch -t "$preferredDate" "$file"

        echo "Updated $file"
#    else
#        echo "No update needed for $file"
    fi
done
