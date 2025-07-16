#!/bin/bash

echo "📋 Testing Icon Differences Between Dev and Prod Versions"
echo "======================================================="
echo

# Function to check if TextEnhancer is running
check_running() {
    if pgrep -f "TextEnhancer" > /dev/null; then
        echo "✅ TextEnhancer is running"
        return 0
    else
        echo "❌ TextEnhancer is not running"
        return 1
    fi
}

# Function to check bundle path
check_bundle_path() {
    if pgrep -f "TextEnhancer" > /dev/null; then
        local pid=$(pgrep -f "TextEnhancer" | head -1)
        local full_path=$(ps -p $pid -o args= 2>/dev/null | awk '{print $1}')
        echo "📍 Full path: $full_path"
        
        if [[ "$full_path" == *"/.build/"* ]] || [[ "$full_path" == ".build/"* ]]; then
            echo "🔧 This is the DEVELOPMENT (non-bundled) version"
            echo "   Expected icon: 🔧 (wrench)"
        else
            echo "🚀 This is the PRODUCTION (bundled) version"
            echo "   Expected icon: ⚠️ (triangle with exclamation)"
        fi
    fi
}

# Test 1: Current running version
echo "🔍 Test 1: Check current running version"
if check_running; then
    check_bundle_path
else
    echo "💡 Start TextEnhancer first with:"
    echo "   ./build.sh --run    # Development (non-bundled)"
    echo "   ./build.sh --bundle # Production (bundled)"
fi
echo

# Test 2: Manual verification instructions
echo "🔍 Test 2: Manual verification"
echo "   1. Look at the TextEnhancer icon in your menu bar"
echo "   2. Verify the icon matches the expected icon shown above"
echo "   3. If accessibility permissions are granted, you should see:"
echo "      - Development: ✨ (stars) or wand.and.stars SF Symbol"
echo "      - Production: ✨ (stars) or wand.and.stars SF Symbol"
echo "   4. If accessibility permissions are NOT granted, you should see:"
echo "      - Development: 🔧 (wrench) or wrench SF Symbol"
echo "      - Production: ⚠️ (triangle) or exclamationmark.triangle SF Symbol"
echo

# Test 3: Instructions for testing both versions
echo "🔍 Test 3: Testing both versions"
echo "   To test development version:"
echo "   1. pkill -f TextEnhancer"
echo "   2. ./build.sh --run"
echo "   3. Check menu bar icon (should be 🔧 if no permissions)"
echo
echo "   To test production version:"
echo "   1. pkill -f TextEnhancer"
echo "   2. ./build.sh --bundle"
echo "   3. Check menu bar icon (should be ⚠️ if no permissions)"
echo

echo "🧪 Icon Difference Test Complete!"
echo "The icons help you quickly identify which version you're running:"
echo "  🔧 = Development (non-bundled, permissions reset every time)"
echo "  ⚠️ = Production (bundled, persistent permissions possible)"