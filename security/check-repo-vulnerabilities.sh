#!/bin/bash

# Repository Security Vulnerability Scanner
# Checks Git history for potentially sensitive information

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 --repo-path <path> [--output-file <file>] [--verbose]"
    echo ""
    echo "Required arguments:"
    echo "  --repo-path <path>       Path to the git repository to scan"
    echo ""
    echo "Optional arguments:"
    echo "  --output-file <file>     Save results to file (default: security_scan_TIMESTAMP.txt)"
    echo "  --verbose               Show detailed output"
    echo "  --help                  Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --repo-path ~/work/your-repo --output-file security_report.txt"
}

# Initialize variables
REPO_PATH=""
OUTPUT_FILE=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-path)
            REPO_PATH="$2"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
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
if [[ -z "$REPO_PATH" ]]; then
    echo "Error: Missing required --repo-path argument"
    echo ""
    show_usage
    exit 1
fi

# Expand tilde in REPO_PATH
REPO_PATH="${REPO_PATH/#\~/$HOME}"

# Set default output file if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="security_scan_${TIMESTAMP}.txt"
fi

# Change to repository directory
if [[ ! -d "$REPO_PATH" ]]; then
    echo -e "${RED}Error: Repository path does not exist: $REPO_PATH${NC}"
    exit 1
fi

cd "$REPO_PATH" || { echo -e "${RED}Error: Could not change to repository directory${NC}"; exit 1; }

# Check if it's a git repository
if [[ ! -d ".git" ]]; then
    echo -e "${RED}Error: Not a git repository: $REPO_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Starting security vulnerability scan...${NC}"
echo "Repository: $REPO_PATH"
echo "Output file: $OUTPUT_FILE"
echo ""

# Initialize output file
cat > "$OUTPUT_FILE" << EOF
SECURITY VULNERABILITY SCAN REPORT
Generated on: $(date)
Repository: $REPO_PATH
=====================================

EOF

# Function to log both to console and file
log_result() {
    local severity=$1
    local message=$2
    local color=""

    case $severity in
        "HIGH") color=$RED ;;
        "MEDIUM") color=$YELLOW ;;
        "LOW") color=$GREEN ;;
        "INFO") color=$BLUE ;;
    esac

    echo -e "${color}[$severity] $message${NC}"
    echo "[$severity] $message" >> "$OUTPUT_FILE"
}

# 1. Check for common sensitive patterns in Git history
echo -e "${BLUE}🔑 Scanning for sensitive patterns in commit history...${NC}"
echo "1. SENSITIVE PATTERNS SCAN" >> "$OUTPUT_FILE"
echo "=========================" >> "$OUTPUT_FILE"

# Common sensitive patterns
declare -A patterns=(
    ["API Keys"]="[aA][pP][iI][_-]?[kK][eE][yY]|[aA][pP][iI][kK][eE][yY]"
    ["Passwords"]="[pP][aA][sS][sS][wW][oO][rR][dD].*[=:].*['\"][^'\"]{6,}['\"]"
    ["Tokens"]="[tT][oO][kK][eE][nN].*[=:].*['\"][^'\"]{10,}['\"]"
    ["Private Keys"]="-----BEGIN [A-Z ]*PRIVATE KEY-----"
    ["AWS Keys"]="AKIA[0-9A-Z]{16}"
    ["Database URLs"]="[a-zA-Z]+://[^\\s:@]+:[^\\s:@]+@[^\\s]+:[0-9]+/[^\\s]+"
    ["JWT Tokens"]="eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*"
    ["Email Addresses"]="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
    ["Credit Cards"]="[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}"
    ["SSH Keys"]="ssh-rsa|ssh-ed25519|ssh-dss"
    ["Generic Secrets"]="[sS][eE][cC][rR][eE][tT].*[=:].*['\"][^'\"]{8,}['\"]"
)

