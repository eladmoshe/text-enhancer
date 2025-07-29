# macOS Accessibility Permissions: Complete Troubleshooting Guide

## Overview
This document explains the complete solution to accessibility permission issues we encountered with TextEnhancer, including root causes, symptoms, and the definitive fix.

## The Problem

### Symptoms
- ⚠️ App shows exclamation mark in menu bar despite permissions appearing "enabled"
- 🔄 Clicking accessibility toggle opens System Settings but doesn't clear the warning
- ❌ Keyboard shortcuts don't work even with permissions "granted"
- 🗑️ Cannot remove app from accessibility settings (clicking "-" just disables it)
- 🔁 App keeps requesting permissions repeatedly

### Root Cause Analysis

The issue was **multiple app instances with conflicting bundle identifiers and paths** confusing macOS's permission system:

1. **Development vs Production Paths**: 
   - App was running from DerivedData: `/Users/.../Library/Developer/Xcode/DerivedData/TextEnhancer-*/Build/Products/Release/TextEnhancer.app`
   - Should run from: `/Applications/TextEnhancer.app`

2. **Multiple App Instances**:
   ```bash
   # Found scattered across system:
   /Users/.../Library/Developer/Xcode/DerivedData/TextEnhancer-dxbhrybimtjsghhgjhbvahfboymc/Build/Products/Debug/TextEnhancer.app
   /Users/.../Library/Developer/Xcode/DerivedData/TextEnhancer-dvcncbhlwuqoajgeycaxoyiowgao/Build/Products/Release/TextEnhancer.app
   /Users/.../my-code/text-llm-modify/TextEnhancer.app
   /Users/.../my-code/text-llm-modify/build/Build/Products/Release/TextEnhancer.app
   # ... and more
   ```

3. **Bundle Identifier Conflicts**:
   - Multiple apps with same bundle ID (`com.lemonadeinc.TextEnhancer`)
   - macOS permission system got confused about which app to grant permissions to
   - TCC (Transparency, Consent, and Control) database had conflicting entries

4. **Permission System Confusion**:
   - macOS grants permissions to specific app path + bundle identifier combinations
   - When multiple apps exist with same bundle ID, system doesn't know which one to trust
   - Development apps from DerivedData paths are treated as temporary/untrusted

## Why This Happens

### macOS Permission System Architecture

macOS uses several mechanisms to track app permissions:

1. **TCC Database** (`~/Library/Application Support/com.apple.TCC/TCC.db`):
   - Stores permission grants per bundle identifier
   - Links permissions to specific app paths
   - Requires exact path + bundle ID match

2. **Code Signing Verification**:
   - Apps must be properly signed for production use
   - Development builds have different signing characteristics
   - Unsigned or ad-hoc signed apps get restricted permissions

3. **App Installation Path Requirements**:
   - Production apps should be in `/Applications/`
   - Development builds in DerivedData are treated as temporary
   - System preferences only trust "properly installed" apps

### Bundle Identifier Importance

```swift
// Bundle identifier must be:
// 1. Unique across all app instances
// 2. Consistent between Info.plist and Xcode project
// 3. Properly reflected in code signing

// Info.plist
<key>CFBundleIdentifier</key>
<string>com.lemonadeinc.textenhancer.v2</string>

// project.pbxproj  
PRODUCT_BUNDLE_IDENTIFIER = com.lemonadeinc.textenhancer.v2;
```

## The Complete Solution

### Step 1: Clean Up All Existing Instances

```bash
# Kill all running instances
pkill -f "TextEnhancer"

# Find all app instances
find /Users -name "*.app" -path "*/TextEnhancer*" 2>/dev/null

# Remove development builds
rm -rf "/Users/.../Library/Developer/Xcode/DerivedData/TextEnhancer-"*
rm -rf "/Users/.../my-code/text-llm-modify/build"

# Remove old production app
rm -rf "/Applications/TextEnhancer.app"
```

### Step 2: Reset Permissions

```bash
# Reset accessibility permissions for old bundle ID
sudo tccutil reset Accessibility com.lemonadeinc.TextEnhancer

# If needed, reset all accessibility permissions
sudo tccutil reset Accessibility
```

### Step 3: Create Fresh Bundle Identifier

Update **both** configuration files:

**Info.plist:**
```xml
<key>CFBundleIdentifier</key>
<string>com.lemonadeinc.textenhancer.v2</string>
```

