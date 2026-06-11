#!/bin/bash
################################################################################
# FortiCNAPP IaC Security Scanner - Reusable Script
# 
# Usage:
#   ./forticnapp-scan.sh [OPTIONS] [FILE_OR_FOLDER]
#
# Environment Variables (Required):
#   LW_ACCESS          - FortiCNAPP API Access Key
#   LW_SECRET          - FortiCNAPP API Secret Key
#   LACEWORK_ACCOUNT   - FortiCNAPP Account ID
#
# Environment Variables (Optional):
#   SCAN_REPORT_DIR    - Output directory for scan results (default: forticnapp-scan-reports)
#   CONTINUE_ON_ERROR  - Continue scanning if one fails (default: false)
#
# Options:
#   -h, --help         Show this help message
#   -v, --verbose      Enable verbose output
#   -o, --output DIR   Set output directory for reports
#
# Examples:
#   ./forticnapp-scan.sh vpc-stack.yaml
#   ./forticnapp-scan.sh -o /tmp/reports /path/to/templates
#   ./forticnapp-scan.sh *.yaml
#
################################################################################

set -e

# Default values
SCAN_REPORT_DIR="${SCAN_REPORT_DIR:-forticnapp-scan-reports}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-false}"
VERBOSE="${VERBOSE:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

show_help() {
    head -n 30 "$0" | grep "^#" | sed 's/^#//g'
}

# Validate environment variables
validate_env() {
    local missing=0
    
    if [[ -z "$LW_ACCESS" ]]; then
        log_error "LW_ACCESS environment variable not set"
        missing=1
    fi
    
    if [[ -z "$LW_SECRET" ]]; then
        log_error "LW_SECRET environment variable not set"
        missing=1
    fi
    
    if [[ -z "$LACEWORK_ACCOUNT" ]]; then
        log_error "LACEWORK_ACCOUNT environment variable not set"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        log_error "Missing required environment variables"
        return 1
    fi
    
    return 0
}

# Authenticate with FortiCNAPP and get token
get_api_token() {
    log_info "Authenticating with FortiCNAPP..."
    
    TOKEN_RESPONSE=$(curl -s -X POST "https://${LACEWORK_ACCOUNT}.lacework.net/api/v2/access/tokens" \
      -u "${LW_ACCESS}:${LW_SECRET}" \
      -H "Content-Type: application/json" \
      -d '{"expiryTime":3600}')
    
    local API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.data[0].token' 2>/dev/null || echo "")
    
    if [[ -z "$API_TOKEN" ]] || [[ "$API_TOKEN" == "null" ]]; then
        log_error "Failed to authenticate with FortiCNAPP API"
        log_verbose "Response: $TOKEN_RESPONSE"
        return 1
    fi
    
    log_success "FortiCNAPP authentication successful"
    echo "$API_TOKEN"
}

