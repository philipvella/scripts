#!/bin/bash

# Setup script for Environment Comparison Tool
# This script helps you configure and run the environment comparison

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Environment Comparison Tool Setup${NC}"
echo "=================================="
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Warning: Node.js is not installed. Please install it from https://nodejs.org${NC}"
    echo
fi

# Make the main script executable
chmod +x "$SCRIPT_DIR/compare_environments.sh"

echo -e "${GREEN}✓ Made compare_environments.sh executable${NC}"

# Only check for urls.txt now
if [[ -f "$CONFIG_DIR/urls.txt" && -s "$CONFIG_DIR/urls.txt" ]]; then
    echo -e "${GREEN}\u2713 URLs file exists and has content${NC}"
else
    echo -e "${YELLOW}\u26a0 Please add URLs to urls.txt${NC}"
fi

echo
echo "Usage Examples:"
echo "==============="
echo
echo "1. Basic comparison (no authentication):"
echo "   ./compare_environments.sh"
echo
echo "2. With authentication cookies:"
echo "   UAT_COOKIE='accessToken=xyz...' PROD_COOKIE='accessToken=abc...' ./compare_environments.sh"
echo
echo "3. Using command line options:"
echo "   ./compare_environments.sh --uat-cookie 'accessToken=xyz...' --prod-cookie 'accessToken=abc...'"
echo
echo "Files you can customize:"
echo "======================="
echo "- uat_urls.txt: List of UAT environment URLs"
echo "- prod_urls.txt: List of PROD environment URLs"
echo
echo -e "${GREEN}Setup complete! You're ready to run environment comparisons.${NC}"
