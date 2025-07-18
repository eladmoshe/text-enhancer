#!/bin/bash

echo "🔍 Comprehensive Permission Diagnostics for TextEnhancer"
echo "======================================================="
echo

# Function to check accessibility permission using Swift
check_accessibility_swift() {
    cat > /tmp/check_accessibility.swift << 'EOF'
import ApplicationServices

let isTrusted = AXIsProcessTrusted()
print("AXIsProcessTrusted(): \(isTrusted)")

// Test actual functionality
let systemWideElement = AXUIElementCreateSystemWide()
var focusedElement: CFTypeRef?
let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

print("AXUIElementCopyAttributeValue result: \(result.rawValue)")
print("Can actually access accessibility: \(result == .success)")

// Print bundle info
print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
print("Bundle path: \(Bundle.main.bundlePath)")
print("Process name: \(ProcessInfo.processInfo.processName)")
EOF

    swift /tmp/check_accessibility.swift 2>/dev/null
    rm -f /tmp/check_accessibility.swift
}

# Function to check screen recording permission using Swift  
check_screen_recording_swift() {
    cat > /tmp/check_screen_recording.swift << 'EOF'
import CoreGraphics

if #available(macOS 10.15, *) {
    let hasPermission = CGPreflightScreenCaptureAccess()
    print("CGPreflightScreenCaptureAccess(): \(hasPermission)")
    
    // Test actual screen capture
    let displayID = CGMainDisplayID()
    let image = CGDisplayCreateImage(displayID)
    print("Can actually capture screen: \(image != nil)")
    
    if let image = image {
        print("Screen capture successful - image size: \(CGImageGetWidth(image))x\(CGImageGetHeight(image))")
    }
} else {
    print("CGPreflightScreenCaptureAccess(): true (macOS < 10.15)")
}
EOF

    swift /tmp/check_screen_recording.swift 2>/dev/null
    rm -f /tmp/check_screen_recording.swift
}

# Test 1: Check running processes
echo "🔍 Test 1: Running TextEnhancer Processes"
echo "==========================================="
echo "Current TextEnhancer processes:"
ps aux | grep TextEnhancer | grep -v grep | while read line; do
    echo "  $line"
done
echo

# Test 2: Check installed app bundle
echo "🔍 Test 2: App Bundle Information"
echo "=================================="
if [ -d "/Applications/TextEnhancer.app" ]; then
    echo "✅ Found at /Applications/TextEnhancer.app"
    echo "Bundle ID: $(defaults read /Applications/TextEnhancer.app/Contents/Info.plist CFBundleIdentifier 2>/dev/null || echo 'Not found')"
    echo "Bundle version: $(defaults read /Applications/TextEnhancer.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo 'Not found')"
    echo "Code signature: $(codesign -dv /Applications/TextEnhancer.app 2>&1 | grep "Authority=" | head -1 || echo 'Not signed')"
fi

if [ -d "$HOME/Applications/TextEnhancer.app" ]; then
    echo "✅ Found at ~/Applications/TextEnhancer.app"
    echo "Bundle ID: $(defaults read ~/Applications/TextEnhancer.app/Contents/Info.plist CFBundleIdentifier 2>/dev/null || echo 'Not found')"
    echo "Bundle version: $(defaults read ~/Applications/TextEnhancer.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo 'Not found')"
    echo "Code signature: $(codesign -dv ~/Applications/TextEnhancer.app 2>&1 | grep "Authority=" | head -1 || echo 'Not signed')"
fi
echo

# Test 3: Check accessibility permissions using Swift
echo "🔍 Test 3: Accessibility Permission Check (Swift)"
echo "=================================================="
check_accessibility_swift
echo

# Test 4: Check screen recording permissions using Swift
echo "🔍 Test 4: Screen Recording Permission Check (Swift)"
echo "====================================================="
check_screen_recording_swift
echo

# Test 5: Check macOS permission database
echo "🔍 Test 5: macOS Permission Database"
echo "====================================="
echo "Accessibility permissions in system database:"
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT client, auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%textenhancer%' OR client LIKE '%TextEnhancer%';" 2>/dev/null || echo "Cannot read system TCC database (expected)"

echo "User accessibility permissions:"
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT client, auth_value FROM access WHERE service='kTCCServiceAccessibility' AND (client LIKE '%textenhancer%' OR client LIKE '%TextEnhancer%');" 2>/dev/null || echo "No user TCC entries found"

echo "Screen recording permissions:"
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT client, auth_value FROM access WHERE service='kTCCServiceScreenCapture' AND (client LIKE '%textenhancer%' OR client LIKE '%TextEnhancer%');" 2>/dev/null || echo "No screen recording TCC entries found"
echo

# Test 6: Check what System Settings sees
echo "🔍 Test 6: System Settings Check"
echo "================================="
echo "To manually verify permissions:"
echo "1. Open System Settings > Privacy & Security > Accessibility"
echo "2. Look for 'TextEnhancer' in the list"
echo "3. Check if it's enabled (checkbox checked)"
echo "4. Open Privacy & Security > Screen Recording" 
echo "5. Look for 'TextEnhancer' in the list"
echo "6. Check if it's enabled (checkbox checked)"
echo

echo "🔧 Diagnostic Complete!"
echo "======================="
echo "If permissions show as granted but the app still shows warnings:"
echo "1. The bundle identity might have changed"
echo "2. Multiple versions might be running"
echo "3. Permission cache might need clearing"
echo "4. App might need a full restart" 