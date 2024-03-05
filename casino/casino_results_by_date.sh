#!/bin/bash
# This script fetches the results of a casino game from an API and stores them in a CSV file
# The script takes two arguments: the start date and the end date

# Define the start and end dates as arguments
START_DATE=$1
END_DATE=$2

# The CSV file to store the results
OUTPUT_FILE="results-$START_DATE.csv"

# Write the CSV header
echo "Date,runs.time,runs.results.number,runs.results.number,runs.results.number,runs.results.number,runs.results.number,runs.results.number" > $OUTPUT_FILE

# Function to fetch data for a specific date and page, then append to CSV
fetch_data() {
    local date=$1
    local page=$2
    response=$(curl -s --location "https://par-iframe.betgames.tv/s/web/v1/game/results/hollywoodbets_net?game_id=9&page=$page&date=$date&timezone=2" --header 'Cookie: <Your Cookie Here>')

    # Extract the number of pages and runs data using jq
    pages=$(echo $response | jq '.pages')
    runs=$(echo $response | jq -c '.runs[]')

    # Iterate through each run and append data to the CSV
    echo "$runs" | while read -r run; do
        # Check if results are not null
        if [[ $(echo $run | jq '.results') != "null" ]]; then
            time=$(echo $run | jq '.time')
            numbers=$(echo $run | jq '.results[].number' | tr '\n' ',' | sed 's/,$//')
            # Only append if numbers are not empty
            if [[ -n $numbers ]]; then
                echo "$date,$time,$numbers" >> $OUTPUT_FILE
            fi
        fi
    done

    echo $pages
}

# Iterate through dates
current_date="$START_DATE"
while : ; do
    page=1
    pages=$(fetch_data $current_date $page)
    while [[ "$page" -lt "$pages" ]]; do
        ((page++))
        fetch_data $current_date $page > /dev/null
    done
    # Break the loop if we've processed the end date
    if [[ "$current_date" == "$END_DATE" ]]; then
        break
    fi
    current_date=$(date -I -d "$current_date + 1 day")
done
