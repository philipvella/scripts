#!/bin/bash

# Generates a deployable folder with HTML comparison and all screenshots for CF Workers
# Usage: ./scripts/generate_comparison_html.sh

OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/output"
UAT_DIR="$OUTPUT_DIR/screenshots/uat"
PROD_DIR="$OUTPUT_DIR/screenshots/prod"
DEPLOY_DIR="$OUTPUT_DIR/deploy"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create deployment directory structure
mkdir -p "$DEPLOY_DIR/screenshots/uat"
mkdir -p "$DEPLOY_DIR/screenshots/prod"

# Copy all screenshots to deploy folder
cp "$UAT_DIR"/*.png "$DEPLOY_DIR/screenshots/uat/" 2>/dev/null || echo "No UAT screenshots found"
cp "$PROD_DIR"/*.png "$DEPLOY_DIR/screenshots/prod/" 2>/dev/null || echo "No PROD screenshots found"

# Find all UAT screenshots in deploy folder
uat_files=($(ls "$DEPLOY_DIR/screenshots/uat"/*.png 2>/dev/null))

# Generate index.html in deploy folder
cat > "$DEPLOY_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Environment Screenshot Comparison</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f8f9fa;
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }
        .header {
            text-align: center;
            background: #fff;
            padding: 30px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        .header h1 {
            margin: 0 0 10px 0;
            color: #2c3e50;
            font-size: 2.5em;
        }
        .header p {
            color: #7f8c8d;
            margin: 0;
            font-size: 1.1em;
        }
        .comparison {
            background: #fff;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.08);
            margin-bottom: 30px;
            padding: 25px;
            transition: transform 0.2s ease;
        }
        .comparison:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.12);
        }
        .url {
            font-weight: 600;
            margin-bottom: 20px;
            word-break: break-all;
            font-size: 1.1em;
            color: #34495e;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #3498db;
        }
        .screenshots {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 25px;
        }
        @media (max-width: 768px) {
            .screenshots {
                grid-template-columns: 1fr;
            }
        }
        .env {
            text-align: center;
        }
        .env-label {
            font-weight: 600;
            margin-bottom: 15px;
            padding: 12px 20px;
            border-radius: 25px;
            color: #fff;
            font-size: 0.95em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .uat-label {
            background: linear-gradient(135deg, #ff6b35, #f39c12);
        }
        .prod-label {
            background: linear-gradient(135deg, #27ae60, #2ecc71);
        }
        .img-container {
            position: relative;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            width: max-content;
            margin: auto;
        }
        img {
            width: 100%;
            height: auto;
            display: block;
            transition: transform 0.3s ease;
        }
        .img-container:hover img {
            transform: scale(1.02);
        }
        .missing {
            color: #7f8c8d;
            font-style: italic;
            background: #ecf0f1;
            padding: 60px 20px;
            border-radius: 8px;
            text-align: center;
            font-size: 1.1em;
        }
        .stats {
            background: #fff;
            padding: 20px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.08);
            margin-bottom: 30px;
            text-align: center;
        }
        .stats h2 {
            margin: 0 0 15px 0;
            color: #2c3e50;
        }
        .stat-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .stat-item {
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #3498db;
        }
        .stat-label {
            color: #7f8c8d;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Environment Comparison</h1>
        <p>Generated on $(date '+%B %d, %Y at %I:%M %p')</p>
    </div>
EOF

# Count screenshots for stats
uat_count=0
prod_count=0
pairs_count=0

for uat_path in "${uat_files[@]}"; do
    uat_file=$(basename "$uat_path")
    prod_file="${uat_file/uat.supersportbet.com/www.supersportbet.com}"
    prod_path="$DEPLOY_DIR/screenshots/prod/$prod_file"

    if [ -f "$uat_path" ]; then ((uat_count++)); fi
    if [ -f "$prod_path" ]; then ((prod_count++)); fi
    if [ -f "$uat_path" ] && [ -f "$prod_path" ]; then ((pairs_count++)); fi
done

# Add stats section
cat >> "$DEPLOY_DIR/index.html" <<EOF
    <div class="stats">
        <h2>Comparison Statistics</h2>
        <div class="stat-grid">
            <div class="stat-item">
                <div class="stat-number">$uat_count</div>
                <div class="stat-label">UAT Screenshots</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">$prod_count</div>
                <div class="stat-label">PROD Screenshots</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">$pairs_count</div>
                <div class="stat-label">Complete Pairs</div>
            </div>
        </div>
    </div>
EOF

# Generate comparison sections
for uat_path in "${uat_files[@]}"; do
    uat_file=$(basename "$uat_path")
    prod_file="${uat_file/uat.supersportbet.com/www.supersportbet.com}"
    prod_path="$DEPLOY_DIR/screenshots/prod/$prod_file"
    url="https://uat.supersportbet.com/$(echo "$uat_file" | sed 's|uat.supersportbet.com_||; s|_|/|g; s|.png$||')"

    cat >> "$DEPLOY_DIR/index.html" <<EOF
    <div class="comparison">
        <div class="url">$url</div>
        <div class="screenshots">
            <div class="env">
                <div class="env-label uat-label">UAT Environment</div>
EOF

    if [ -f "$uat_path" ]; then
        cat >> "$DEPLOY_DIR/index.html" <<EOF
                <div class="img-container">
                    <img src="screenshots/uat/$uat_file" alt="UAT Screenshot" loading="lazy">
                </div>
EOF
    else
        cat >> "$DEPLOY_DIR/index.html" <<EOF
                <div class="missing">No UAT screenshot available</div>
EOF
    fi

    cat >> "$DEPLOY_DIR/index.html" <<EOF
            </div>
            <div class="env">
                <div class="env-label prod-label">PROD Environment</div>
EOF

    if [ -f "$prod_path" ]; then
        cat >> "$DEPLOY_DIR/index.html" <<EOF
                <div class="img-container">
                    <img src="screenshots/prod/$prod_file" alt="PROD Screenshot" loading="lazy">
                </div>
EOF
    else
        cat >> "$DEPLOY_DIR/index.html" <<EOF
                <div class="missing">No PROD screenshot available</div>
EOF
    fi

    cat >> "$DEPLOY_DIR/index.html" <<EOF
            </div>
        </div>
    </div>
EOF
done

# Close HTML
cat >> "$DEPLOY_DIR/index.html" <<EOF
</body>
</html>
EOF

echo "============================================"
echo "Deployment folder created: $DEPLOY_DIR"
echo "============================================"
echo "Contents:"
echo "  - index.html (main comparison page)"
echo "  - screenshots/uat/ ($uat_count files)"
echo "  - screenshots/prod/ ($prod_count files)"
echo ""
echo "Ready to upload to Cloudflare Workers!"
echo "Just upload the entire '$DEPLOY_DIR' folder contents."
echo "============================================"
