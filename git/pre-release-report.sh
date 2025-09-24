#!/bin/bash

# repository: https://dev.azure.com/BetagyDevOps/Frontend/_git/kingmakers-frontend
# Usage: ./pre-release-report.sh --repo-path <path> --uat-hash <hash> --prod-hash <hash> --path-to-check <path> [--debug]

# Initialize variables
DEBUG_MODE=false
REPO_PATH=""
UAT_HASH=""
PROD_HASH=""
PATH_TO_CHECK=""

# Function to show usage
show_usage() {
    echo "Usage: $0 --repo-path <path> --uat-hash <hash> --prod-hash <hash> --path-to-check <path> [--debug]"
    echo ""
    echo "Required arguments:"
    echo "  --repo-path <path>       Path to the git repository"
    echo "  --uat-hash <hash>        UAT commit hash"
    echo "  --prod-hash <hash>       PROD commit hash"
    echo "  --path-to-check <path>   Path within repo to check for diffs"
    echo ""
    echo "Optional arguments:"
    echo "  --debug                  Enable debug output"
    echo "  --help                   Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --repo-path ~/work/kingmakers-frontend --uat-hash 5afd67036559e24f6481896a0b3a8f249c262d5c --prod-hash 8a6052ea57e5d71d570490c956586664efde9275 --path-to-check apps/islands-tailwind"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-path)
            REPO_PATH="$2"
            shift 2
            ;;
        --uat-hash)
            UAT_HASH="$2"
            shift 2
            ;;
        --prod-hash)
            PROD_HASH="$2"
            shift 2
            ;;
        --path-to-check)
            PATH_TO_CHECK="$2"
            shift 2
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REPO_PATH" || -z "$UAT_HASH" || -z "$PROD_HASH" || -z "$PATH_TO_CHECK" ]]; then
    echo "Error: Missing required arguments"
    echo ""
    show_usage
    exit 1
fi

# Expand tilde in REPO_PATH
REPO_PATH="${REPO_PATH/#\~/$HOME}"

# Create output file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="/Users/philipvella/work/scripts/git/commit_analysis_${TIMESTAMP}.txt"
SLACK_FILE="/Users/philipvella/work/scripts/git/slack_release_summary_${TIMESTAMP}.md"

# Function to output both to terminal and file
output() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

# Function to output debug information only if debug mode is enabled
debug_output() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "$1" >> "$OUTPUT_FILE"
    fi
}

# Initialize output file
echo "Git Commit Analysis Report" > "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"
if [ "$DEBUG_MODE" = true ]; then
    echo "Debug mode: ENABLED" >> "$OUTPUT_FILE"
fi
echo "======================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Initialize Slack-friendly output
echo "🚀 *Release Summary - $(date '+%B %d, %Y')*" > "$SLACK_FILE"
echo "" >> "$SLACK_FILE"

# Change to the repository directory
cd "$REPO_PATH" || { echo "Error: Could not change to repository directory $REPO_PATH"; exit 1; }

# Debug: Check if we're in a git repository
debug_output "DEBUG: Checking git repository status..."
debug_output "DEBUG: Current directory: $(pwd)"
debug_output "DEBUG: Git status:"
if [ "$DEBUG_MODE" = true ]; then
    git status --porcelain >> "$OUTPUT_FILE" 2>&1
fi
debug_output "DEBUG: Git remote -v:"
if [ "$DEBUG_MODE" = true ]; then
    git remote -v >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

# Debug: Check if the commit hashes exist
debug_output "DEBUG: Checking if commit hashes exist..."
debug_output "DEBUG: Checking PROD hash ($PROD_HASH):"
if [ "$DEBUG_MODE" = true ]; then
    git cat-file -t "$PROD_HASH" >> "$OUTPUT_FILE" 2>&1
fi
debug_output "DEBUG: Checking UAT hash ($UAT_HASH):"
if [ "$DEBUG_MODE" = true ]; then
    git cat-file -t "$UAT_HASH" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

