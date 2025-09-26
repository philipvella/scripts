#!/bin/bash

# Environment Comparison Script
# Compares two environments by taking screenshots and generating a visual report

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
REPORT_DIR="$OUTPUT_DIR/reports"
UAT_URLS_FILE="$SCRIPT_DIR/uat_urls.txt"
PROD_URLS_FILE="$SCRIPT_DIR/prod_urls.txt"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cookie configuration (can be set via environment variables)
UAT_COOKIE="${UAT_COOKIE:-}"
PROD_COOKIE="${PROD_COOKIE:-}"

# Default viewport size
VIEWPORT_WIDTH=1920
VIEWPORT_HEIGHT=1080

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."

    local deps=("node" "npm")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is required but not installed"
            exit 1
        fi
    done

    # Check if puppeteer is available
    if ! node -e "require('puppeteer')" 2>/dev/null; then
        log "Installing Puppeteer..."
        npm install puppeteer
    fi

    success "All dependencies are available"
}

# Create necessary directories
setup_directories() {
    log "Setting up directories..."
    mkdir -p "$SCREENSHOTS_DIR/uat"
    mkdir -p "$SCREENSHOTS_DIR/prod"
    mkdir -p "$REPORT_DIR"
    success "Directories created"
}

# Generate URL filename for screenshots
url_to_filename() {
    local url="$1"
    echo "$url" | sed 's|https://||g' | sed 's|http://||g' | sed 's|/|_|g' | sed 's|?|_|g' | sed 's|&|_|g' | sed 's|=|_|g'
}

# Take screenshot using Puppeteer
take_screenshot() {
    local url="$1"
    local output_path="$2"
    local cookie="$3"
    local env_name="$4"

    log "Taking screenshot of $url ($env_name)"

    # Create a temporary Node.js script for screenshot
    cat > "$SCRIPT_DIR/screenshot_temp.js" << EOF
const puppeteer = require('puppeteer');
(async () => {
    try {
        const browser = await puppeteer.launch({
            headless: 'new',
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
        });
        const page = await browser.newPage();
        const cookie = '$3';
        console.log('Cookie being set for $4:', cookie);
        if (cookie) {
            await page.setCookie(...cookie.split(';').map(pair => {
                const [name, ...rest] = pair.trim().split('=');
                return { name, value: rest.join('='), domain: new URL('$1').hostname };
            }));
        }
        await page.goto('$1', { waitUntil: 'networkidle2', timeout: 30000 });
        await page.screenshot({ path: '$2', fullPage: true });
        await browser.close();
    } catch (error) {
        console.error('Error taking screenshot of $1:', error.message);
        process.exit(1);
    }
})();
EOF

    if node "$SCRIPT_DIR/screenshot_temp.js"; then
        success "Screenshot saved: $output_path"
    else
        error "Failed to take screenshot of $url"
        return 1
    fi

    # Clean up temp script
    rm -f "$SCRIPT_DIR/screenshot_temp.js"
}

# Process URLs and take screenshots
process_environment() {
    local urls_file="$1"
    local env_name="$2"
    local cookie="$3"
    local screenshot_dir="$4"

    if [[ ! -f "$urls_file" ]]; then
        error "URLs file not found: $urls_file"
        return 1
    fi

    log "Processing $env_name environment..."

    local count=0
    while IFS= read -r url; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

        local filename=$(url_to_filename "$url")
        local output_path="$screenshot_dir/${filename}.png"

        if take_screenshot "$url" "$output_path" "$cookie" "$env_name"; then
            ((count++))
        fi

        # Small delay to avoid overwhelming the server
        sleep 2
    done < "$urls_file"

    success "Processed $count URLs for $env_name"
    return 0
}

