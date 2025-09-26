#!/bin/bash

# Configuration file for Environment Comparison Tool
# You can modify these settings to customize the behavior

# Default viewport size (set for mobile view)
export VIEWPORT_WIDTH=375
export VIEWPORT_HEIGHT=812

# Timeout settings (in milliseconds)
export PAGE_TIMEOUT=30000
export SCREENSHOT_DELAY=2

# Browser settings
export HEADLESS_MODE=true
export BROWSER_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage"

# Remove any cookie config from config.sh, as cookies should only be set in ~/.zshrc

# Output settings
export FULL_PAGE_SCREENSHOTS=true
export GENERATE_THUMBNAILS=false
export THUMBNAIL_WIDTH=400

# Report settings
export REPORT_TITLE="Environment Comparison Report"
export INCLUDE_SUMMARY_STATS=true
export INCLUDE_TIMESTAMP=true

# Logging settings
export LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
export LOG_TO_FILE=false