**project.pbxproj:**
```
PRODUCT_BUNDLE_IDENTIFIER = com.lemonadeinc.textenhancer.v2;
```

### Step 4: Clean Build and Install

```bash
# Clean build with new bundle ID
xcodebuild -scheme TextEnhancer -configuration Release -derivedDataPath build/ clean build

# Install to proper location
cp -R "build/Build/Products/Release/TextEnhancer.app" "/Applications/"

# Verify bundle identifier
codesign -dv --verbose=4 "/Applications/TextEnhancer.app" | grep Identifier
# Should show: Identifier=com.lemonadeinc.textenhancer.v2
```

### Step 5: Update Build Number for Tracking

```swift
struct AppVersion {
    static let buildNumber: Int = 1005  // Increment for tracking
    static let version: String = "1.0.3"
    static let fullVersion: String = "\(version) (build \(buildNumber))"
}
```

## Verification Steps

### 1. Confirm App Location and Identity
```bash
# Check running location
ps aux | grep "/Applications/TextEnhancer" | grep -v grep
# Should show: /Applications/TextEnhancer.app/Contents/MacOS/TextEnhancer

# Verify bundle identifier
codesign -dv --verbose=4 "/Applications/TextEnhancer.app" | grep Identifier
```

### 2. Test Permission Flow
1. Click accessibility menu item in app
2. System Settings should open to Accessibility panel
3. TextEnhancer should appear in list as a new entry
4. Enable the toggle
5. Exclamation mark should disappear from menu bar
6. Keyboard shortcuts should work

### 3. Check Logs
```bash
tail -f "/Users/$USER/Library/Logs/TextEnhancer/debug.log"
# Should show build 1005 and accessibility permissions working
```

## Prevention: Best Practices

### 1. Consistent Bundle Identifiers
- Use unique, versioned bundle IDs for major releases
- Ensure Info.plist and project.pbxproj match exactly
- Never reuse bundle IDs from problematic builds

### 2. Proper Installation Process
- Always install production builds to `/Applications/`
- Never run production versions from DerivedData
- Clean up old development builds regularly

### 3. Permission Management
- Use `tccutil reset` when changing bundle IDs
- Test permissions on clean systems
- Document permission requirements clearly

### 4. Development Workflow
```bash
# During development, use separate bundle ID
com.lemonadeinc.textenhancer.dev

# For production releases
com.lemonadeinc.textenhancer.v1
com.lemonadeinc.textenhancer.v2  # When fixing permission issues
```

## Debugging Commands

### Check Current State
```bash
# Running app info
ps aux | grep -i textenhancer | grep -v grep

# Bundle identifier verification  
codesign -dv --verbose=4 "/Applications/TextEnhancer.app" | grep Identifier

# Find all instances
find /Users -name "*.app" -path "*TextEnhancer*" 2>/dev/null

# Permission status
# Note: TCC database requires sudo access to read directly
```

### Reset Everything (Nuclear Option)
```bash
# Kill all instances
pkill -f "TextEnhancer"

# Remove all app instances
find /Users -name "TextEnhancer.app" -type d -exec rm -rf {} + 2>/dev/null

# Reset all accessibility permissions
sudo tccutil reset Accessibility

# Clean Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData/TextEnhancer-*
```

## Key Learnings

1. **Bundle Identifier Conflicts are Silent but Deadly**: Multiple apps with the same bundle ID create invisible conflicts in the permission system.

2. **Development Paths Matter**: Apps running from DerivedData are treated differently than those in `/Applications/`.

3. **TCC Database is Sticky**: Once confused, the permission system needs explicit reset via `tccutil`.

4. **Code Signing Affects Permissions**: Properly signed apps in proper locations get better permission handling.

5. **Fresh Start Sometimes Required**: When permissions are thoroughly confused, changing the bundle identifier provides a clean slate.

## Success Indicators

✅ **App runs from `/Applications/TextEnhancer.app`**  
✅ **Single bundle identifier across all config files**  
✅ **Accessibility toggle works immediately**  
✅ **No exclamation mark in menu bar**  
✅ **Keyboard shortcuts function**  
✅ **App can be properly removed from accessibility settings**

---

*This solution was developed after extensive debugging of macOS accessibility permission system behavior. The key insight was that multiple app instances with the same bundle identifier create irreconcilable conflicts in the TCC permission database, requiring both cleanup and a fresh bundle identifier to resolve.*