# Debug: Check if the path exists
debug_output "DEBUG: Checking if path exists..."
debug_output "DEBUG: ls -la $PATH_TO_CHECK:"
if [ "$DEBUG_MODE" = true ]; then
    ls -la "$PATH_TO_CHECK" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

# Debug: Test basic git log without path restriction
debug_output "DEBUG: Testing basic git log between commits (no path restriction):"
if [ "$DEBUG_MODE" = true ]; then
    git log --oneline "$PROD_HASH..$UAT_HASH" | head -10 >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

# Debug: Test git log with path restriction
debug_output "DEBUG: Testing git log with path restriction:"
if [ "$DEBUG_MODE" = true ]; then
    git log --oneline "$PROD_HASH..$UAT_HASH" -- "$PATH_TO_CHECK" | head -10 >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

# Debug: Try reverse order (UAT..PROD instead of PROD..UAT)
debug_output "DEBUG: Testing reverse commit range (UAT..PROD):"
if [ "$DEBUG_MODE" = true ]; then
    git log --oneline "$UAT_HASH..$PROD_HASH" -- "$PATH_TO_CHECK" | head -10 >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

# Debug: Check if there are any commits at all in the path
debug_output "DEBUG: Recent commits in the path (last 10):"
if [ "$DEBUG_MODE" = true ]; then
    git log --oneline -10 -- "$PATH_TO_CHECK" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
fi

{
echo "=== Analyzing commits between PROD and UAT ==="
echo "Repository Path: $REPO_PATH"
echo "PROD: $PROD_HASH"
echo "UAT: $UAT_HASH"
echo "Path: $PATH_TO_CHECK"
echo ""

# Debug output for commit range
if [ "$DEBUG_MODE" = true ]; then
    echo "DEBUG: Using commit range: $PROD_HASH..$UAT_HASH"
    echo "DEBUG: Checking if there are any commits in this range..."
    COMMIT_COUNT=$(git rev-list --count "$PROD_HASH..$UAT_HASH" -- "$PATH_TO_CHECK" 2>/dev/null || echo "0")
    echo "DEBUG: Found $COMMIT_COUNT commits in range with path restriction"
    COMMIT_COUNT_NO_PATH=$(git rev-list --count "$PROD_HASH..$UAT_HASH" 2>/dev/null || echo "0")
    echo "DEBUG: Found $COMMIT_COUNT_NO_PATH commits in range without path restriction"
    echo ""

    # Try reverse range if forward range is empty
    if [ "$COMMIT_COUNT" -eq 0 ]; then
        echo "DEBUG: Forward range is empty, trying reverse range..."
        REVERSE_COUNT=$(git rev-list --count "$UAT_HASH..$PROD_HASH" -- "$PATH_TO_CHECK" 2>/dev/null || echo "0")
        echo "DEBUG: Found $REVERSE_COUNT commits in reverse range"
        if [ "$REVERSE_COUNT" -gt 0 ]; then
            echo "DEBUG: Using reverse range instead!"
            TEMP_HASH="$PROD_HASH"
            PROD_HASH="$UAT_HASH"
            UAT_HASH="$TEMP_HASH"
            echo "DEBUG: Swapped hashes - now using $PROD_HASH..$UAT_HASH"
        fi
        echo ""
    fi
else
    # Still perform the range check logic but without debug output
    COMMIT_COUNT=$(git rev-list --count "$PROD_HASH..$UAT_HASH" -- "$PATH_TO_CHECK" 2>/dev/null || echo "0")
    if [ "$COMMIT_COUNT" -eq 0 ]; then
        REVERSE_COUNT=$(git rev-list --count "$UAT_HASH..$PROD_HASH" -- "$PATH_TO_CHECK" 2>/dev/null || echo "0")
        if [ "$REVERSE_COUNT" -gt 0 ]; then
            TEMP_HASH="$PROD_HASH"
            PROD_HASH="$UAT_HASH"
            UAT_HASH="$TEMP_HASH"
        fi
    fi
fi

# 1. Get list of users who merged (commit authors and committers)
echo "=== 1. USERS WHO MERGED ==="
git log --pretty=format:"%cn <%ce>" $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK | sort | uniq
echo ""
echo ""

# 2. Get files changed between the commits
echo "=== 2. FILES CHANGED ==="
git diff --name-only $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK
echo ""
echo ""

# Full commit details with PR URLs
echo "=== FULL COMMIT DETAILS WITH PR LINKS ==="
git log --oneline --graph --decorate $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK | while IFS= read -r line; do
    echo "$line"
    # Extract PR number from commit message (look for "Merged PR 12345:")
    pr_number=$(echo "$line" | grep -oE 'Merged PR [0-9]+' | grep -oE '[0-9]+')
    if [[ -n "$pr_number" ]]; then
        echo "  → PR Link: https://dev.azure.com/BetagyDevOps/Frontend/_git/kingmakers-frontend/pullrequest/$pr_number"
    fi
done

echo ""
echo "=== ANALYSIS COMPLETE ==="
echo ""
echo "Report saved to: $OUTPUT_FILE"

} | tee "$OUTPUT_FILE"

