#!/bin/bash

# TextEnhancer Startup Uninstall Script
# This script removes TextEnhancer from Applications and login items

set -e  # Exit on any error

echo "🗑️  TextEnhancer Startup Uninstall"
echo "================================="

# Step 1: Remove from Applications folder
INSTALL_PATH="/Applications/TextEnhancer.app"

if [ -d "$INSTALL_PATH" ]; then
    echo "📦 Removing from Applications folder..."
    rm -rf "$INSTALL_PATH"
    echo "✅ Removed from Applications"
else
    echo "ℹ️  TextEnhancer not found in Applications"
fi

# Step 2: Remove from login items
echo "🌅 Removing from login items..."

# Create AppleScript to remove from login items
cat > /tmp/remove_login_item.scpt << 'EOF'
tell application "System Events"
    try
        delete login item "TextEnhancer"
    on error
        -- Item not found, that's okay
    end try
end tell
EOF

# Run the AppleScript
if osascript /tmp/remove_login_item.scpt > /dev/null 2>&1; then
    echo "✅ Removed from login items"
else
    echo "⚠️  Could not automatically remove from login items"
    echo "Please remove manually: System Settings > General > Login Items"
fi

# Clean up
rm -f /tmp/remove_login_item.scpt

# Step 3: Kill running instance if it exists
echo "🛑 Stopping running instance..."
pkill -f "TextEnhancer" > /dev/null 2>&1 || true
echo "✅ Stopped running instance"

echo ""
echo "🎉 Uninstall Complete!"
echo ""
echo "TextEnhancer has been removed from:"
echo "• Applications folder"
echo "• Login items"
echo "• Running processes"
echo ""
echo "To reinstall for startup, run: ./install-startup.sh" 