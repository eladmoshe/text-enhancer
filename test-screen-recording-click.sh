#!/bin/bash

# Test script to verify screen recording permission functionality

echo "📋 Testing Screen Recording Permission Functionality"
echo "================================================="
echo

# Test 1: Check if app is running
echo "🔍 Test 1: Checking if TextEnhancer is running..."
if pgrep -f "TextEnhancer" > /dev/null; then
    echo "✅ TextEnhancer is running"
else
    echo "❌ TextEnhancer is not running"
    echo "💡 Run: ./build.sh --bundle"
    exit 1
fi

# Test 2: Check current screen recording permission
echo
echo "🔍 Test 2: Checking current screen recording permission..."
python3 -c "
import subprocess
result = subprocess.run(['python3', '-c', '''
import ctypes
import ctypes.util
CoreGraphics = ctypes.CDLL(ctypes.util.find_library('CoreGraphics'))
has_permission = CoreGraphics.CGPreflightScreenCaptureAccess()
print('Screen recording permission:', 'GRANTED' if has_permission else 'DENIED')
'''], capture_output=True, text=True)
print(result.stdout.strip())
"

# Test 3: Check if menu shows screen recording option
echo
echo "🔍 Test 3: Manual test instructions for screen recording permission..."
echo "   1. Click on the TextEnhancer menu bar icon"
echo "   2. Look for 'Screen Recording: Disabled (Click to enable)' menu item"
echo "   3. Click on that menu item"
echo "   4. Verify that System Settings opens to Privacy & Security > Screen Recording"
echo "   5. Check that an alert dialog appears with detailed instructions"
echo

# Test 4: Check if shortcuts with screenshots work
echo "🔍 Test 4: Testing screenshot-enabled shortcuts..."
echo "   Available shortcuts with screenshots:"
echo "   - ⌃⌥6 - Describe Screen"
echo "   - ⌃⌥7 - Analyze Screen (OpenAI)"
echo
echo "   Manual test:"
echo "   1. Select some text"
echo "   2. Press ⌃⌥6 (Ctrl+Option+6)"
echo "   3. If screen recording permission is not granted, you should see an error"
echo "   4. If permission is granted, screenshot should be included in the API call"
echo

echo "🧪 Screen Recording Permission Test Complete!"
echo "Please perform the manual tests above to verify functionality."