#!/bin/bash

# TextEnhancer Startup Installation Script
# This script builds the app, installs it to Applications, and sets it up for startup

set -e  # Exit on any error

echo "🚀 TextEnhancer Startup Installation"
echo "===================================="

# Check if running from project directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Please run this script from the TextEnhancer project directory"
    exit 1
fi

# Step 1: Stop any running instances
echo "🛑 Stopping any running TextEnhancer instances..."

# Kill running TextEnhancer processes
if pgrep -f "TextEnhancer" > /dev/null; then
    echo "Found running TextEnhancer instances, terminating..."
    pkill -f "TextEnhancer"
    sleep 2
    
    # Force kill if still running
    if pgrep -f "TextEnhancer" > /dev/null; then
        echo "Force terminating remaining instances..."
        pkill -9 -f "TextEnhancer"
        sleep 1
    fi
    echo "✅ All TextEnhancer instances stopped"
else
    echo "✅ No running TextEnhancer instances found"
fi

# Step 2: Build the app bundle
echo "🔨 Building TextEnhancer app bundle..."
make bundle

if [ ! -d "TextEnhancer.app" ]; then
    echo "❌ Failed to create app bundle"
    exit 1
fi

echo "✅ App bundle created successfully"

# Step 3: Install to Applications folder
echo "📦 Installing to Applications folder..."
INSTALL_PATH="/Applications/TextEnhancer.app"

# Remove existing installation if it exists
if [ -d "$INSTALL_PATH" ]; then
    echo "🗑️  Removing existing installation..."
    rm -rf "$INSTALL_PATH"
fi

# Copy to Applications
cp -R TextEnhancer.app "$INSTALL_PATH"
echo "✅ Installed to $INSTALL_PATH"

# Step 4: Set up for startup using osascript (AppleScript)
echo "🌅 Setting up for startup..."

# Create AppleScript to add to login items
cat > /tmp/add_login_item.scpt << 'EOF'
tell application "System Events"
    set appPath to POSIX file "/Applications/TextEnhancer.app"
    make login item at end with properties {path:appPath, hidden:false, name:"TextEnhancer"}
end tell
EOF

# Run the AppleScript
if osascript /tmp/add_login_item.scpt > /dev/null 2>&1; then
    echo "✅ Added to login items successfully"
else
    echo "⚠️  Could not automatically add to login items"
    echo "Please add manually: System Settings > General > Login Items"
fi

# Clean up
rm -f /tmp/add_login_item.scpt

echo ""
echo "🎉 Installation Complete!"
echo ""
echo "TextEnhancer is now installed and will start automatically on login."
echo ""
echo "What happens next:"
echo "1. 📱 The app will appear in your menu bar (system tray)"
echo "2. 🔐 You may be prompted for accessibility permissions"
echo "3. ⌨️  Global keyboard shortcuts will be active:"
echo "   - Ctrl+Alt+I: Improve Text" 
echo "   - Ctrl+Alt+U: Summarize"
echo "   - Ctrl+Alt+V: Expand"
echo ""
echo "Manual controls:"
echo "• To start now: open /Applications/TextEnhancer.app"
echo "• To manage startup: System Settings > General > Login Items"
echo "• To uninstall: run './uninstall-startup.sh'"
echo ""
echo "📝 Note: The app requires accessibility permissions to work properly."
echo "   You'll be prompted to grant these when you first run it." 