#!/bin/bash

# Setup script for Environment Comparison Tool
# This script helps you configure and run the environment comparison

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Check if URL files exist and have content
if [[ -f "$SCRIPT_DIR/uat_urls.txt" && -s "$SCRIPT_DIR/uat_urls.txt" ]]; then
    echo -e "${GREEN}✓ UAT URLs file exists and has content${NC}"
else
    echo -e "${YELLOW}⚠ Please add URLs to uat_urls.txt${NC}"
fi

if [[ -f "$SCRIPT_DIR/prod_urls.txt" && -s "$SCRIPT_DIR/prod_urls.txt" ]]; then
    echo -e "${GREEN}✓ PROD URLs file exists and has content${NC}"
else
    echo -e "${YELLOW}⚠ Please add URLs to prod_urls.txt${NC}"
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
