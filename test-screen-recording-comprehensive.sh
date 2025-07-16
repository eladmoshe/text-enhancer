#!/bin/bash

echo "📋 Comprehensive Screen Recording Permission Test"
echo "============================================="
echo

# Function to check screen recording permission
check_screen_permission() {
    python3 -c "
import ctypes
import ctypes.util
CoreGraphics = ctypes.CDLL(ctypes.util.find_library('CoreGraphics'))
has_permission = CoreGraphics.CGPreflightScreenCaptureAccess()
print('✅ GRANTED' if has_permission else '❌ DENIED')
"
}

# Function to test screen capture capability
test_screen_capture() {
    echo "🔍 Testing screenshot capture capability..."
    python3 -c "
import ctypes
import ctypes.util
import sys

# Load CoreGraphics
CoreGraphics = ctypes.CDLL(ctypes.util.find_library('CoreGraphics'))

# Check permission first
has_permission = CoreGraphics.CGPreflightScreenCaptureAccess()
print(f'Permission status: {\"GRANTED\" if has_permission else \"DENIED\"}')

if not has_permission:
    print('❌ Cannot capture screenshot - permission denied')
    sys.exit(1)

# Try to capture screen
try:
    display_id = 0  # Main display
    image_ref = CoreGraphics.CGDisplayCreateImage(display_id)
    if image_ref:
        print('✅ Successfully captured screenshot')
        # Note: In real usage, we'd convert to base64 and use in API call
    else:
        print('❌ Failed to capture screenshot')
        sys.exit(1)
except Exception as e:
    print(f'❌ Exception during screenshot capture: {e}')
    sys.exit(1)
"
}

# Test 1: Check current permission status
echo "🔍 Test 1: Current screen recording permission status"
echo -n "Current permission: "
check_screen_permission
echo

# Test 2: Check if TextEnhancer is running
echo "🔍 Test 2: TextEnhancer running status"
if pgrep -f "TextEnhancer" > /dev/null; then
    echo "✅ TextEnhancer is running"
else
    echo "❌ TextEnhancer is not running"
    echo "💡 Start with: ./build.sh --bundle"
    exit 1
fi
echo

# Test 3: Test screen capture capability
echo "🔍 Test 3: Screen capture capability"
test_screen_capture
echo

# Test 4: Check if screenshot shortcuts are configured
echo "🔍 Test 4: Screenshot shortcuts configuration"
if [ -f "/Users/elad.moshe/Library/Application Support/TextEnhancer/config.json" ]; then
    echo "✅ Configuration file exists"
    screenshot_shortcuts=$(grep -c "\"includeScreenshot\": true" "/Users/elad.moshe/Library/Application Support/TextEnhancer/config.json")
    echo "📊 Number of screenshot-enabled shortcuts: $screenshot_shortcuts"
    
    if [ "$screenshot_shortcuts" -gt 0 ]; then
        echo "✅ Screenshot shortcuts are configured"
        echo "🔍 Screenshot shortcuts found:"
        grep -B 3 -A 1 "\"includeScreenshot\": true" "/Users/elad.moshe/Library/Application Support/TextEnhancer/config.json" | grep "\"name\"" | sed 's/.*"name": "\([^"]*\)".*/   - \1/'
    else
        echo "❌ No screenshot shortcuts configured"
    fi
else
    echo "❌ Configuration file not found"
fi
echo

# Test 5: Instructions for manual permission test
echo "🔍 Test 5: Manual permission test instructions"
echo "   1. Click on TextEnhancer menu bar icon"
echo "   2. Look for '⚠️ Screen Recording: Disabled (Click to enable)' menu item"
echo "   3. Click on that menu item"
echo "   4. Verify System Settings opens to Privacy & Security > Screen Recording"
echo "   5. Check that an alert dialog appears with instructions"
echo "   6. Add TextEnhancer to the list and enable it"
echo "   7. Restart TextEnhancer"
echo "   8. Run this test again to verify permission is granted"
echo

echo "🧪 Test Complete!"
echo "📝 Current Status Summary:"
echo -n "   Screen Recording Permission: "
check_screen_permission
echo "   TextEnhancer Status: $(pgrep -f TextEnhancer > /dev/null && echo 'Running' || echo 'Not Running')"
echo "   Screenshot Shortcuts: $screenshot_shortcuts configured"