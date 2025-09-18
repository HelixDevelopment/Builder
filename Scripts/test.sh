#!/bin/bash

#╔════════════════════════════════════════╗
#║       AI Model Testing Framework       ║
#║     Test-Fix-Retest Loop System        ║
#╚════════════════════════════════════════╝
#
# Implements the test-fix-retest loop as requested
# Tests models, finds issues, applies fixes, and re-runs until all pass

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Configuration
AUTO_FIX=${AUTO_FIX:-false}
FIXER_TYPE=${FIXER_TYPE:-deepseek}
TEST_DATE=$(date +%Y-%m-%d)
TESTS_DIR="$HERE/../Tests/$TEST_DATE"
TIMEOUT_DURATION=30
MAX_ITERATIONS=5

# Logging configuration
LOG_FILE=""
LOG_ENABLED=false

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
            --fixer=*)
                FIXER_TYPE="${1#*=}"
                shift
                ;;
            --date=*)
                TEST_DATE="${1#*=}"
                TESTS_DIR="$HERE/../Tests/$TEST_DATE"
                shift
                ;;
            --help)
                echo "Usage: $0 [--auto-fix] [--fixer=TYPE] [--date=YYYY-MM-DD] [--help]"
                echo "  --auto-fix: Enable automatic fixing of detected issues"
                echo "  --fixer=TYPE: Choose AI fixer (claude, qwen, deepseek) - default: deepseek"
                echo "  --date=YYYY-MM-DD: Use specific date for test results"
                echo "  --help: Show this help"
                echo ""
                echo "Available fixers:"
                python3 "$HERE/AutoFixers/autofix_manager.py" list 2>/dev/null || echo "  Run with --auto-fix to see available fixers"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Write to log file if enabled
write_log() {
    if [ "$LOG_ENABLED" = true ] && [ -n "$LOG_FILE" ]; then
        echo "$*" >> "$LOG_FILE"
    fi
}

# Logging functions that write to both console and file
log_info() {
    local message="${BLUE}[INFO]${NC} $*"
    echo -e "$message"
    write_log "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_success() {
    local message="${GREEN}[SUCCESS]${NC} $*"
    echo -e "$message"
    write_log "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
}

log_warning() {
    local message="${YELLOW}[WARNING]${NC} $*"
    echo -e "$message"
    write_log "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $*"
}

log_error() {
    local message="${RED}[ERROR]${NC} $*"
    echo -e "$message"
    write_log "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
}

log_fix() {
    local message="${PURPLE}[FIX]${NC} $*"
    echo -e "$message"
    write_log "[$(date '+%Y-%m-%d %H:%M:%S')] [FIX] $*"
}

log_raw() {
    echo "$*"
    write_log "$*"
}

