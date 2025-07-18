import Foundation
import ApplicationServices

print("🔍 Manual Permission Test")
print("========================")

// Check current status
let currentStatus = AXIsProcessTrusted()
print("Current accessibility status: \(currentStatus)")

// Print app info
print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
print("Process name: \(ProcessInfo.processInfo.processName)")

if !currentStatus {
    print("Requesting accessibility permissions...")
    
    // Request with prompt
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
    print("Permission request result: \(result)")
    
    // Wait and check again
    print("Waiting 3 seconds...")
    Thread.sleep(forTimeInterval: 3.0)
    
    let newStatus = AXIsProcessTrusted()
    print("Status after request: \(newStatus)")
} else {
    print("Permissions already granted!")
}

// Test actual functionality
print("\nTesting accessibility functionality:")
let systemWideElement = AXUIElementCreateSystemWide()
var focusedElement: CFTypeRef?
let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

print("AXUIElementCopyAttributeValue result: \(result.rawValue)")
if result == .success {
    print("✅ Can access accessibility APIs")
} else {
    print("❌ Cannot access accessibility APIs (Error: \(result.rawValue))")
} 