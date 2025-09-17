#!/bin/bash

#╔════════════════════════════════════════╗
#║      Debug Test Diagnostics           ║
#║     Issue Detection & Analysis        ║
#╚════════════════════════════════════════╝
#
# Debug test script to find the issue
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_DATE="debug-$(date +%H%M%S)"
TESTS_DIR="$HERE/../Tests/$TEST_DATE"
MODEL_SIZE="7B"

echo "=== DEBUG TEST ==="
echo "HERE: $HERE"
echo "TEST_DATE: $TEST_DATE"
echo "TESTS_DIR: $TESTS_DIR"
echo "MODEL_SIZE: $MODEL_SIZE"

# Create test directory
mkdir -p "$TESTS_DIR"
echo "$MODEL_SIZE" > "$TESTS_DIR/model_size.txt"

echo "=== CHECKING MODELS FILE ==="
MODELS_FILE="$HERE/Recipes/Models/General/$MODEL_SIZE"
echo "Models file: $MODELS_FILE"
echo "File exists: $(test -f "$MODELS_FILE" && echo "YES" || echo "NO")"

if [ -f "$MODELS_FILE" ]; then
    echo "File contents:"
    cat "$MODELS_FILE"
    echo ""
    
    echo "=== TESTING FILE READING ==="
    while IFS= read -r model_name || [[ -n "$model_name" ]]; do
        echo "Read line: '$model_name'"
        if [[ -z "$model_name" || "$model_name" =~ ^# ]]; then
            echo "  -> Skipping (empty or comment)"
        else
            echo "  -> Would test model: $model_name"
            # Check if model exists
            if ollama list | grep -q "$model_name"; then
                echo "  -> Model available: YES"
            else
                echo "  -> Model available: NO"
            fi
        fi
    done < "$MODELS_FILE"
else
    echo "ERROR: Models file not found!"
fi