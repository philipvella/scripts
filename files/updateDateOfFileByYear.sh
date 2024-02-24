#!/bin/bash

# DESCRIPTION
# This script updates the modification and access times of files in a directory
# to a new date if the modification date is greater than a target date.

# Year variable
YEAR="2015"

# Directory to process, incorporating the year variable
TARGET_DIR="/Users/philipvella/Downloads/GooglePhotos/by-year/${YEAR}"

# Assuming the target date to check against is the end of the specified year,
# and setting the new modification date to the start of that year.
# Adjust these dates if the logic is meant to be different.
TARGET_DATE="${YEAR}12312359.59"
NEW_DATE="${YEAR}01010000.00"

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
