#!/bin/bash

# Simple single-model test script to validate core functionality

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_DATE=$(date +%Y-%m-%d-%H%M%S)
TESTS_DIR="$HERE/Tests/$TEST_DATE"
TIMEOUT_DURATION=30

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing single model: qwen3:8b${NC}"

# Create test structure
mkdir -p "$TESTS_DIR/qwen3-8b"/{Generated,Issues}

# Test the model
echo -e "${BLUE}Running test...${NC}"

if timeout $TIMEOUT_DURATION bash -c "
    echo 'What is 2+2? Answer briefly.' | ollama run qwen3:8b 2>'$TESTS_DIR/qwen3-8b/Issues/error.log' | 
    tee '$TESTS_DIR/qwen3-8b/Generated/raw_response.txt' | 
    sed 's/\x1b\[[0-9;]*[mGKH]//g' | 
    sed 's/\[?[0-9]*[hlc]//g' |      
    sed 's/\[[0-9]*G//g' |           
    tr -d '\r' |                     
    grep -v '^$' |                   
    head -10 > '$TESTS_DIR/qwen3-8b/Generated/test_response.txt'
"; then
    
    if [ -s "$TESTS_DIR/qwen3-8b/Generated/test_response.txt" ]; then
        response=$(cat "$TESTS_DIR/qwen3-8b/Generated/test_response.txt")
        cleaned_response=$(echo "$response" | tr -d '\n\r' | sed 's/[[:space:]]\+/ /g')
        
        echo -e "${BLUE}Response received (${#response} chars):${NC}"
        echo "$cleaned_response"
        
        if [[ "$cleaned_response" =~ .*4.* ]]; then
            echo -e "${GREEN}✅ TEST PASSED: Model correctly answered 2+2${NC}"
            echo "PASSED" > "$TESTS_DIR/qwen3-8b/test_status.txt"
            
            # Create report
            cat > "$TESTS_DIR/qwen3-8b/Report.md" << EOF
# Test Report: qwen3:8b

**Date**: $TEST_DATE
**Status**: ✅ PASSED

## Test Details
- **Prompt**: What is 2+2? Answer briefly.
- **Response Length**: ${#response} characters
- **Contains "4"**: Yes

## Generated Content
\`\`\`
$cleaned_response
\`\`\`

## Files Created
- Generated/test_response.txt
- Generated/raw_response.txt
- Issues/error.log
- Report.md
- test_status.txt
EOF
        else
            echo -e "${RED}❌ TEST FAILED: Response doesn't contain '4'${NC}"
            echo "FAILED" > "$TESTS_DIR/qwen3-8b/test_status.txt"
        fi
    else
        echo -e "${RED}❌ TEST FAILED: No response generated${NC}"
        echo "FAILED" > "$TESTS_DIR/qwen3-8b/test_status.txt"
    fi
else
    echo -e "${RED}❌ TEST FAILED: Timeout or error${NC}"
    echo "FAILED" > "$TESTS_DIR/qwen3-8b/test_status.txt"
fi

echo -e "${BLUE}Test results saved to: $TESTS_DIR/qwen3-8b/${NC}"
ls -la "$TESTS_DIR/qwen3-8b/"

echo -e "${BLUE}Generated directory contents:${NC}"
ls -la "$TESTS_DIR/qwen3-8b/Generated/" 2>/dev/null || echo "No Generated directory"

echo -e "${BLUE}Issues directory contents:${NC}" 
ls -la "$TESTS_DIR/qwen3-8b/Issues/" 2>/dev/null || echo "No Issues directory"