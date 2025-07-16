# Code Signing Implementation Summary

This document summarizes the implementation of persistent accessibility permissions for TextEnhancer through code signing.

## Problem Solved

**Before**: Accessibility permissions reset after every rebuild, requiring manual re-approval each time.  
**After**: Permissions persist across rebuilds when using signed builds.

## Implementation Overview

### 1. Enhanced Makefile

**New Targets Added**:
- `bundle-signed` - Creates signed app bundle
- `install-signed` - Installs signed bundle to ~/Applications
- `check-sign` - Checks certificate availability and status
- `install-location` - Shows installation status
- `clean-sign` - Cleans build and signing artifacts
- `notarize` - Notarizes signed app (optional)

**Key Features**:
- Automatic fallback to unsigned builds when no certificate available
- Clear status reporting and guidance
- Consistent bundle identifier (`com.textenhancer.app`)
- Proper entitlements embedding

### 2. Enhanced Build Script

**New Commands**:
- `./build.sh --bundle-signed` - Build and install signed version
- `./build.sh --status` - Show installation and signing status  
- `./build.sh --help` - Comprehensive help with signing guidance

**Features**:
- Automatic certificate detection and guidance
- Clear differentiation between signed/unsigned builds
- Persistent installation to ~/Applications/TextEnhancer.app

### 3. Code Signing Process

**Signing Command**:
```bash
codesign --force --deep \
    --options runtime \
    --entitlements TextEnhancer.entitlements \
    --timestamp \
    --sign "$SIGN_ID" TextEnhancer.app
```

**Requirements**:
- `SIGN_ID` environment variable with certificate name
- Valid Apple Development certificate
- Consistent bundle identifier across builds

### 4. Documentation

**Created**:
- `docs/ACCESSIBILITY_PERMISSIONS.md` - Comprehensive setup guide
- `QUICK_START_SIGNING.md` - 5-minute quick reference
- Updated `README.md` with signing information

## Technical Details

### Why This Works

macOS identifies apps in the TCC database using:
1. **Bundle Identifier**: `com.textenhancer.app` (stays constant)
2. **Code Signature**: Certificate chain (stays constant with same SIGN_ID)

When both remain consistent, macOS treats rebuilds as updates to the same app.

### Certificate Requirements

**Development**: Apple Development certificate (free Apple ID sufficient)  
**Distribution**: Developer ID Application certificate (paid account required)  
**App Store**: Apple Distribution certificate (paid account required)

#### Certificate Chain Resolution

For Apple Development certificates, macOS requires a complete certificate chain:

1. **Your Development Certificate** → issued by Apple Worldwide Developer Relations Certification Authority (G3)
2. **WWDR G3 Intermediate Certificate** → issued by Apple Root CA
3. **Apple Root CA** → self-signed root certificate

**Common Issue**: `errSecInternalComponent` error during signing typically indicates missing intermediate certificates in the chain.

**Resolution**:
```bash
# Download and install WWDR G3 intermediate certificate
curl -o ~/Downloads/wwdrg3.der "http://certs.apple.com/wwdrg3.der"
security add-certificates ~/Downloads/wwdrg3.der

# Verify certificate chain
security find-certificate -c "Apple Development: your.email@example.com" -p > /tmp/dev_cert.pem
security verify-cert -c /tmp/dev_cert.pem
```

**Note**: The Apple Root CA is typically pre-installed on macOS. If missing, it can be downloaded from Apple's Certificate Authority page.

### Entitlements Used

```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.cs.allow-jit</key>
<false/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<false/>
```

## User Workflow

### One-Time Setup
1. Create development certificate in Xcode
2. Export certificate name: `export SIGN_ID="Apple Development: Name (TEAMID)"`
3. Build signed version: `./build.sh --bundle-signed`
4. Grant accessibility permissions (one time only)

### Daily Development
```bash
# Quick development (permissions reset)
./build.sh --run

# Testing with persistent permissions
./build.sh --bundle-signed
```

## Build Command Matrix

| Command | Build Type | Install Location | Permissions Persist? |
|---------|------------|------------------|---------------------|
| `./build.sh --run` | Debug executable | N/A | ❌ No |
| `./build.sh --bundle` | Unsigned bundle | ~/Applications | ❌ No |
| `./build.sh --bundle-signed` | Signed bundle | ~/Applications | ✅ Yes |

## Status Commands

| Command | Purpose |
|---------|---------|
| `./build.sh --status` | Installation and signing status |
| `make check-sign` | Certificate availability |
| `make install-location` | Installation details |

## Error Handling

**No Certificates**: Clear guidance to create development certificate  
**SIGN_ID Not Set**: Shows available certificates and export format  
**Signing Fails**: Detailed error reporting with troubleshooting steps  
**Mixed Builds**: Guidance to clean and use consistent signing

## Future Enhancements

### Automatic Version Bumping
```bash
# Could add to build script
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" Info.plist
```

### Team Certificate Management
- Shared team certificate setup
- CI/CD integration
- Automatic certificate renewal

### Notarization Integration
- Automated notarization for distribution
- Keychain profile management
- Stapling verification

## Testing Verification

### Manual Testing
1. Build signed version: `./build.sh --bundle-signed`
2. Grant accessibility permissions
3. Rebuild: `./build.sh --bundle-signed`
4. Verify no new permission prompt

### Automated Verification
```bash
# Check TCC database entry
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client,auth_value FROM access WHERE client LIKE '%textenhancer%';"
```

## Compatibility

**macOS Versions**: 14.0+ (Sonoma and later)  
**Xcode Versions**: Any version supporting Apple Development certificates  
**Swift Versions**: 5.9+ (existing requirement)

## Security Considerations

- Hardened runtime enabled (`--options runtime`)
- Minimal entitlements (only required permissions)
- Timestamp signing for certificate validation
- Deep signing for nested components

## Migration Path

**Existing Users**:
1. Remove old TextEnhancer entries from accessibility settings
2. Set up signing certificate
3. Use `./build.sh --bundle-signed`
4. Re-approve permissions once

**New Users**:
- Follow setup guide in `docs/ACCESSIBILITY_PERMISSIONS.md`
- Use signed builds from the start

This implementation provides a seamless development experience while maintaining the security benefits of macOS's permission system. 