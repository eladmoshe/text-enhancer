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
    echo "🛑 Checking for running TextEnhancer instances..."
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

# Check if --run flag is provided
if [[ "$1" == "--run" ]]; then
    stop_existing_instances
    echo "🎯 Running TextEnhancer..."
    echo "Note: You'll need to grant accessibility permissions when prompted"
    echo "Press Ctrl+C to stop the application"
    echo ""
    .build/debug/TextEnhancer
elif [[ "$1" == "--bundle" ]]; then
    stop_existing_instances
    echo "📦 Creating app bundle..."
    make bundle
    echo ""
    echo "🎯 Running TextEnhancer as app bundle..."
    echo "Note: This will show as 'TextEnhancer' in accessibility permissions"
    open TextEnhancer.app
elif [[ "$1" == "--test" ]]; then
    echo "🧪 Running tests with coverage..."
    swift test --enable-code-coverage
    echo ""
    echo "📊 Code coverage report:"
    echo "Use: xcrun llvm-cov show .build/debug/TextEnhancerPackageTests.xctest/Contents/MacOS/TextEnhancerPackageTests -instr-profile .build/debug/codecov/default.profdata"
elif [[ "$1" == "--settings" ]]; then
    echo "⚙️  Opening TextEnhancer settings..."
    if [ -d "TextEnhancer.app" ]; then
        open TextEnhancer.app --args --settings
    else
        echo "📦 Creating app bundle first..."
        make bundle
        open TextEnhancer.app --args --settings
    fi
fi

echo ""
echo "🎉 Build complete!"
echo "To run the application:"
echo "  ./build.sh --run          # Run debug executable"
echo "  ./build.sh --bundle       # Create and run as app bundle (recommended)"
echo "  ./build.sh --test         # Run tests with coverage"
echo "  ./build.sh --settings     # Open settings window directly"
echo "  .build/debug/TextEnhancer  # Run debug executable directly"
echo ""
echo "For release build:"
echo "  swift build -c release"
echo "  make bundle               # Create app bundle"
echo "  open TextEnhancer.app     # Run app bundle" 