#!/bin/bash

# TextEnhancer Build Script
# This script builds and optionally runs the TextEnhancer application

set -e  # Exit on any error

echo "🚀 TextEnhancer Build Script"
echo "=============================="

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed or not in PATH"
    echo "Please install Xcode or Swift toolchain"
    exit 1
fi

echo "✅ Swift found: $(swift --version | head -1)"

# Check Swift version
SWIFT_VERSION=$(swift --version | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
echo "📝 Swift version: $SWIFT_VERSION"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
swift package clean > /dev/null 2>&1 || true

# Resolve dependencies
echo "📦 Resolving dependencies..."
swift package resolve

# Build the project
echo "🔨 Building TextEnhancer..."
if swift build; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Function to stop existing instances
stop_existing_instances() {
    echo "🔍 Checking for running TextEnhancer instances..."
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
}

# Function to check signing setup
check_signing_setup() {
    if [ -z "$SIGN_ID" ]; then
        echo ""
        echo "⚠️  SIGN_ID not set - accessibility permissions will reset on rebuild"
        echo ""
        echo "🎯 For persistent accessibility permissions:"
        echo "   1. Open Xcode and create a development certificate"
        echo "   2. Run: export SIGN_ID=\"Apple Development: Your Name (TEAMID)\""
        echo "   3. Use --bundle-signed instead of --bundle"
        echo ""
        echo "💡 Check available certificates: make check-sign"
        echo ""
    else
        echo "✅ SIGN_ID set: $SIGN_ID"
        echo "🎯 Using signed builds for persistent accessibility permissions"
    fi
}

# Check if --run flag is provided
if [[ "$1" == "--run" ]]; then
    stop_existing_instances
    echo "🎯 Running TextEnhancer (debug)..."
    echo "Note: Debug builds don't persist accessibility permissions"
    echo "Press Ctrl+C to stop the application"
    echo ""
    .build/debug/TextEnhancer
elif [[ "$1" == "--bundle" ]]; then
    stop_existing_instances
    
    # Clean up any old installations to prevent version conflicts
    echo "🧹 Cleaning up old TextEnhancer installations..."
    rm -rf /Applications/TextEnhancer.app 2>/dev/null || true
    rm -rf ~/Applications/TextEnhancer.app 2>/dev/null || true
    
    check_signing_setup
    echo "📦 Creating signed app bundle..."
    make bundle-signed
    echo ""
    echo "📍 Installing to ~/Applications/TextEnhancer.app..."
    make install
    echo ""
    echo "🎯 Running TextEnhancer as signed app bundle..."
    echo "✅ Accessibility permissions will persist across rebuilds!"
    open ~/Applications/TextEnhancer.app
elif [[ "$1" == "--bundle-signed" ]]; then
    stop_existing_instances
    
    # Clean up any old installations to prevent version conflicts
    echo "🧹 Cleaning up old TextEnhancer installations..."
    rm -rf /Applications/TextEnhancer.app 2>/dev/null || true
    rm -rf ~/Applications/TextEnhancer.app 2>/dev/null || true
    
    if [ -z "$SIGN_ID" ]; then
        echo "❌ SIGN_ID not set. Please export your signing certificate:"
        echo ""
        echo "📝 Available certificates:"
        make check-sign
        echo ""
        echo "💡 Example: export SIGN_ID=\"Apple Development: Your Name (TEAMID)\""
        exit 1
    fi
    echo "📦 Creating signed app bundle..."
    make bundle-signed
    echo ""
    echo "📍 Installing to ~/Applications/TextEnhancer.app..."
    make install-signed
    echo ""
    echo "🎯 Running TextEnhancer as signed app bundle..."
    echo "✅ Accessibility permissions will persist across rebuilds!"
    open ~/Applications/TextEnhancer.app
elif [[ "$1" == "--test" ]]; then
    echo "🧪 Running tests with coverage..."
    swift test --enable-code-coverage
    echo ""
    echo "📊 Code coverage report:"
    echo "Use: xcrun llvm-cov show .build/debug/TextEnhancerPackageTests.xctest/Contents/MacOS/TextEnhancerPackageTests -instr-profile .build/debug/codecov/default.profdata"
elif [[ "$1" == "--settings" ]]; then
    echo "⚙️  Opening TextEnhancer settings..."
    if [ -d "~/Applications/TextEnhancer.app" ]; then
        open ~/Applications/TextEnhancer.app --args --settings
    else
        echo "📦 Installing app first..."
        if [ -n "$SIGN_ID" ]; then
            make install-signed
        else
            make install
        fi
        open ~/Applications/TextEnhancer.app --args --settings
    fi
elif [[ "$1" == "--status" ]]; then
    echo "📊 TextEnhancer Status"
    echo "====================="
    make install-location
    echo ""
    make check-sign
elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo ""
    echo "📖 TextEnhancer Build Script Help"
    echo "=================================="
    echo ""
    echo "🏗️  Production Build & Run:"
    echo "  ./build.sh --bundle          Create & run unsigned bundle (permissions reset)"
    echo "  ./build.sh --bundle-signed   Create & run signed bundle (persistent permissions)"
    echo ""
    echo "🔧 Development Build & Run:"
    echo "  ./build.sh --run             Run debug binary directly (no bundle, permissions reset)"
    echo ""
    echo "⚙️  Other:"
    echo "  ./build.sh --test            Run tests with coverage"
    echo "  ./build.sh --settings        Open settings window"
    echo "  ./build.sh --status          Show installation and signing status"
    echo "  ./build.sh --help            Show this help"
    echo ""
    echo "🔏 For persistent accessibility permissions:"
    echo "   1. Open Xcode → Preferences → Accounts → Manage Certificates → +"
    echo "   2. Create 'Apple Development' certificate"
    echo "   3. export SIGN_ID=\"Apple Development: Your Name (TEAMID)\""
    echo "   4. ./build.sh --bundle-signed"
    echo ""
    echo "💡 Direct make commands:"
    echo "   make help                    Show all available targets"
    echo "   make check-sign              Check signing certificate status"
    echo "   make install-location        Show installation status"
    echo ""
    exit 0
fi

echo ""
echo "🎉 Build complete!"

if [[ "$1" != "--help" ]] && [[ "$1" != "-h" ]] && [[ "$1" != "--status" ]]; then
    echo ""
    echo "📖 Quick reference:"
    echo "  ./build.sh --run             # Development: Debug binary (no bundle, permissions reset)"
    echo "  ./build.sh --bundle          # Production: Signed bundle (persistent permissions)"
    echo "  ./build.sh --bundle-signed   # Production: Signed bundle (persistent permissions)"
    echo "  ./build.sh --status          # Check installation and signing status"
    echo "  ./build.sh --help            # Full help"
    echo ""
    if [ -z "$SIGN_ID" ]; then
        echo "💡 For persistent accessibility permissions, set up code signing:"
        echo "   export SIGN_ID=\"Apple Development: Your Name (TEAMID)\""
        echo "   ./build.sh --bundle-signed"
    fi
fi 