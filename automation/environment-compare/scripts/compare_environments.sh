#!/bin/bash

# Source config.sh for default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
CONFIG_SH="$CONFIG_DIR/config.sh"
source "$CONFIG_SH"

# Configuration
OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/output"
SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
URLS_FILE="$CONFIG_DIR/urls.txt"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YIGHLIGHT='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cookie configuration (only use environment variables from shell, ignore repo config)
UAT_COOKIE="${UAT_COOKIE}"
PROD_COOKIE="${PROD_COOKIE}"

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
    echo -e "${YIGHLIGHT}[WARNING]${NC} $1"
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
    success "Directories created"
}

# Generate URL filename for screenshots
url_to_filename() {
    local url="$1"
    echo "$url" | sed 's|https://||g' | sed 's|http://||g' | sed 's|/|_|g' | sed 's|?|_|g' | sed 's|&|_|g' | sed 's|=|_|g'
}

# Helper to convert UAT to PROD URL
uat_to_prod_url() {
    local url="$1"
    echo "$url" | sed 's|uat.supersportbet.com|www.supersportbet.com|'
}

# Take screenshot using Puppeteer
take_screenshot() {
    local url="$1"
    local output_path="$2"
    local cookie="$3"
    local env_name="$4"

    log "Taking screenshot of $url ($env_name)"
    log "Screenshot will be saved to: $output_path"

    # Create a temporary Node.js script for screenshot
    cat > "$SCRIPT_DIR/screenshot_temp.js" << EOF
const puppeteer = require('puppeteer');
const fs = require('fs');
(async () => {
    try {
        const browser = await puppeteer.launch({
            headless: 'new',
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
        });
        const page = await browser.newPage();
        await page.setViewport({ width: 375, height: 812 }); // Mobile viewport (iPhone X/11/12/13)
        const cookie = '$3';
        console.log('Cookie being set for $4:', cookie);
        if (cookie) {
            const cookies = cookie.split(';').map(pair => {
                const [name, ...rest] = pair.trim().split('=');
                if (["Path", "Expires", "Max-Age", "Domain", "Secure", "HttpOnly", "SameSite"].includes(name)) return null;
                if (!name || rest.length === 0) return null;
                const value = rest.join('=');
                console.log(`Setting cookie: name='${name}', value='${value}', domain='${new URL('$1').hostname}'`);
                return { name, value, domain: new URL('$1').hostname };
            }).filter(Boolean);
            if (cookies.length > 0) {
                await page.setCookie(...cookies);
            }
        }
        await page.goto('$1', { waitUntil: 'networkidle2', timeout: 30000 });
        await page.screenshot({ path: '$2', fullPage: true });
        if (fs.existsSync('$2')) {
            console.log('Screenshot successfully created:', '$2');
        } else {
            console.error('Screenshot file not found after creation:', '$2');
        }
        await browser.close();
    } catch (error) {
        console.error('Error taking screenshot of $1:', error.message);
        process.exit(1);
    }
})();
EOF

    # Always run the temp script using its absolute path and log output
    node "$SCRIPT_DIR/screenshot_temp.js" > "$output_path.log" 2>&1
    if [ -f "$output_path" ]; then
        success "Screenshot saved: $output_path"
    else
        warn "Screenshot NOT created: $output_path. See $output_path.log for details."
    fi

    # Clean up temp script
    rm -f "$SCRIPT_DIR/screenshot_temp.js"
}

# Process URLs and take screenshots
process_environment() {
    local env_name="$1"
    local cookie="$2"
    local screenshot_dir="$3"

    if [[ ! -f "$URLS_FILE" ]]; then
        error "URLs file not found: $URLS_FILE"
        return 1
    fi

    log "Processing $env_name environment..."

    local count=0
    while IFS= read -r url; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

        local target_url="$url"
        if [[ "$env_name" == "PROD" ]]; then
            target_url="$(uat_to_prod_url "$url")"
        fi
        local filename=$(url_to_filename "$target_url")
        local output_path="$screenshot_dir/${filename}.png"

        if take_screenshot "$target_url" "$output_path" "$cookie" "$env_name"; then
            ((count++))
        fi
        sleep 2
    done < "$URLS_FILE"

    success "Processed $count URLs for $env_name"
    return 0
}

# Main execution
main() {
    log "Starting environment comparison..."

    check_dependencies
    setup_directories

    log "UAT_COOKIE value: $UAT_COOKIE"
    log "PROD_COOKIE value: $PROD_COOKIE"

    # Process UAT environment
    if process_environment "UAT" "$UAT_COOKIE" "$SCREENSHOTS_DIR/uat"; then
        success "UAT environment processed successfully"
    else
        error "Failed to process UAT environment"
    fi

    # Process PROD environment
    if process_environment "PROD" "$PROD_COOKIE" "$SCREENSHOTS_DIR/prod"; then
        success "PROD environment processed successfully"
    else
        error "Failed to process PROD environment"
    fi

    echo ""
    echo "Results:"
    echo "  Screenshots: $SCREENSHOTS_DIR"
    echo ""
    echo "To view the screenshots, open the files in: $SCREENSHOTS_DIR"
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
    echo "  urls.txt       List of URLs to compare (UAT and PROD)"
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