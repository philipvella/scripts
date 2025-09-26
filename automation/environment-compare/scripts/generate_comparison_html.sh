#!/bin/bash

# Generates a side-by-side HTML comparison of UAT and PROD screenshots
# Usage: ./scripts/generate_comparison_html.sh

OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/output"
UAT_DIR="$OUTPUT_DIR/screenshots/uat"
PROD_DIR="$OUTPUT_DIR/screenshots/prod"
REPORT_DIR="$OUTPUT_DIR/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/comparison_report_$TIMESTAMP.html"

mkdir -p "$REPORT_DIR"

# Find all UAT screenshots
uat_files=($(ls "$UAT_DIR"/*.png 2>/dev/null))

cat > "$REPORT_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Environment Screenshot Comparison</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
        .comparison { background: #fff; border-radius: 8px; box-shadow: 0 2px 8px #ccc; margin-bottom: 30px; padding: 20px; }
        .url { font-weight: bold; margin-bottom: 10px; word-break: break-all; }
        .screenshots { display: flex; gap: 20px; justify-content: center; }
        .env { text-align: center; flex: 1; }
        .env-label { font-weight: bold; margin-bottom: 10px; padding: 8px 16px; border-radius: 4px; color: #fff; }
        .uat-label { background: #ff6b35; }
        .prod-label { background: #4caf50; }
        img { max-width: 375px; border: 2px solid #ddd; border-radius: 4px; box-shadow: 0 2px 8px #eee; }
        .missing { color: #999; font-style: italic; background: #eee; padding: 40px; border-radius: 4px; }
    </style>
</head>
<body>
    <h1>Environment Screenshot Comparison</h1>
    <p>Generated: $(date)</p>
EOF

for uat_path in "${uat_files[@]}"; do
    uat_file=$(basename "$uat_path")
    prod_file="${uat_file/uat.supersportbet.com/www.supersportbet.com}"
    prod_path="$PROD_DIR/$prod_file"
    url="https://uat.supersportbet.com/$(echo "$uat_file" | sed 's|uat.supersportbet.com_||; s|_|/|g; s|.png$||')"
    echo "    <div class=\"comparison\">" >> "$REPORT_FILE"
    echo "        <div class=\"url\">$url</div>" >> "$REPORT_FILE"
    echo "        <div class=\"screenshots\">" >> "$REPORT_FILE"
    echo "            <div class=\"env\">" >> "$REPORT_FILE"
    echo "                <div class=\"env-label uat-label\">UAT</div>" >> "$REPORT_FILE"
    if [ -f "$uat_path" ]; then
        echo "                <img src=\"../screenshots/uat/$uat_file\" alt=\"UAT Screenshot\">" >> "$REPORT_FILE"
    else
        echo "                <div class=\"missing\">No UAT screenshot</div>" >> "$REPORT_FILE"
    fi
    echo "            </div>" >> "$REPORT_FILE"
    echo "            <div class=\"env\">" >> "$REPORT_FILE"
    echo "                <div class=\"env-label prod-label\">PROD</div>" >> "$REPORT_FILE"
    if [ -f "$prod_path" ]; then
        echo "                <img src=\"../screenshots/prod/$prod_file\" alt=\"PROD Screenshot\">" >> "$REPORT_FILE"
    else
        echo "                <div class=\"missing\">No PROD screenshot</div>" >> "$REPORT_FILE"
    fi
    echo "            </div>" >> "$REPORT_FILE"
    echo "        </div>" >> "$REPORT_FILE"
    echo "    </div>" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" <<EOF
</body>
</html>
EOF

echo "HTML comparison report generated: $REPORT_FILE"