# Generate HTML comparison report
generate_html_report() {
    log "Generating HTML comparison report..."

    local report_file="$REPORT_DIR/comparison_report_$TIMESTAMP.html"

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Environment Comparison Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .comparison-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            justify-content: center;
        }
        .comparison-item {
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 20px;
            margin-bottom: 30px;
            width: 100%;
            max-width: 1200px;
        }
        .url-title {
            text-align: center;
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 20px;
            color: #333;
            word-break: break-all;
        }
        .screenshots {
            display: flex;
            gap: 20px;
            justify-content: center;
            flex-wrap: wrap;
        }
        .screenshot-container {
            flex: 1;
            min-width: 400px;
            text-align: center;
        }
        .env-label {
            font-weight: bold;
            margin-bottom: 10px;
            padding: 8px 16px;
            border-radius: 4px;
            color: white;
        }
        .uat-label {
            background-color: #ff6b35;
        }
        .prod-label {
            background-color: #4caf50;
        }
        .screenshot {
            max-width: 100%;
            border: 2px solid #ddd;
            border-radius: 4px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .missing-screenshot {
            display: flex;
            align-items: center;
            justify-content: center;
            height: 300px;
            background-color: #f0f0f0;
            border: 2px dashed #ccc;
            border-radius: 4px;
            color: #666;
            font-style: italic;
        }
        .summary {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .stat-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            text-align: center;
        }
        .stat-number {
            font-size: 24px;
            font-weight: bold;
            color: #2c3e50;
        }
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Environment Comparison Report</h1>
        <p>Generated on: <strong>TIMESTAMP_PLACEHOLDER</strong></p>
    </div>

    <div class="summary">
        <h2>Summary</h2>
        <div class="stats">
            <div class="stat-item">
                <div class="stat-number" id="total-urls">0</div>
                <div class="stat-label">Total URLs</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="uat-screenshots">0</div>
                <div class="stat-label">UAT Screenshots</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="prod-screenshots">0</div>
                <div class="stat-label">PROD Screenshots</div>
            </div>
            <div class="stat-item">
                <div class="stat-number" id="successful-pairs">0</div>
                <div class="stat-label">Successful Pairs</div>
            </div>
        </div>
    </div>

    <div class="comparison-container" id="comparisons">
        <!-- Comparisons will be inserted here -->
    </div>

    <script>
        // This will be populated by the shell script
        const comparisons = COMPARISONS_DATA_PLACEHOLDER;

        function generateComparisons() {
            const container = document.getElementById('comparisons');
            let totalUrls = 0;
            let uatScreenshots = 0;
            let prodScreenshots = 0;
            let successfulPairs = 0;

            comparisons.forEach(comparison => {
                totalUrls++;

                const item = document.createElement('div');
                item.className = 'comparison-item';

                const hasUat = comparison.uat_screenshot;
                const hasProd = comparison.prod_screenshot;

                if (hasUat) uatScreenshots++;
                if (hasProd) prodScreenshots++;
                if (hasUat && hasProd) successfulPairs++;

                item.innerHTML = `
                    <div class="url-title">${comparison.url}</div>
                    <div class="screenshots">
                        <div class="screenshot-container">
                            <div class="env-label uat-label">UAT Environment</div>
                            ${hasUat ?
                                `<img src="../screenshots/uat/${comparison.uat_screenshot}" alt="UAT Screenshot" class="screenshot">` :
                                `<div class="missing-screenshot">Screenshot not available</div>`
                            }
                        </div>
                        <div class="screenshot-container">
                            <div class="env-label prod-label">PROD Environment</div>
                            ${hasProd ?
                                `<img src="../screenshots/prod/${comparison.prod_screenshot}" alt="PROD Screenshot" class="screenshot">` :
                                `<div class="missing-screenshot">Screenshot not available</div>`
                            }
                        </div>
                    </div>
                `;

                container.appendChild(item);
            });

            // Update summary stats
            document.getElementById('total-urls').textContent = totalUrls;
            document.getElementById('uat-screenshots').textContent = uatScreenshots;
            document.getElementById('prod-screenshots').textContent = prodScreenshots;
            document.getElementById('successful-pairs').textContent = successfulPairs;
        }

        generateComparisons();
    </script>
</body>
</html>
EOF

    # Replace placeholders and generate comparison data
    local comparison_data="["
    local first=true

    # Get all unique URLs from both files
    local all_urls=$(cat "$UAT_URLS_FILE" "$PROD_URLS_FILE" 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u)

    while IFS= read -r url; do
        [[ -z "$url" ]] && continue

        local filename=$(url_to_filename "$url")
        local uat_file="$SCREENSHOTS_DIR/uat/${filename}.png"
        local prod_file="$SCREENSHOTS_DIR/prod/${filename}.png"

        if [[ "$first" != true ]]; then
            comparison_data+=","
        fi
        first=false

        comparison_data+="{\"url\":\"$url\","
        comparison_data+="\"uat_screenshot\":\"$([ -f "$uat_file" ] && echo "${filename}.png" || echo "")\","
        comparison_data+="\"prod_screenshot\":\"$([ -f "$prod_file" ] && echo "${filename}.png" || echo "")\"}"
    done <<< "$all_urls"

    comparison_data+="]"

    # Replace placeholders in HTML
    sed -i '' "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$report_file"
    sed -i '' "s/COMPARISONS_DATA_PLACEHOLDER/$comparison_data/g" "$report_file"

    success "HTML report generated: $report_file"
    echo "$report_file"
}

# Main execution
main() {
    log "Starting environment comparison..."

    check_dependencies
    setup_directories

    log "UAT_COOKIE value: $UAT_COOKIE"
    log "PROD_COOKIE value: $PROD_COOKIE"

    # Process UAT environment
    if process_environment "$UAT_URLS_FILE" "UAT" "$UAT_COOKIE" "$SCREENSHOTS_DIR/uat"; then
        success "UAT environment processed successfully"
    else
        error "Failed to process UAT environment"
    fi

    # Process PROD environment
    if process_environment "$PROD_URLS_FILE" "PROD" "$PROD_COOKIE" "$SCREENSHOTS_DIR/prod"; then
        success "PROD environment processed successfully"
    else
        error "Failed to process PROD environment"
    fi

    # Generate report
    local report_file=$(generate_html_report)

    success "Environment comparison completed!"
    echo ""
    echo "Results:"
    echo "  Screenshots: $SCREENSHOTS_DIR"
    echo "  Report: $report_file"
    echo ""
    echo "To view the report, open: $report_file"
}

# Help function
show_help() {
    echo "Environment Comparison Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --uat-cookie   Set UAT environment cookie"
    echo "  --prod-cookie  Set PROD environment cookie"
    echo ""
    echo "Environment Variables:"
    echo "  UAT_COOKIE     Cookie for UAT environment authentication"
    echo "  PROD_COOKIE    Cookie for PROD environment authentication"
    echo ""
    echo "Files Required:"
    echo "  uat_urls.txt   List of UAT URLs to compare"
    echo "  prod_urls.txt  List of PROD URLs to compare"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --uat-cookie)
            UAT_COOKIE="$2"
            shift 2
            ;;
        --prod-cookie)
            PROD_COOKIE="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