for pattern_name in "${!patterns[@]}"; do
    pattern="${patterns[$pattern_name]}"
    if $VERBOSE; then
        echo "  Checking for: $pattern_name"
    fi

    # Search in current files
    current_matches=$(git grep -i -E "$pattern" 2>/dev/null | wc -l)

    # Search in ALL Git history - improved method
    # Method 1: Search in all commit diffs
    history_matches=$(git log --all --full-history -p -S "$pattern" --regexp-ignore-case 2>/dev/null | wc -l)

    # Method 2: Search in all file contents across all commits
    git_log_matches=$(git log --all --full-history --oneline --grep="$pattern" -i 2>/dev/null | wc -l)

    # Method 3: Search in actual file content changes (more thorough)
    content_matches=$(git rev-list --all | xargs -I {} git grep -l -i -E "$pattern" {} -- 2>/dev/null | wc -l)

    if [[ $current_matches -gt 0 ]]; then
        log_result "HIGH" "$pattern_name found in current files: $current_matches matches"
        if $VERBOSE; then
            echo "  Current file matches:" >> "$OUTPUT_FILE"
            git grep -n -i -E "$pattern" 2>/dev/null >> "$OUTPUT_FILE" || true
            echo "" >> "$OUTPUT_FILE"
        fi
    fi

    if [[ $history_matches -gt 0 ]]; then
        log_result "MEDIUM" "$pattern_name found in Git history diffs: $history_matches lines"
        if $VERBOSE; then
            echo "  Historical diff matches:" >> "$OUTPUT_FILE"
            git log --all --full-history -p -S "$pattern" --regexp-ignore-case --oneline 2>/dev/null | head -10 >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    fi

    if [[ $git_log_matches -gt 0 ]]; then
        log_result "MEDIUM" "$pattern_name found in commit messages: $git_log_matches commits"
        if $VERBOSE; then
            echo "  Commit message matches:" >> "$OUTPUT_FILE"
            git log --all --full-history --oneline --grep="$pattern" -i 2>/dev/null >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    fi

    if [[ $content_matches -gt 0 ]]; then
        log_result "HIGH" "$pattern_name found in historical file contents: $content_matches occurrences"
        if $VERBOSE; then
            echo "  Historical content matches (showing first 10):" >> "$OUTPUT_FILE"
            git rev-list --all | head -50 | xargs -I {} git grep -l -i -E "$pattern" {} -- 2>/dev/null | head -10 >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    fi
done

# Additional deep history scan for common secret patterns
echo -e "${BLUE}🕵️  Performing deep history scan for secrets...${NC}"
echo "" >> "$OUTPUT_FILE"
echo "1.1 DEEP HISTORY SCAN" >> "$OUTPUT_FILE"
echo "=====================" >> "$OUTPUT_FILE"

# Get all commits and scan each one
total_commits=$(git rev-list --all --count 2>/dev/null)
log_result "INFO" "Scanning $total_commits total commits in repository history"

# Sample a subset of commits for performance (last 100 commits + random sample)
recent_commits=$(git rev-list --all -n 100 2>/dev/null)
sample_commits=$(git rev-list --all 2>/dev/null | shuf | head -50)
all_scan_commits=$(echo -e "$recent_commits\n$sample_commits" | sort | uniq)

secret_patterns="password|secret|key|token|credential|api[_-]?key|private[_-]?key|access[_-]?token"
commits_with_secrets=0

echo "$all_scan_commits" | while read -r commit; do
    if [[ -n "$commit" ]]; then
        # Check if this commit contains potential secrets
        if git show "$commit" 2>/dev/null | grep -i -E "$secret_patterns" >/dev/null 2>&1; then
            commits_with_secrets=$((commits_with_secrets + 1))
            log_result "MEDIUM" "Potential secrets found in commit: $commit"
            if $VERBOSE; then
                echo "  Commit details:" >> "$OUTPUT_FILE"
                git show --name-only --oneline "$commit" 2>/dev/null >> "$OUTPUT_FILE"
                echo "  Matching lines:" >> "$OUTPUT_FILE"
                git show "$commit" 2>/dev/null | grep -i -E "$secret_patterns" | head -5 >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
            fi
        fi
    fi
done

echo "" >> "$OUTPUT_FILE"

# 2. Check for large files that might contain sensitive data
echo -e "${BLUE}📦 Scanning for large files in history...${NC}"
echo "2. LARGE FILES SCAN" >> "$OUTPUT_FILE"
echo "==================" >> "$OUTPUT_FILE"

large_files=$(git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | sed -n 's/^blob //p' | sort --numeric-sort --key=2 | tail -20)

if [[ -n "$large_files" ]]; then
    log_result "INFO" "Top 20 largest files in Git history:"
    echo "$large_files" >> "$OUTPUT_FILE"

    # Check if any large files are binary and might be sensitive
    while read -r line; do
        size=$(echo "$line" | awk '{print $2}')
        filename=$(echo "$line" | awk '{print $3}')

        if [[ $size -gt 1048576 ]]; then # > 1MB
            size_mb=$((size / 1048576))
            if [[ "$filename" =~ \.(db|sqlite|sql|dump|bak|key|pem|p12|pfx)$ ]]; then
                log_result "HIGH" "Large potentially sensitive file: $filename (${size_mb}MB)"
            else
                log_result "LOW" "Large file: $filename (${size_mb}MB)"
            fi
        fi
    done <<< "$large_files"
fi

