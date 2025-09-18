#\!/bin/bash
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR="../Tests/test-verify"
mkdir -p "$TESTS_DIR"
echo "7B" > "$TESTS_DIR/model_size.txt"

# Test that each category can be found
categories=(
    "General"
    "Coder"
    "Tester"
    "Translation"
    "Generative/Animation"
    "Generative/Audio"
    "Generative/JPEG"
    "Generative/PNG"
    "Generative/SVG"
)

echo "=== Checking model recipe files for all categories ==="
for category in "${categories[@]}"; do
    recipe_file="$HERE/Recipes/Models/$category/7B"
    if [ -f "$recipe_file" ]; then
        model_count=$(grep -v "^#" "$recipe_file" | grep -v "^$" | wc -l)
        echo "✅ $category: Found $model_count models in 7B recipe"
    else
        echo "❌ $category: Recipe file not found at $recipe_file"
    fi
done
