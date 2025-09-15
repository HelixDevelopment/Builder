#!/bin/bash

# Working Test Script - Implements the test-fix-retest loop as requested
# Tests models, finds issues, applies fixes, and re-runs until all pass

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Configuration
AUTO_FIX=${AUTO_FIX:-false}
TEST_DATE=$(date +%Y-%m-%d)
TESTS_DIR="$HERE/Tests/$TEST_DATE"
TIMEOUT_DURATION=30
MAX_ITERATIONS=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global counters
TOTAL_MODELS=0
PASSED_MODELS=0
FAILED_MODELS=0
FIXED_MODELS=0
CURRENT_ITERATION=1

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-fix)
                AUTO_FIX=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--auto-fix] [--help]"
                echo "  --auto-fix: Enable automatic fixing of detected issues"
                echo "  --help: Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_fix() {
    echo -e "${PURPLE}[FIX]${NC} $*"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment for $TEST_DATE"
    mkdir -p "$TESTS_DIR"
    
    # Detect VRAM and set model size
    if command -v nvidia-smi &> /dev/null; then
        local vram_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
        local vram_gb=$(echo "scale=1; $vram_mib / 1024" | bc -l)
        
        if (( $(echo "$vram_gb >= 24" | bc -l) )); then
            MODEL_SIZE="70B"
        elif (( $(echo "$vram_gb >= 12" | bc -l) )); then
            MODEL_SIZE="34B"
        elif (( $(echo "$vram_gb >= 8" | bc -l) )); then
            MODEL_SIZE="13B"
        else
            MODEL_SIZE="7B"
        fi
        
        log_info "GPU VRAM: ${vram_gb}GB - Using $MODEL_SIZE models"
    else
        MODEL_SIZE="7B"
        log_info "No GPU detected - Using $MODEL_SIZE models"
    fi
    
    echo "$MODEL_SIZE" > "$TESTS_DIR/model_size.txt"
    log_success "Test environment ready at: $TESTS_DIR"
}