# Generate Markdown-friendly summary for Slack
{
echo "# 🚀 PRE-RELEASE SUMMARY - $(date '+%B %d, %Y' | tr '[:lower:]' '[:upper:]')"
echo ""
echo "**📦 Component:** \`$PATH_TO_CHECK\`"
echo "**🔄 From:** \`${PROD_HASH:0:8}\` → **To:** \`${UAT_HASH:0:8}\`"
echo ""

# Count commits and users
COMMIT_COUNT=$(git rev-list --count "$PROD_HASH..$UAT_HASH" -- "$PATH_TO_CHECK" 2>/dev/null || echo "0")
USER_COUNT=$(git log --pretty=format:"%cn" $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK | sort | uniq | wc -l | tr -d ' ')
FILE_COUNT=$(git diff --name-only $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK | wc -l | tr -d ' ')

echo "**📊 Summary:** $COMMIT_COUNT commits by $USER_COUNT contributor(s), $FILE_COUNT file(s) changed"
echo ""

# Contributors
echo "## 👥 Contributors"
git log --pretty=format:"%cn" $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK | sort | uniq | sed 's/^/- /'
echo ""

# Key changes (PRs)
echo "## 🔗 Pull Requests"
git log --pretty=format:"%H|%s|%cn" --decorate $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK | while IFS='|' read -r commit_hash commit_msg committer_name; do
    pr_number=$(echo "$commit_msg" | grep -oE 'Merged PR [0-9]+' | grep -oE '[0-9]+')
    if [[ -n "$pr_number" ]]; then
        # Clean up the commit message for Markdown
        clean_msg=$(echo "$commit_msg" | sed 's/^[* |\\]*[a-f0-9]* //' | sed 's/Merged PR [0-9]*: //')
        echo "- [$clean_msg ($committer_name)](https://dev.azure.com/BetagyDevOps/Frontend/_git/kingmakers-frontend/pullrequest/$pr_number)"
    fi
done
echo ""

# Files changed (limit to first 10 for readability)
echo "## 📁 Files Changed"
file_list=$(git diff --name-only $PROD_HASH..$UAT_HASH -- $PATH_TO_CHECK)
file_count=$(echo "$file_list" | wc -l | tr -d ' ')
if [ "$file_count" -gt 10 ]; then
    echo "$file_list" | head -10 | sed 's/^/- `/' | sed 's/$/`/'
    echo "- ... and $((file_count - 10)) more files"
else
    echo "$file_list" | sed 's/^/- `/' | sed 's/$/`/'
fi

} > "$SLACK_FILE"

echo ""
echo "Analysis complete!"
echo "📄 Detailed report: $OUTPUT_FILE"
echo "📝 Markdown summary: $SLACK_FILE"
echo ""
echo "📋 Open $SLACK_FILE in a Markdown viewer, then copy-paste the rendered output to Slack!"
