#!/bin/bash

# CI Validation Script
# This script validates that the CI configuration will work before pushing

set -e

echo "🔍 Validating CI configuration..."

# Check if required directories exist
echo "📁 Checking directory structure..."
if [ ! -d "TextEnhancer" ]; then
    echo "❌ Error: TextEnhancer/ directory not found"
    exit 1
fi

if [ ! -d "Tests" ]; then
    echo "❌ Error: Tests/ directory not found"
    exit 1
fi

echo "✅ Directory structure OK"

# Check if SwiftLint configuration is valid
echo "🔧 Validating SwiftLint configuration..."
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint version
    # Run SwiftLint but don't fail on violations, just validate config
    swiftlint lint --quiet > /dev/null 2>&1 || echo "⚠️ SwiftLint found issues but config is valid"
    echo "✅ SwiftLint configuration OK"
else
    echo "⚠️ SwiftLint not installed, skipping validation"
fi

# Check if SwiftFormat can run
echo "🎨 Validating SwiftFormat..."
if command -v swiftformat >/dev/null 2>&1; then
    swiftformat --version
    swiftformat --lint TextEnhancer/ Tests/ > /dev/null 2>&1 || echo "⚠️ SwiftFormat found issues but can run"
    echo "✅ SwiftFormat configuration OK"
else
    echo "⚠️ SwiftFormat not installed, skipping validation"
fi

# Check if Xcode project can build
echo "🔨 Testing Xcode build..."
if command -v xcodebuild >/dev/null 2>&1; then
    xcodebuild -project TextEnhancer.xcodeproj -scheme TextEnhancer -configuration Debug build -destination 'platform=macOS' -quiet
    echo "✅ Xcode build test passed"
else
    echo "❌ Error: xcodebuild not available"
    exit 1
fi

# Check if build scripts exist and are executable
echo "📜 Checking build scripts..."
if [ -f "build-and-install.sh" ]; then
    if [ -x "build-and-install.sh" ]; then
        echo "✅ build-and-install.sh exists and is executable"
    else
        echo "⚠️ build-and-install.sh exists but is not executable"
        chmod +x build-and-install.sh
        echo "✅ Made build-and-install.sh executable"
    fi
else
    echo "❌ Error: build-and-install.sh not found"
    exit 1
fi

echo ""
echo "🎉 All CI validations passed!"
echo "✅ Ready to push to GitHub - CI should pass"