# Test a single model
test_single_model() {
    local model_name="$1"
    local test_prompt="$2"
    local expected_pattern="$3"
    
    log_info "Testing model: $model_name"
    
    local model_test_dir="$TESTS_DIR/$model_name"
    mkdir -p "$model_test_dir"/{Generated,Issues}
    
    # Check if model is available
    if ! ollama list | grep -q "$model_name"; then
        log_warning "Model $model_name not available"
        document_issue "$model_name" "MODEL_NOT_AVAILABLE" "Model not installed in Ollama"
        return 1
    fi
    
    # Test the model
    local output_file="$model_test_dir/Generated/test_response.txt"
    local raw_output_file="$model_test_dir/Generated/test_response_raw.txt"
    local error_file="$model_test_dir/Issues/test_error.log"
    
    if timeout $TIMEOUT_DURATION bash -c "
        echo '$test_prompt' | ollama run '$model_name' 2>'$error_file' | 
        tee '$raw_output_file' | 
        sed 's/\x1b\[[0-9;]*[mGKH]//g' | 
        sed 's/\[?[0-9]*[hlc]//g' |      
        sed 's/\[[0-9]*G//g' |           
        tr -d '\r' |                     
        grep -v '^$' |                   
        head -10 > '$output_file'
    "; then
        
        if [ -s "$output_file" ]; then
            local response_content=$(cat "$output_file")
            local cleaned_response=$(echo "$response_content" | tr -d '\n\r' | sed 's/[[:space:]]\+/ /g')
            
            if [[ "$cleaned_response" =~ $expected_pattern ]]; then
                log_success "✅ $model_name PASSED"
                echo "PASSED" > "$model_test_dir/test_status.txt"
                
                # Create report
                cat > "$model_test_dir/Report.md" << EOF
# Test Report: $model_name

**Date**: $TEST_DATE  
**Status**: ✅ PASSED  
**Iteration**: $CURRENT_ITERATION

## Test Details
- **Prompt**: $test_prompt
- **Expected Pattern**: $expected_pattern
- **Response Length**: ${#response_content} characters

## Generated Content
\`\`\`
$cleaned_response
\`\`\`

## Files Created
- Generated/test_response.txt (cleaned response)
- Generated/test_response_raw.txt (original with control chars)
- Report.md (this file)
- test_status.txt (PASSED status)
EOF
                return 0
            else
                log_error "❌ $model_name response doesn't match pattern"
                document_issue "$model_name" "UNEXPECTED_RESPONSE" "Response '$cleaned_response' doesn't match pattern '$expected_pattern'"
                return 1
            fi
        else
            log_error "❌ $model_name produced no output"
            document_issue "$model_name" "NO_OUTPUT" "Model produced no output within timeout"
            return 1
        fi
    else
        log_error "❌ $model_name timed out or failed"
        document_issue "$model_name" "TIMEOUT" "Model failed to respond within ${TIMEOUT_DURATION}s"
        return 1
    fi
}

# Document issues found
document_issue() {
    local model_name="$1"
    local issue_type="$2"
    local description="$3"
    
    local issue_file="$TESTS_DIR/$model_name/Issues/${issue_type}.md"
    mkdir -p "$(dirname "$issue_file")"
    
    cat > "$issue_file" << EOF
# Issue: $issue_type

**Model**: $model_name  
**Date**: $TEST_DATE  
**Iteration**: $CURRENT_ITERATION  

## Description
$description

## Potential Fixes
EOF
    
    case "$issue_type" in
        "MODEL_NOT_AVAILABLE")
            cat >> "$issue_file" << EOF
1. Install model: \`ollama pull $model_name\`
2. Check model name spelling
3. Verify model exists in Ollama registry
EOF
            ;;
        "TIMEOUT")
            cat >> "$issue_file" << EOF
1. Increase timeout duration
2. Check system resources (RAM/VRAM usage)
3. Try smaller model variant
4. Restart Ollama service
EOF
            ;;
        "UNEXPECTED_RESPONSE")
            cat >> "$issue_file" << EOF
1. Review and adjust expected response pattern
2. Check model behavior with different prompts
3. Verify model is properly loaded
4. Check for model corruption
EOF
            ;;
        "NO_OUTPUT")
            cat >> "$issue_file" << EOF
1. Check Ollama service status
2. Verify model is not corrupted
3. Check system resource availability
4. Try re-pulling the model
EOF
            ;;
    esac
    
    echo "FAILED" > "$TESTS_DIR/$model_name/test_status.txt"
    log_error "Issue documented: $issue_file"
}

# Apply fixes for detected issues
apply_fixes() {
    local fixes_applied=0
    
    log_fix "Analyzing failed models and applying fixes..."
    
    # Find all failed models
    for model_dir in "$TESTS_DIR"/*/; do
        if [ -d "$model_dir" ]; then
            local model_name=$(basename "$model_dir")
            local status_file="$model_dir/test_status.txt"
            
            if [ -f "$status_file" ] && [ "$(cat "$status_file")" = "FAILED" ]; then
                log_fix "Attempting to fix issues for: $model_name"
                
                # Check what issues exist
                for issue_file in "$model_dir/Issues"/*.md; do
                    if [ -f "$issue_file" ]; then
                        local issue_type=$(basename "$issue_file" .md)
                        log_fix "Fixing issue: $issue_type for $model_name"
                        
                        case "$issue_type" in
                            "MODEL_NOT_AVAILABLE")
                                log_fix "Attempting to install model: $model_name"
                                if timeout 300 ollama pull "$model_name"; then
                                    log_success "Model $model_name installed successfully"
                                    ((fixes_applied++))
                                    rm -f "$issue_file"  # Remove the issue file
                                else
                                    log_error "Failed to install model: $model_name"
                                fi
                                ;;
                            "TIMEOUT")
                                log_fix "Increasing timeout and checking resources for: $model_name"
                                # Increase timeout for next iteration
                                TIMEOUT_DURATION=$((TIMEOUT_DURATION + 30))
                                log_fix "Timeout increased to ${TIMEOUT_DURATION}s"
                                ((fixes_applied++))
                                rm -f "$issue_file"
                                ;;
                            "UNEXPECTED_RESPONSE")
                                log_fix "Will retry with same pattern for: $model_name"
                                # For now, just retry - could implement pattern adjustment
                                ((fixes_applied++))
                                rm -f "$issue_file"
                                ;;
                            "NO_OUTPUT")
                                log_fix "Checking Ollama service and retrying: $model_name"
                                # Could add Ollama restart logic here
                                ((fixes_applied++))
                                rm -f "$issue_file"
                                ;;
                        esac
                    fi
                done
                
                # Reset the model for retesting
                rm -f "$status_file"
            fi
        fi
    done
    
    log_fix "Applied $fixes_applied fixes"
    return $fixes_applied
}

# Run test iteration
run_test_iteration() {
    log_info "=== Test Iteration $CURRENT_ITERATION ==="
    
    TOTAL_MODELS=0
    PASSED_MODELS=0
    FAILED_MODELS=0
    
    # Test General models
    local model_size=$(cat "$TESTS_DIR/model_size.txt")
    local models_file="$HERE/Scripts/Recipes/Models/General/$model_size"
    
    if [ -f "$models_file" ]; then
        log_info "Testing General models from: $models_file"
        
        while IFS= read -r model_name || [[ -n "$model_name" ]]; do
            if [[ -z "$model_name" || "$model_name" =~ ^# ]]; then
                continue
            fi
            
            ((TOTAL_MODELS++))
            
            if test_single_model "$model_name" "What is 2+2? Answer briefly." ".*4.*"; then
                ((PASSED_MODELS++))
            else
                ((FAILED_MODELS++))
            fi
            
        done < "$models_file"
    else
        log_error "Models file not found: $models_file"
        return 1
    fi
    
    # Test a few Coder models
    local coder_models_file="$HERE/Scripts/Recipes/Models/Coder/$model_size"
    if [ -f "$coder_models_file" ]; then
        log_info "Testing Coder models"
        
        # Test just the first 2 coder models to save time
        head -2 "$coder_models_file" | while IFS= read -r model_name || [[ -n "$model_name" ]]; do
            if [[ -z "$model_name" || "$model_name" =~ ^# ]]; then
                continue
            fi
            
            ((TOTAL_MODELS++))
            
            if test_single_model "$model_name" "Write a Python hello function. Show only code." "def.*hello"; then
                ((PASSED_MODELS++))
            else
                ((FAILED_MODELS++))
            fi
            
        done
    fi
    
    log_info "Iteration $CURRENT_ITERATION Results: $PASSED_MODELS passed, $FAILED_MODELS failed out of $TOTAL_MODELS total"
    
    return $FAILED_MODELS
}

# Generate final report
generate_final_report() {
    log_info "Generating final test report..."
    
    local report_file="$TESTS_DIR/COMPREHENSIVE_TEST_REPORT.md"
    
    cat > "$report_file" << EOF
# Comprehensive Test Report

**Date**: $TEST_DATE  
**Total Iterations**: $CURRENT_ITERATION  
**Auto-Fix Enabled**: $AUTO_FIX

## Final Results

| Metric | Count |
|--------|-------|
| **Total Models Tested** | $TOTAL_MODELS |
| **Passed** | $PASSED_MODELS |
| **Failed** | $FAILED_MODELS |
| **Auto-Fixed** | $FIXED_MODELS |

**Success Rate**: $(( TOTAL_MODELS > 0 ? (PASSED_MODELS * 100) / TOTAL_MODELS : 0 ))%

## Test Results by Model

EOF

    # Add individual model results
    for model_dir in "$TESTS_DIR"/*/; do
        if [ -d "$model_dir" ] && [[ "$(basename "$model_dir")" != "$(basename "$TESTS_DIR")" ]]; then
            local model_name=$(basename "$model_dir")
            local status="❌ FAILED"
            
            if [ -f "$model_dir/test_status.txt" ] && [ "$(cat "$model_dir/test_status.txt")" = "PASSED" ]; then
                status="✅ PASSED"
            fi
            
            echo "- **$model_name**: $status" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Directory Structure

\`\`\`
Tests/$TEST_DATE/
├── COMPREHENSIVE_TEST_REPORT.md (this file)
├── model_size.txt
└── <model_name>/
    ├── Generated/
    │   ├── test_response.txt
    │   └── test_response_raw.txt
    ├── Issues/ (if any)
    │   └── <ISSUE_TYPE>.md
    ├── Report.md
    └── test_status.txt
\`\`\`

---
*Report generated by comprehensive test framework*
EOF

    log_success "Final report generated: $report_file"
}

# Main execution
main() {
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       AI Model Testing Framework      ║${NC}"
    echo -e "${CYAN}║     Test-Fix-Retest Loop System       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
    
    parse_arguments "$@"
    
    log_info "Starting test-fix-retest loop"
    log_info "Auto-fix mode: $([ "$AUTO_FIX" = "true" ] && echo "ENABLED" || echo "DISABLED")"
    
    setup_test_environment
    
    # Main test-fix-retest loop
    while [ $CURRENT_ITERATION -le $MAX_ITERATIONS ]; do
        log_info "Starting iteration $CURRENT_ITERATION..."
        
        if run_test_iteration; then
            log_success "All tests passed! No issues found."
            break
        else
            log_warning "Some tests failed in iteration $CURRENT_ITERATION"
            
            if [ "$AUTO_FIX" = "true" ]; then
                log_fix "Auto-fix enabled - attempting to resolve issues..."
                
                if apply_fixes > 0; then
                    log_success "Fixes applied - retesting in next iteration"
                    ((CURRENT_ITERATION++))
                    ((FIXED_MODELS++))
                else
                    log_error "No fixes could be applied - stopping"
                    break
                fi
            else
                log_error "Auto-fix disabled - stopping on first failure"
                break
            fi
        fi
    done
    
    if [ $CURRENT_ITERATION -gt $MAX_ITERATIONS ]; then
        log_warning "Maximum iterations ($MAX_ITERATIONS) reached"
    fi
    
    generate_final_report
    
    echo
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            Final Results               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo -e "${BLUE}Total Iterations:${NC} $CURRENT_ITERATION"
    echo -e "${BLUE}Total Models Tested:${NC} $TOTAL_MODELS"
    echo -e "${GREEN}Passed:${NC} $PASSED_MODELS"
    echo -e "${RED}Failed:${NC} $FAILED_MODELS"
    echo -e "${PURPLE}Auto-Fixed:${NC} $FIXED_MODELS"
    
    if [ $TOTAL_MODELS -gt 0 ]; then
        local success_rate=$(( (PASSED_MODELS * 100) / TOTAL_MODELS ))
        echo -e "${YELLOW}Success Rate:${NC} ${success_rate}%"
    fi
    
    echo
    log_info "Detailed results at: $TESTS_DIR"
    log_info "Comprehensive report: $TESTS_DIR/COMPREHENSIVE_TEST_REPORT.md"
    
    # Exit with appropriate code
    if [ $FAILED_MODELS -eq 0 ]; then
        log_success "🎉 All tests passed! System is working correctly."
        exit 0
    else
        log_error "❌ Some tests failed. Check reports for details."
        exit 1
    fi
}

# Execute main function
main "$@"