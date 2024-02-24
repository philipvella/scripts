#!/bin/bash

# DESCRIPTION
# This script updates the access and modification times of files in the target directory
# to match the content creation or modification date of the file.

# Directory to process
TARGET_DIR="/Users/philipvella/Downloads/GooglePhotos/by-year/2021"


# Find command to iterate over files
find "${TARGET_DIR}" -type f -print0 | while IFS= read -r -d $'\0' file; do
    # Get file's content creation and modification dates using stat
    creationDate=$(stat -f "%SB" -t "%Y%m%d%H%M.%S" "$file")
    modificationDate=$(stat -f "%Sm" -t "%Y%m%d%H%M.%S" "$file")

    # Prefer creation date if available, otherwise use modification date
    preferredDate="${creationDate:-$modificationDate}"

    # Convert preferredDate to timestamp format for comparison
    preferredTimestamp=$(date -j -f "%Y%m%d%H%M.%S" "$preferredDate" "+%s")

    # Get current modification timestamp of the file
    currentModTimestamp=$(stat -f "%m" "$file")

    # Compare if the file's modification timestamp matches the preferred timestamp
    if [ "$preferredTimestamp" -ne "$currentModTimestamp" ]; then
        # Update the file's access and modification times if different
        touch -t "$preferredDate" "$file"

        echo "Updated $file"
#    else
#        echo "No update needed for $file"
    fi
done
