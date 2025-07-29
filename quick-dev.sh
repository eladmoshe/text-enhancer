#!/bin/bash

# Quick Development Build Script
# For rapid iteration during development - still ensures proper permissions

set -e

APP_NAME="TextEnhancer"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Quick Development Build"
echo "⚠️  Building for proper permissions (app is useless without them!)"

# Kill running instances
pkill -f "${APP_NAME}" 2>/dev/null || true

# Quick build and install
cd "${PROJECT_DIR}"
xcodebuild -scheme "${APP_NAME}" -configuration Release -derivedDataPath build/ build > /dev/null 2>&1

if [ ! -d "build/Build/Products/Release/${APP_NAME}.app" ]; then
    echo "❌ Build failed"
    exit 1
fi

# Install and launch
rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null || true
cp -R "build/Build/Products/Release/${APP_NAME}.app" "/Applications/"
open "/Applications/${APP_NAME}.app"

echo "✅ Quick build complete - app launched from Applications"
echo "💡 For full verification, use: ./build-and-install.sh"