echo "" >> "$OUTPUT_FILE"

# 3. Check for hardcoded secrets in file extensions
echo -e "${BLUE}📄 Scanning specific file types for secrets...${NC}"
echo "3. FILE TYPE ANALYSIS" >> "$OUTPUT_FILE"
echo "====================" >> "$OUTPUT_FILE"

# Risky file extensions
risky_extensions=("*.env" "*.config" "*.conf" "*.ini" "*.properties" "*.yaml" "*.yml" "*.json" "*.xml")

for ext in "${risky_extensions[@]}"; do
    files_found=$(git log --name-only --all --pretty=format: -- "$ext" | sort | uniq | wc -l)
    if [[ $files_found -gt 0 ]]; then
        log_result "MEDIUM" "Found $files_found $ext files in Git history"
        if $VERBOSE; then
            git log --name-only --all --pretty=format: -- "$ext" | sort | uniq >> "$OUTPUT_FILE"
        fi
    fi
done

echo "" >> "$OUTPUT_FILE"

# 4. Check for removed sensitive files (might indicate cleanup)
echo -e "${BLUE}🗑️  Scanning for deleted sensitive files...${NC}"
echo "4. DELETED FILES ANALYSIS" >> "$OUTPUT_FILE"
echo "=========================" >> "$OUTPUT_FILE"

deleted_sensitive=$(git log --diff-filter=D --summary --all | grep -E '\.(key|pem|p12|pfx|env|config|sql|dump)$' | wc -l)
if [[ $deleted_sensitive -gt 0 ]]; then
    log_result "HIGH" "Found $deleted_sensitive deleted sensitive files (possible cleanup attempts)"
    git log --diff-filter=D --summary --all | grep -E '\.(key|pem|p12|pfx|env|config|sql|dump)$' >> "$OUTPUT_FILE"
fi

# 5. Check commit messages for sensitive information
echo -e "${BLUE}💬 Scanning commit messages...${NC}"
echo "5. COMMIT MESSAGE ANALYSIS" >> "$OUTPUT_FILE"
echo "=========================" >> "$OUTPUT_FILE"

sensitive_commits=$(git log --all --grep="password\|secret\|key\|token\|credential" --oneline | wc -l)
if [[ $sensitive_commits -gt 0 ]]; then
    log_result "MEDIUM" "Found $sensitive_commits commits with potentially sensitive keywords in messages"
    if $VERBOSE; then
        git log --all --grep="password\|secret\|key\|token\|credential" --oneline >> "$OUTPUT_FILE"
    fi
fi

# 6. Check for binary files that might contain secrets
echo -e "${BLUE}🔒 Scanning for binary files...${NC}"
echo "6. BINARY FILES ANALYSIS" >> "$OUTPUT_FILE"
echo "========================" >> "$OUTPUT_FILE"

binary_files=$(git log --name-only --all --pretty=format: | sort | uniq | xargs -I {} sh -c 'if file "{}" 2>/dev/null | grep -q "binary\|executable"; then echo "{}"; fi' 2>/dev/null | head -20)

if [[ -n "$binary_files" ]]; then
    log_result "LOW" "Found binary files that could potentially contain embedded secrets:"
    echo "$binary_files" >> "$OUTPUT_FILE"
fi

# Summary
echo ""
echo -e "${BLUE}📊 Scan Complete!${NC}"
echo ""
echo "SCAN SUMMARY" >> "$OUTPUT_FILE"
echo "============" >> "$OUTPUT_FILE"
echo "Scan completed on: $(date)" >> "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE" >> "$OUTPUT_FILE"
echo ""
echo "RECOMMENDATIONS:" >> "$OUTPUT_FILE"
echo "- Review all HIGH severity findings immediately" >> "$OUTPUT_FILE"
echo "- Consider using git-secrets or truffleHog for deeper analysis" >> "$OUTPUT_FILE"
echo "- Use BFG Repo-Cleaner or git filter-branch to remove sensitive data if found" >> "$OUTPUT_FILE"
echo "- Implement pre-commit hooks to prevent future leaks" >> "$OUTPUT_FILE"

log_result "INFO" "Security scan completed. Report saved to: $OUTPUT_FILE"

# Check if any HIGH severity issues were found
high_issues=$(grep "^\[HIGH\]" "$OUTPUT_FILE" | wc -l)
if [[ $high_issues -gt 0 ]]; then
    echo ""
    log_result "HIGH" "⚠️  ATTENTION: $high_issues high-severity security issues found!"
    echo "Please review the report immediately and take appropriate action."
    exit 1
else
    log_result "INFO" "✅ No high-severity issues detected in basic scan."
fi
