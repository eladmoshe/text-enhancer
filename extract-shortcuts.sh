#!/usr/bin/env bash
set -euo pipefail

# Extract current user shortcuts and create default configuration
# Usage: ./extract-shortcuts.sh [--preview] [--help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$HOME/Library/Application Support/TextEnhancer/config.json"
TARGET="$SCRIPT_DIR/config.default.json"

show_help() {
    cat << EOF
Extract User Shortcuts for Default Configuration

Usage: $0 [OPTIONS]

OPTIONS:
    --preview    Print the extracted configuration to stdout without writing to file
    --help       Show this help message

DESCRIPTION:
    This script reads your current TextEnhancer configuration from:
    $SOURCE
    
    It scrubs sensitive data (API keys) and creates a default configuration file at:
    $TARGET
    
    This default configuration will be used for clean installations of the app.

EXAMPLES:
    $0              # Extract and save default configuration
    $0 --preview    # Show what would be extracted without saving

EOF
}

preview_mode=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preview)
            preview_mode=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if source config file exists
if [[ ! -f "$SOURCE" ]]; then
    echo "Error: Configuration file not found at: $SOURCE"
    echo ""
    echo "This means you haven't configured TextEnhancer yet, or it's stored elsewhere."
    echo "Please run TextEnhancer and configure at least one shortcut, then try again."
    exit 1
fi

echo "📄 Reading configuration from: $SOURCE"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Please install jq: brew install jq"
    exit 1
fi

# Read and validate JSON
if ! jq empty "$SOURCE" 2>/dev/null; then
    echo "Error: Invalid JSON in configuration file: $SOURCE"
    exit 1
fi

echo "🔧 Scrubbing sensitive data (API keys)..."

# Read and scrub secrets using jq
CONFIG=$(jq '.apiProviders.claude.apiKey="" | .apiProviders.openai.apiKey=""' "$SOURCE")

if [[ "$preview_mode" == true ]]; then
    echo ""
    echo "📋 Preview of extracted configuration:"
    echo "======================================"
    echo "$CONFIG" | jq .
    echo ""
    echo "This would be written to: $TARGET"
    exit 0
fi

# Create backup of existing default config if it exists
if [[ -f "$TARGET" ]]; then
    backup_file="${TARGET}.bak.$(date +%s)"
    echo "💾 Creating backup of existing default config: $backup_file"
    cp "$TARGET" "$backup_file"
fi

echo "💾 Writing default configuration to: $TARGET"

# Write the scrubbed configuration
echo "$CONFIG" | jq . > "$TARGET"

echo "✅ Default configuration created successfully!"
echo ""
echo "Summary:"
echo "  Source:      $SOURCE"
echo "  Target:      $TARGET"
echo "  Shortcuts:   $(echo "$CONFIG" | jq '.shortcuts | length')"
echo "  API Keys:    Scrubbed (empty)"
echo ""
echo "Next steps:"
echo "  1. Review the generated file: cat $TARGET"
echo "  2. Commit the file to git: git add $TARGET && git commit"
echo "  3. The configuration will be used for clean installations" 