#!/bin/bash

# DESCRIPTION
# This script updates the modification and access times of files in a directory
# to a new date if the modification date is greater than a target date.

# Directory to process
TARGET_DIR="/Users/philipvella/Downloads/GooglePhotos/by-year/2023"

# Target and new modification dates in format YYYYMMDDHHMM.SS
TARGET_DATE="202402220000.00"
NEW_DATE="202301010000.00"

# Find command to iterate over files
find "${TARGET_DIR}" -type f -print0 | while IFS= read -r -d $'\0' file; do
    # Get file's modification date in format YYYYMMDDHHMM.SS for comparison
    modDate=$(stat -f "%Sm" -t "%Y%m%d%H%M.%S" "$file")

    # Check if modification date is greater than target date
    if [ "$modDate" \> "$TARGET_DATE" ]; then
        # Update the file's modification and access times to new date
        touch -t "$NEW_DATE" "$file"
        echo "Updated $file"
    fi
done
