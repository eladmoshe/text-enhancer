#!/bin/bash

echo "🔍 Testing Screen Recording Permission Request..."

# Step 1: Check if app is running
if ! pgrep -f TextEnhancer > /dev/null; then
    echo "❌ TextEnhancer is not running"
    echo "💡 Run: ./build.sh --bundle && open ~/Applications/TextEnhancer.app"
    exit 1
fi

echo "✅ TextEnhancer is running"

# Step 2: Check current screen recording permission status
echo "🔍 Checking current screen recording permission status..."

# Use the same method as the app
if python3 -c "
import Quartz
result = Quartz.CGPreflightScreenCaptureAccess()
print('✅ Screen recording: GRANTED' if result else '⚠️ Screen recording: DENIED')
exit(0 if result else 1)
" 2>/dev/null; then
    echo "✅ Screen recording permissions are already granted"
else
    echo "⚠️ Screen recording permissions are not granted"
    echo "🔧 Test: Click on TextEnhancer menu bar icon"
    echo "🔧 Test: Click on 'Screen Recording: Disabled (Click to enable)'"
    echo "🔧 Expected: System Settings opens to Screen Recording section"
    echo "🔧 Expected: Alert dialog appears with instructions"
    echo ""
    echo "📋 Manual Test Checklist:"
    echo "   □ Menu bar icon is visible"
    echo "   □ Click menu bar icon"
    echo "   □ See 'Screen Recording: Disabled' menu item"
    echo "   □ Click the screen recording menu item"
    echo "   □ System Settings opens to Privacy & Security > Screen Recording"
    echo "   □ Alert dialog appears with clear instructions"
    echo "   □ Instructions include correct app path"
    echo ""
    echo "💡 After granting permission, run this script again to verify"
fi

# Step 3: Check app bundle path
echo "🔍 App bundle path: $(find ~/Applications -name 'TextEnhancer.app' -type d 2>/dev/null)"

# Step 4: Check bundle identifier
if [ -f ~/Applications/TextEnhancer.app/Contents/Info.plist ]; then
    echo "🔍 Bundle identifier: $(defaults read ~/Applications/TextEnhancer.app/Contents/Info.plist CFBundleIdentifier)"
else
    echo "❌ Info.plist not found"
fi

echo ""
echo "🎯 Test Status: $([ $? -eq 0 ] && echo 'PASSED' || echo 'NEEDS_MANUAL_TESTING')"