#!/bin/bash

# Define the start and end dates as arguments
START_DATE=$1
END_DATE=$2

# The CSV file to store the results
OUTPUT_FILE="results.csv"

# Write the CSV header
echo "Date,runs.time,runs.results.number,runs.results.number,runs.results.number,runs.results.number,runs.results.number,runs.results.number" > $OUTPUT_FILE

# Function to fetch data for a specific date and page, then append to CSV
fetch_data() {
    local date=$1
    local page=$2
    response=$(curl -s --location "https://par-iframe.betgames.tv/s/web/v1/game/results/hollywoodbets_net?game_id=9&page=$page&date=$date&timezone=2")

    # Extract the number of pages and runs data using jq
    pages=$(echo $response | jq '.pages')
    runs=$(echo $response | jq -c '.runs[]')

    # Iterate through each run and append data to the CSV
    echo "$runs" | while read -r run; do
        time=$(echo $run | jq '.time')
        numbers=$(echo $run | jq '.results[].number' | tr '\n' ',' | sed 's/,$//')
        echo "$date,$time,$numbers" >> $OUTPUT_FILE
    done

    echo $pages
}

# Iterate through dates
current_date="$START_DATE"
while [[ "$current_date" != "$END_DATE" ]]; do
    page=1
    echo "Fetching page $page for date $current_date"
    pages=$(fetch_data $current_date $page)
    while [[ "$page" -lt "$pages" ]]; do
        ((page++))
        fetch_data $current_date $page > /dev/null
    done
    current_date=$(date -I -d "$current_date + 1 day")
done

# Final call for the END_DATE
fetch_data $END_DATE 1
