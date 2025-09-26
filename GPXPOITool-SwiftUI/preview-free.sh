#!/bin/bash

# Preview-free Swift compilation utility
# Temporarily removes #Preview blocks for command-line builds

set -e

TEMP_DIR="temp/preview-free"
SOURCE_DIR="GPX POI Tool"

# Function to create preview-free versions of Swift files
create_preview_free_versions() {
    echo "Creating preview-free versions for compilation..."

    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"/{Models,Views,Services}

    # Copy and process all Swift files
    find "$SOURCE_DIR" -name "*.swift" -type f | while read -r file; do
        relative_path=${file#"$SOURCE_DIR"/}
        output_file="$TEMP_DIR/$relative_path"

        # Remove #Preview blocks and their contents
        awk '
        BEGIN { in_preview = 0; brace_count = 0 }
        /^#Preview/ { in_preview = 1; next }
        in_preview == 1 {
            if ($0 ~ /{/) brace_count++
            if ($0 ~ /}/) {
                brace_count--
                if (brace_count <= 0) {
                    in_preview = 0
                    brace_count = 0
                }
            }
            next
        }
        { print }
        ' "$file" > "$output_file"
    done
}

# Function to clean up temp directory
cleanup_temp() {
    rm -rf "$TEMP_DIR"
}

# Main function
case "${1:-create}" in
    "create")
        create_preview_free_versions
        echo "Preview-free versions created in $TEMP_DIR"
        ;;
    "cleanup")
        cleanup_temp
        echo "Temporary files cleaned up"
        ;;
    *)
        echo "Usage: $0 [create|cleanup]"
        exit 1
        ;;
esac
