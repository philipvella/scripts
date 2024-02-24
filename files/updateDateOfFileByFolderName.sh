#!/bin/bash
# DESCRIPTION
# This script updates the modification and access times of files in a directory
# to a new date if the modification date is greater than a target date.

# Base directory containing year-named subdirectories
BASE_DIR="/Users/philipvella/Downloads/GooglePhotos/by-year"

# Iterate over each year-named subdirectory in the base directory
for YEAR_DIR in "${BASE_DIR}"/*/; do
    # Remove the trailing slash to get a clean directory name
    YEAR_DIR="${YEAR_DIR%/}"

    # Extract the year from the directory name
    YEAR=$(basename "${YEAR_DIR}")

    # Assuming the target date to check against is the end of the specified year,
    # and setting the new modification date to the start of that year.
    TARGET_DATE="${YEAR}12312359.59"
    NEW_DATE="${YEAR}01010000.00"

    echo "Processing directory: ${YEAR_DIR}"

    # Find command to iterate over files
    find "${YEAR_DIR}" -type f -print0 | while IFS= read -r -d $'\0' file; do
        # Get file's modification date in format YYYYMMDDHHMM.SS for comparison
        modDate=$(stat -f "%Sm" -t "%Y%m%d%H%M.%S" "$file")

        # Check if modification date is greater than target date
        if [ "$modDate" \> "$TARGET_DATE" ]; then
            # Update the file's modification and access times to new date
            touch -t "$NEW_DATE" "$file"
            echo "Updated $file"
        fi
    done
done