# Scan a single file with FortiCNAPP
scan_file() {
    local file="$1"
    local api_token="$2"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    log_info "Scanning: $file"
    
    # Encode file content as base64
    local payload=$(cat "$file" | base64 -w 0)
    
    # Call FortiCNAPP API
    local scan_response=$(curl -s -X POST "https://${LACEWORK_ACCOUNT}.lacework.net/api/v2/CloudFormationTemplate/scan" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${api_token}" \
      -d '{"template":"'"${payload}"'"}')
    
    log_verbose "Scan response: $scan_response"
    
    # Extract filename for report
    local filename=$(basename "$file")
    local report_file="${SCAN_REPORT_DIR}/${filename}.scan.json"
    
    # Save scan results
    echo "$scan_response" > "$report_file"
    
    # Check for vulnerabilities in response
    local issue_count=$(echo "$scan_response" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$issue_count" -gt 0 ]]; then
        log_warning "Found issues in $filename: $issue_count"
    else
        log_success "No issues found in $filename"
    fi
    
    return 0
}

# Generate HTML report
generate_html_report() {
    local html_file="${SCAN_REPORT_DIR}/scan-report.html"
    
    log_info "Generating HTML report..."
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>FortiCNAPP IaC Security Scan Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 40px 20px;
            text-align: center;
        }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header p { opacity: 0.9; }
        .content { padding: 30px; }
        .scan-file {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .scan-file h3 { color: #2c3e50; margin-bottom: 10px; }
        pre {
            background: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            font-size: 12px;
            max-height: 400px;
            overflow-y: auto;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-card h4 { font-size: 14px; opacity: 0.9; margin-bottom: 10px; }
        .stat-card .number { font-size: 32px; font-weight: bold; }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 FortiCNAPP IaC Security Scan Report</h1>
            <p>Scan Date: <strong>${SCAN_DATE}</strong></p>
        </div>
        <div class="content">
            <div class="summary">
                <div class="stat-card">
                    <h4>Files Scanned</h4>
                    <div class="number">${FILE_COUNT}</div>
                </div>
                <div class="stat-card">
                    <h4>Account</h4>
                    <div class="number">${LACEWORK_ACCOUNT}</div>
                </div>
            </div>
            <h2>Scan Results</h2>
            ${SCAN_RESULTS}
        </div>
        <div class="footer">
            Generated by FortiCNAPP IaC Scanner | $(date)
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "HTML report generated: $html_file"
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -o|--output)
                SCAN_REPORT_DIR="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Get target files/folders
    local targets=("$@")
    
    if [[ ${#targets[@]} -eq 0 ]]; then
        log_error "No files or folders specified"
        show_help
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$SCAN_REPORT_DIR"
    log_info "Output directory: $SCAN_REPORT_DIR"
    
    # Validate environment
    if ! validate_env; then
        exit 1
    fi
    
    # Get API token
    local api_token
    api_token=$(get_api_token) || exit 1
    
    # Collect all files to scan
    local files_to_scan=()
    for target in "${targets[@]}"; do
        if [[ -f "$target" ]]; then
            files_to_scan+=("$target")
        elif [[ -d "$target" ]]; then
            while IFS= read -r -d '' file; do
                files_to_scan+=("$file")
            done < <(find "$target" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.tf" \) -print0)
        elif [[ "$target" == *\** ]]; then
            # Handle glob patterns
            for file in $target; do
                if [[ -f "$file" ]]; then
                    files_to_scan+=("$file")
                fi
            done
        fi
    done
    
    if [[ ${#files_to_scan[@]} -eq 0 ]]; then
        log_error "No IaC files found to scan"
        exit 1
    fi
    
    log_info "Found ${#files_to_scan[@]} file(s) to scan"
    
    # Scan files
    local success_count=0
    local fail_count=0
    local scan_results=""
    
    echo ""
    echo "================================"
    echo "Starting FortiCNAPP Scan"
    echo "================================"
    echo ""
    
    for file in "${files_to_scan[@]}"; do
        if scan_file "$file" "$api_token"; then
            ((success_count++))
            scan_results+="<div class=\"scan-file\"><h3>✓ $(basename "$file")</h3><p>Scanned successfully</p></div>"
        else
            ((fail_count++))
            scan_results+="<div class=\"scan-file\"><h3>✗ $(basename "$file")</h3><p>Scan failed</p></div>"
            if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
                exit 1
            fi
        fi
    done
    
    echo ""
    echo "================================"
    echo "Scan Complete"
    echo "================================"
    log_success "Scanned: $success_count files"
    if [[ $fail_count -gt 0 ]]; then
        log_warning "Failed: $fail_count files"
    fi
    echo ""
    
    # Generate HTML report
    SCAN_DATE=$(date)
    FILE_COUNT=${#files_to_scan[@]}
    SCAN_RESULTS="$scan_results"
    generate_html_report
    
    log_success "All scan results saved to: $SCAN_REPORT_DIR"
    
    return $fail_count
}

# Run main
main "$@"