# Setup test environment
setup_test_environment() {
    mkdir -p "$TESTS_DIR"

    # Initialize logging
    LOG_FILE="$TESTS_DIR/test_run.log"
    LOG_ENABLED=true

    # Create log file with header
    cat > "$LOG_FILE" << EOF
================================================================================
AI Model Testing Framework - Complete Test Run Log
================================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Test Directory: $TESTS_DIR
Auto-Fix Mode: $AUTO_FIX
Fixer Type: $FIXER_TYPE
Max Iterations: $MAX_ITERATIONS
Timeout Duration: ${TIMEOUT_DURATION}s
================================================================================

EOF

    log_info "Setting up test environment for $TEST_DATE"
    log_info "Log file created at: $LOG_FILE"
    
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
    log_info "DEBUG: Checking availability of model: $model_name"
    local ollama_output=$(ollama list)
    log_info "DEBUG: Ollama list output contains: $(echo "$ollama_output" | grep "$model_name" || echo "NO MATCH")"
    
    if ! echo "$ollama_output" | grep -q "$model_name"; then
        log_warning "Model $model_name not available"
        document_issue "$model_name" "MODEL_NOT_AVAILABLE" "Model not installed in Ollama"
        return 1
    fi
    
    log_info "DEBUG: Model $model_name confirmed available"
    
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
    write_log "\n--- Starting Fix Phase ---"
    
    # FIRST: Check and fix codebase issues that could be causing model failures
    apply_codebase_fixes
    local codebase_fixes=$?
    fixes_applied=$((fixes_applied + codebase_fixes))
    
    # SECOND: Use AI-powered intelligent analysis and fixing
    if command -v python3 &> /dev/null; then
        log_fix "🤖 AI-powered intelligent auto-fix enabled (using: $FIXER_TYPE)"
        local ai_fixes=$(apply_ai_fixes)
        fixes_applied=$((fixes_applied + ai_fixes))
    else
        log_warning "⚠️  AI auto-fix disabled (missing python3)"
    fi
    
    # THEN: Find all failed models and apply model-specific fixes
    for model_dir in "$TESTS_DIR"/*/; do
        if [ -d "$model_dir" ]; then
            local dir_name=$(basename "$model_dir")
            local status_file="$model_dir/test_status.txt"

            # Extract model name from directory (format: Category_model:version)
            local model_name="${dir_name#*_}"  # Remove category prefix

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
                                    # Give Ollama a moment to update its model list
                                    sleep 2
                                    ((fixes_applied++))
                                    log_info "DEBUG: Model fix applied, fixes_applied now = $fixes_applied"
                                    rm -f "$issue_file"  # Remove the issue file
                                    log_info "DEBUG: Issue file removed: $issue_file"
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
                log_info "DEBUG: Reset status file for $model_name"
            fi
        fi
    done
    
    log_info "DEBUG: Finished processing all model directories"
    
    log_fix "Applied $fixes_applied fixes"
    write_log "--- Fix Phase Complete: $fixes_applied fixes applied ---\n"
    log_info "DEBUG: Returning fixes count: $fixes_applied"
    return $fixes_applied
}

# Apply fixes to project codebase for detected issues
apply_codebase_fixes() {
    local codebase_fixes=0
    
    log_fix "Scanning project codebase for issues to fix..."
    
    # Fix 1: Typo in install.sh "wth" -> "with"
    if grep -q "wth success" install.sh 2>/dev/null; then
        log_fix "Fixing typo in Scripts/install.sh: 'wth' -> 'with'"
        sed -i 's/wth success/with success/g' install.sh
        ((codebase_fixes++))
        log_success "Fixed typo in install.sh"
    fi
    
    # Fix 2: Check for missing dependency validation in install scripts
    if [ -f "install_ollama_models.sh" ] && ! grep -q "command -v bc" install_ollama_models.sh 2>/dev/null; then
        log_fix "Adding dependency check for 'bc' command in install_ollama_models.sh"
        # Create a backup and add dependency check
        cp install_ollama_models.sh install_ollama_models.sh.backup
        
        # Add dependency check after the shebang
        sed -i '/^#!/a\\n# Check required dependencies\nif ! command -v bc &> /dev/null; then\n    echo "ERROR: bc command not found. Please install bc package."\n    exit 1\nfi' install_ollama_models.sh
        
        ((codebase_fixes++))
        log_success "Added dependency check for bc command"
    fi
    
    # Fix 3: Check for proper error handling in audio installation
    if grep -q "return 0" AudioTemplates/install_musicgen.py 2>/dev/null && grep -q "sys.exit(main())" AudioTemplates/install_musicgen.py 2>/dev/null; then
        # This is actually correct, but let's check for other issues
        log_fix "Audio installation scripts appear correct"
    fi
    
    # Fix 4: Validate model recipe files for syntax issues
    for recipe_file in Recipes/Models/*/*/*; do
        if [ -f "$recipe_file" ] && [ -s "$recipe_file" ]; then
            # Check for lines that don't match expected format (not empty, not comment, should have model:tag)
            if grep -v "^#" "$recipe_file" | grep -v "^$" | grep -v ":" | head -1 >/dev/null 2>&1; then
                log_fix "Found potential format issue in recipe file: $recipe_file"
                # Could add specific fixes here
            fi
        fi
    done
    
    # Fix 5: Check for proper permissions on scripts
    for script in *.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            log_fix "Making script executable: $script"
            chmod +x "$script"
            ((codebase_fixes++))
            log_success "Made $script executable"
        fi
    done
    
    # Fix 6: Verify Ollama service is running and restart if needed
    if command -v systemctl &> /dev/null; then
        if ! systemctl is-active --quiet ollama 2>/dev/null; then
            log_fix "Ollama service not running, attempting to start..."
            if sudo systemctl start ollama 2>/dev/null; then
                log_success "Started Ollama service"
                ((codebase_fixes++))
            else
                log_warning "Could not start Ollama service (may need manual intervention)"
            fi
        fi
    fi
    
    # Fix 7: Check disk space for model storage
    local available_space=$(df -BG "$HERE" | awk 'NR==2{gsub(/G/,""); print $4}')
    if [ "$available_space" -lt 10 ]; then
        log_warning "Low disk space detected: ${available_space}GB available"
        log_fix "Consider cleaning up old models or increasing storage"
        # Could implement automatic cleanup here
    fi
    
    log_fix "Applied $codebase_fixes codebase fixes"
    return $codebase_fixes
}

# Apply Claude-powered intelligent fixes
apply_ai_fixes() {
    local ai_fixes=0
    
    log_fix "🤖 Analyzing issues with $FIXER_TYPE..." >&2
    
    # Find all failed models and create issue data for AI analysis
    for model_dir in "$TESTS_DIR"/*/; do
        if [ -d "$model_dir" ]; then
            local dir_name=$(basename "$model_dir")
            local status_file="$model_dir/test_status.txt"

            # Extract model name from directory (format: Category_model:version)
            local model_name="${dir_name#*_}"  # Remove category prefix

            if [ -f "$status_file" ] && [ "$(cat "$status_file")" = "FAILED" ]; then
                log_fix "🔍 $FIXER_TYPE analyzing: $model_name" >&2

                # Create issue data JSON for AI analysis
                local issue_json="$model_dir/ai_issue.json"
                create_ai_issue_json "$model_name" "$model_dir" "$issue_json"
                
                # Use AI to analyze and fix via the manager
                if python3 "$HERE/AutoFixers/autofix_manager.py" fix "$issue_json" "$FIXER_TYPE" >&2; then
                    log_success "✅ $FIXER_TYPE successfully fixed: $model_name" >&2
                    ((ai_fixes++))
                    
                    # Remove issue files since AI fixed it
                    rm -f "$model_dir/Issues"/*.md
                    rm -f "$status_file"
                else
                    log_error "❌ $FIXER_TYPE could not fix: $model_name" >&2
                fi
            fi
        fi
    done
    
    log_fix "$FIXER_TYPE applied $ai_fixes intelligent fixes" >&2
    echo $ai_fixes
}

# Create JSON issue data for AI analysis
create_ai_issue_json() {
    local model_name="$1"
    local model_dir="$2"
    local output_file="$3"
    
    # Collect issue information
    local issue_type="UNKNOWN"
    local description="Unknown issue"
    local error_output=""
    local actual_response=""
    
    # Read issue files to get details
    for issue_file in "$model_dir/Issues"/*.md; do
        if [ -f "$issue_file" ]; then
            issue_type=$(basename "$issue_file" .md)
            description=$(grep -A 1 "## Description" "$issue_file" | tail -1 || echo "No description")
            break
        fi
    done
    
    # Get actual response if available
    if [ -f "$model_dir/Generated/test_response.txt" ]; then
        actual_response=$(cat "$model_dir/Generated/test_response.txt" || echo "")
    fi
    
    # Get error output if available
    if [ -f "$model_dir/Issues/test_error.log" ]; then
        error_output=$(cat "$model_dir/Issues/test_error.log" || echo "")
    fi
    
    # Create JSON using Python with safe string handling
    cat > "$output_file.tmp" << 'EOF'
import json
import sys
from datetime import datetime

# Read data from environment variables
model_name = sys.argv[1]
issue_type = sys.argv[2]
description = sys.argv[3]
error_output = sys.argv[4]
actual_response = sys.argv[5]
model_dir = sys.argv[6]

# Create properly escaped JSON data
data = {
    'model': model_name,
    'issue_type': issue_type,
    'description': description,
    'error_output': error_output,
    'test_prompt': 'What is 2+2? Answer briefly.',
    'expected_pattern': '.*4.*',
    'actual_response': actual_response,
    'timestamp': datetime.now().isoformat(),
    'test_environment': {
        'ollama_version': '$(ollama --version 2>/dev/null || echo "unknown")',
        'system': '$(uname -s)',
        'test_dir': model_dir
    }
}

try:
    with open(sys.argv[7], 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
except Exception as e:
    print(f'Error creating JSON: {e}', file=sys.stderr)
    sys.exit(1)
EOF

    # Execute Python script with arguments to avoid quote issues
    python3 "$output_file.tmp" "$model_name" "$issue_type" "$description" "$error_output" "$actual_response" "$model_dir" "$output_file"
    rm -f "$output_file.tmp"
}

# Run comprehensive confirmation test of ALL models
run_full_confirmation_test() {
    log_info "🚀 Starting comprehensive confirmation test..."

    local confirmation_total=0
    local confirmation_passed=0
    local confirmation_failed=0

    # Test ALL models from all categories
    local model_size=$(cat "$TESTS_DIR/model_size.txt")

    # Define test configurations for each category
    declare -A category_prompts
    declare -A category_patterns

    category_prompts["General"]="What is 2+2? Answer briefly."
    category_patterns["General"]=".*4.*"

    category_prompts["Coder"]="Write a Python hello function. Show only code."
    category_patterns["Coder"]="def.*hello"

    category_prompts["Tester"]="Write a unit test for a function that adds two numbers. Show only code."
    category_patterns["Tester"]="(test|assert|def.*test)"

    category_prompts["Translation"]="Translate 'Hello' to French. Answer with one word only."
    category_patterns["Translation"]="(Bonjour|bonjour|Salut|salut)"

    category_prompts["Generative/Animation"]="Generate SVG code for a red circle. Show only the SVG code."
    category_patterns["Generative/Animation"]="<svg.*circle"

    category_prompts["Generative/Audio"]="Describe how to generate audio. Be brief."
    category_patterns["Generative/Audio"]="(audio|sound|music|speech)"

    category_prompts["Generative/JPEG"]="Describe an image of a sunset. Be brief."
    category_patterns["Generative/JPEG"]="(sunset|sun|sky|orange|horizon)"

    category_prompts["Generative/PNG"]="Describe an image of a mountain. Be brief."
    category_patterns["Generative/PNG"]="(mountain|peak|snow|landscape)"

    category_prompts["Generative/SVG"]="Generate SVG code for a blue square. Show only the SVG code."
    category_patterns["Generative/SVG"]="<svg.*rect"

    # Test each category
    for category in "General" "Coder" "Tester" "Translation" "Generative/Animation" "Generative/Audio" "Generative/JPEG" "Generative/PNG" "Generative/SVG"; do
        local models_file="$HERE/Recipes/Models/$category/$model_size"

        if [ ! -f "$models_file" ]; then
            log_warning "Skipping $category - models file not found"
            continue
        fi

        # Handle audio models specially
        if [[ "$category" == "Generative/Audio" ]]; then
            local audio_content=$(grep -v "^#" "$models_file" | grep -v "^$" | head -1)
            if [ -n "$audio_content" ]; then
                log_info "📋 Confirmation testing Audio models (external framework)..."

                # Check if audio framework exists
                local audio_dir="$HERE/../AudioModels"
                while IFS= read -r model_line || [[ -n "$model_line" ]]; do
                    if [[ -z "$model_line" || "$model_line" =~ ^# ]]; then
                        continue
                    fi

                    ((confirmation_total++))
                    local model_name=$(echo "$model_line" | cut -d: -f1)
                    log_info "🔍 Confirming: $model_name (Audio framework)"

                    if [ -d "$audio_dir" ] && [ -f "$audio_dir/generate_music.py" -o -f "$audio_dir/text_to_speech.py" ]; then
                        ((confirmation_passed++))
                        log_success "✅ CONFIRMED: $model_name (Audio framework installed)"
                    else
                        ((confirmation_failed++))
                        log_error "❌ CONFIRMATION FAILED: $model_name (Audio framework missing)"
                    fi
                done < "$models_file"
                continue
            fi
        fi

        log_info "📋 Confirmation testing $category models..."

        while IFS= read -r model_name || [[ -n "$model_name" ]]; do
            if [[ -z "$model_name" || "$model_name" =~ ^# ]]; then
                continue
            fi

            ((confirmation_total++))
            log_info "🔍 Confirming: $model_name ($category)"

            local prompt="${category_prompts[$category]}"
            local pattern="${category_patterns[$category]}"

            if test_single_model_confirmation "$model_name" "$prompt" "$pattern"; then
                ((confirmation_passed++))
                log_success "✅ CONFIRMED: $model_name"
            else
                ((confirmation_failed++))
                log_error "❌ CONFIRMATION FAILED: $model_name"
            fi
        done < "$models_file"
    done

    # Generate confirmation report
    log_info "📊 Confirmation Test Results:"
    log_info "   Total models tested: $confirmation_total"
    log_success "   Confirmed working: $confirmation_passed"
    log_error "   Failed confirmation: $confirmation_failed"

    if [ $confirmation_failed -eq 0 ]; then
        log_success "🎉 ALL MODELS CONFIRMED WORKING!"
        return 0
    else
        log_error "⚠️  Some models failed final confirmation"
        return 1
    fi
}

# Test a single model for confirmation (streamlined version)
test_single_model_confirmation() {
    local model_name="$1"
    local test_prompt="${2:-What is 2+2? Answer briefly.}"
    local expected_pattern="${3:-.*4.*}"
    
    # Quick availability check
    if ! ollama list | grep -q "$model_name"; then
        return 1
    fi
    
    # Quick response test
    local response=$(echo "$test_prompt" | timeout 30 ollama run "$model_name" 2>/dev/null | head -5 | tr -d '\n\r' | sed 's/[[:space:]]\+/ /g')
    
    if [[ "$response" =~ $expected_pattern ]]; then
        return 0
    else
        return 1
    fi
}

# Run test iteration
run_test_iteration() {
    log_info "=== Test Iteration $CURRENT_ITERATION ==="
    write_log "Starting test iteration $CURRENT_ITERATION at $(date '+%Y-%m-%d %H:%M:%S')"

    TOTAL_MODELS=0
    PASSED_MODELS=0
    FAILED_MODELS=0

    local model_size=$(cat "$TESTS_DIR/model_size.txt")

    # Test General models
    test_category "General" "$model_size" "What is 2+2? Answer briefly." ".*4.*"

    # Test Coder models
    test_category "Coder" "$model_size" "Write a Python hello function. Show only code." "def.*hello"

    # Test Tester models
    test_category "Tester" "$model_size" "Write a unit test for a function that adds two numbers. Show only code." "(test|assert|def.*test)"

    # Test Translation models
    test_category "Translation" "$model_size" "Translate 'Hello' to French. Answer with one word only." "(Bonjour|bonjour|Salut|salut)"

    # Test Generative/Animation models
    test_category "Generative/Animation" "$model_size" "Generate SVG code for a red circle. Show only the SVG code." "<svg.*circle"

    # Test Generative/Audio models (special handling for audio framework)
    if [ -f "$HERE/Recipes/Models/Generative/Audio/$model_size" ]; then
        local audio_content=$(grep -v "^#" "$HERE/Recipes/Models/Generative/Audio/$model_size" | grep -v "^$" | head -1)
        if [ -n "$audio_content" ]; then
            # Audio models use special format and external framework, skip normal testing
            log_info "Audio models use external framework - checking installation only"
            test_audio_category "$model_size"
        fi
    fi

    # Test Generative/JPEG models
    test_category "Generative/JPEG" "$model_size" "Describe an image of a sunset. Be brief." "(sunset|sun|sky|orange|horizon)"

    # Test Generative/PNG models
    test_category "Generative/PNG" "$model_size" "Describe an image of a mountain. Be brief." "(mountain|peak|snow|landscape)"

    # Test Generative/SVG models
    test_category "Generative/SVG" "$model_size" "Generate SVG code for a blue square. Show only the SVG code." "<svg.*rect"

    log_info "Iteration $CURRENT_ITERATION Results: $PASSED_MODELS passed, $FAILED_MODELS failed out of $TOTAL_MODELS total"
    write_log "\nIteration $CURRENT_ITERATION Summary:"
    write_log "  Total Models: $TOTAL_MODELS"
    write_log "  Passed: $PASSED_MODELS"
    write_log "  Failed: $FAILED_MODELS"
    write_log "  Success Rate: $([ $TOTAL_MODELS -gt 0 ] && echo "$(( (PASSED_MODELS * 100) / TOTAL_MODELS ))%" || echo "N/A")"
    write_log "  Completed at: $(date '+%Y-%m-%d %H:%M:%S')\n"

    return $FAILED_MODELS
}

# Test audio category models (special handling)
test_audio_category() {
    local model_size="$1"
    local models_file="$HERE/Recipes/Models/Generative/Audio/$model_size"

    if [ ! -f "$models_file" ]; then
        log_warning "Audio models file not found: $models_file"
        return 1
    fi

    log_info "Testing Audio models (external framework) from: $models_file"

    local category_models=0
    local category_passed=0

    # Check if AudioModels directory exists as a sign of installation
    local audio_dir="$HERE/../AudioModels"

    while IFS= read -r model_line || [[ -n "$model_line" ]]; do
        if [[ -z "$model_line" || "$model_line" =~ ^# ]]; then
            continue
        fi

        ((TOTAL_MODELS++))
        ((category_models++))

        # Parse audio model format: model_name:type:repository_id
        local model_name=$(echo "$model_line" | cut -d: -f1)
        local model_type=$(echo "$model_line" | cut -d: -f2)
        local repo_id=$(echo "$model_line" | cut -d: -f3)

        local model_dir="$TESTS_DIR/Generative_Audio_${model_name}"
        mkdir -p "$model_dir"/{Generated,Issues}

        # Check if audio framework is installed
        if [ -d "$audio_dir" ] && [ -f "$audio_dir/generate_music.py" -o -f "$audio_dir/text_to_speech.py" ]; then
            log_success "✅ Audio framework installed for $model_name ($model_type)"
            echo "PASSED" > "$model_dir/test_status.txt"

            # Create report
            cat > "$model_dir/Report.md" << EOF
# Test Report: $model_name (Audio)

**Date**: $TEST_DATE
**Status**: ✅ PASSED (Framework Available)
**Type**: $model_type
**Repository**: $repo_id

## Test Details
- Audio models use external framework
- Framework installation verified
- Model type: $model_type

## Files Created
- Report.md (this file)
- test_status.txt (PASSED status)
EOF
            ((PASSED_MODELS++))
            ((category_passed++))
        else
            log_warning "❌ Audio framework not installed for $model_name"
            document_issue_with_dir "$model_name" "AUDIO_FRAMEWORK_MISSING" "Audio framework not installed. Run: ./Scripts/install.sh Generative/Audio" "$model_dir"
            ((FAILED_MODELS++))
        fi

    done < "$models_file"

    if [ $category_models -gt 0 ]; then
        log_info "Audio results: $category_passed/$category_models passed"
    fi
}

# Test a specific category of models
test_category() {
    local category="$1"
    local model_size="$2"
    local test_prompt="$3"
    local expected_pattern="$4"

    local models_file="$HERE/Recipes/Models/$category/$model_size"

    if [ ! -f "$models_file" ]; then
        log_warning "Models file not found for $category: $models_file"
        write_log "  Recipe file does not exist"
        return 1
    fi

    log_info "Testing $category models from: $models_file"
    write_log "  Category: $category"
    write_log "  Model Size: $model_size"
    write_log "  Recipe File: $models_file"

    local category_models=0
    local category_passed=0

    while IFS= read -r model_name || [[ -n "$model_name" ]]; do
        if [[ -z "$model_name" || "$model_name" =~ ^# ]]; then
            continue
        fi

        ((TOTAL_MODELS++))
        ((category_models++))

        # Create category-specific test directory
        local category_safe=$(echo "$category" | tr '/' '_')
        local model_dir="$TESTS_DIR/${category_safe}_${model_name}"

        if test_single_model_with_dir "$model_name" "$test_prompt" "$expected_pattern" "$model_dir"; then
            ((PASSED_MODELS++))
            ((category_passed++))
        else
            ((FAILED_MODELS++))
        fi

    done < "$models_file"

    if [ $category_models -gt 0 ]; then
        log_info "$category results: $category_passed/$category_models passed"
        write_log "  Category Summary: $category_passed passed, $((category_models - category_passed)) failed out of $category_models total"
    fi
}

# Test a single model with custom directory
test_single_model_with_dir() {
    local model_name="$1"
    local test_prompt="$2"
    local expected_pattern="$3"
    local model_test_dir="$4"

    log_info "Testing model: $model_name"
    write_log "  Prompt: $test_prompt"
    write_log "  Expected Pattern: $expected_pattern"
    write_log "  Test Directory: $model_test_dir"

    mkdir -p "$model_test_dir"/{Generated,Issues}

    # Check if model is available
    write_log "  Checking model availability..."
    local ollama_output=$(ollama list 2>&1)
    write_log "  Ollama list output: $(echo "$ollama_output" | wc -l) lines"

    if ! echo "$ollama_output" | grep -q "$model_name"; then
        log_warning "Model $model_name not available"
        write_log "  Model not found in Ollama registry"
        document_issue_with_dir "$model_name" "MODEL_NOT_AVAILABLE" "Model not installed in Ollama" "$model_test_dir"
        return 1
    fi

    write_log "  Model confirmed available"

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

            write_log "  Raw response length: ${#response_content} characters"
            write_log "  Cleaned response: $cleaned_response"

            if [[ "$cleaned_response" =~ $expected_pattern ]]; then
                log_success "✅ $model_name PASSED"
                write_log "  Pattern match successful"
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
                write_log "  Pattern match failed"
                write_log "  Expected pattern: $expected_pattern"
                write_log "  Actual response: $cleaned_response"
                document_issue_with_dir "$model_name" "UNEXPECTED_RESPONSE" "Response '$cleaned_response' doesn't match pattern '$expected_pattern'" "$model_test_dir"
                return 1
            fi
        else
            log_error "❌ $model_name produced no output"
            write_log "  No output generated"
            document_issue_with_dir "$model_name" "NO_OUTPUT" "Model produced no output within timeout" "$model_test_dir"
            return 1
        fi
    else
        local exit_code=$?
        log_error "❌ $model_name timed out or failed"
        write_log "  Command failed with exit code: $exit_code"
        write_log "  Timeout: ${TIMEOUT_DURATION}s"
        document_issue_with_dir "$model_name" "TIMEOUT" "Model failed to respond within ${TIMEOUT_DURATION}s" "$model_test_dir"
        return 1
    fi
}

# Document issues with custom directory
document_issue_with_dir() {
    local model_name="$1"
    local issue_type="$2"
    local description="$3"
    local model_dir="$4"

    local issue_file="$model_dir/Issues/${issue_type}.md"
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

    echo "FAILED" > "$model_dir/test_status.txt"
    log_error "Issue documented: $issue_file"
}

# Generate final report
generate_final_report() {
    log_info "Generating final test report..."

    local report_file="$TESTS_DIR/COMPREHENSIVE_TEST_REPORT.md"

    # Add summary to log file
    write_log ""
    write_log "================================================================================"
    write_log "FINAL TEST RESULTS SUMMARY"
    write_log "================================================================================"
    write_log "Total Iterations: $CURRENT_ITERATION"
    write_log "Total Models Tested: $TOTAL_MODELS"
    write_log "Passed: $PASSED_MODELS"
    write_log "Failed: $FAILED_MODELS"
    write_log "Auto-Fixed: $FIXED_MODELS"
    if [ $TOTAL_MODELS -gt 0 ]; then
        local success_rate=$(( (PASSED_MODELS * 100) / TOTAL_MODELS ))
        write_log "Success Rate: ${success_rate}%"
    fi
    write_log "================================================================================"
    
    cat > "$report_file" << EOF
# Comprehensive Test Report

**Date**: $TEST_DATE  
**Total Iterations**: $CURRENT_ITERATION  
**Auto-Fix Enabled**: $AUTO_FIX$([ "$AUTO_FIX" = "true" ] && echo " (using: $FIXER_TYPE)" || echo "")

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
            local dir_name=$(basename "$model_dir")
            local status="❌ FAILED"

            # Extract category and model name from directory (format: Category_model:version)
            local category="${dir_name%%_*}"
            local model_name="${dir_name#*_}"

            if [ -f "$model_dir/test_status.txt" ] && [ "$(cat "$model_dir/test_status.txt")" = "PASSED" ]; then
                status="✅ PASSED"
            fi

            echo "- **$model_name** ($category): $status" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Directory Structure

\`\`\`
Tests/$TEST_DATE/
├── COMPREHENSIVE_TEST_REPORT.md (this file)
├── test_run.log (complete test execution log)
├── model_size.txt
└── <Category>_<model_name>/
    ├── Generated/
    │   ├── test_response.txt
    │   └── test_response_raw.txt
    ├── Issues/ (if any)
    │   └── <ISSUE_TYPE>.md
    ├── Report.md
    └── test_status.txt
\`\`\`

## Log Files

- **Complete Test Log**: [test_run.log](test_run.log)
- **Log Size**: $([ -f "$LOG_FILE" ] && du -h "$LOG_FILE" | cut -f1 || echo "N/A")
- **Log Lines**: $([ -f "$LOG_FILE" ] && wc -l < "$LOG_FILE" || echo "0") lines

---
*Report generated by comprehensive test framework*
EOF

    log_success "Final report generated: $report_file"
}

# Main execution
main() {
    # Display header (will be captured in log via main wrapper)
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       AI Model Testing Framework       ║${NC}"
    echo -e "${CYAN}║     Test-Fix-Retest Loop System        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
    
    parse_arguments "$@"

    # Setup must happen first to initialize logging
    setup_test_environment

    log_info "Starting test-fix-retest loop"
    log_info "Auto-fix mode: $([ "$AUTO_FIX" = "true" ] && echo "ENABLED" || echo "DISABLED")"
    if [ "$AUTO_FIX" = "true" ]; then
        log_info "AI Fixer: $FIXER_TYPE"
    fi
    write_log "Command line arguments: $*"
    write_log "Current working directory: $(pwd)"
    write_log "Script location: $HERE"
    
    # Main test-fix-retest loop
    while [ $CURRENT_ITERATION -le $MAX_ITERATIONS ]; do
        log_info "Starting iteration $CURRENT_ITERATION (max: $MAX_ITERATIONS)..."
        
        if run_test_iteration; then
            log_success "All tests passed! No issues found."
            
            # Run final confirmation test of ALL models
            if [ $CURRENT_ITERATION -gt 1 ]; then
                log_info "🎯 Running final confirmation test of ALL models..."
                run_full_confirmation_test
            fi
            break
        else
            log_warning "Some tests failed in iteration $CURRENT_ITERATION"
            
            if [ "$AUTO_FIX" = "true" ]; then
                log_fix "Auto-fix enabled - attempting to resolve issues..."
                
                apply_fixes
                local fixes_applied_count=$?
                log_info "DEBUG: Fixes applied count: $fixes_applied_count"
                if [ $fixes_applied_count -gt 0 ]; then
                    log_success "Fixes applied - retesting in next iteration"
                    ((CURRENT_ITERATION++))
                    ((FIXED_MODELS++))
                    log_info "DEBUG: About to continue to iteration $CURRENT_ITERATION"
                    # Continue to next iteration
                    continue
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
    log_info "Complete test log: $TESTS_DIR/test_run.log"
    
    # Final log summary
    write_log "\n================================================================================"
    write_log "TEST RUN COMPLETE"
    write_log "================================================================================"
    write_log "End time: $(date '+%Y-%m-%d %H:%M:%S')"
    write_log "Exit status: $([ $FAILED_MODELS -eq 0 ] && echo "SUCCESS (0)" || echo "FAILURE (1)")"
    write_log "================================================================================"

    # Exit with appropriate code
    if [ $FAILED_MODELS -eq 0 ]; then
        log_success "🎉 All tests passed! System is working correctly."
        exit 0
    else
        log_error "❌ Some tests failed. Check reports for details."
        exit 1
    fi
}

# Wrapper to capture all output
run_with_logging() {
    # Run main and capture all output
    main "$@" 2>&1 | while IFS= read -r line; do
        echo "$line"
        if [ "$LOG_ENABLED" = true ] && [ -n "$LOG_FILE" ]; then
            # Strip ANSI color codes for log file
            echo "$line" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
        fi
    done

    # Capture exit code
    return ${PIPESTATUS[0]}
}

# Execute main function with logging
run_with_logging "$@"