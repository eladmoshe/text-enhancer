# Persistent Accessibility Permissions Setup

This guide explains how to set up TextEnhancer so that accessibility permissions persist across rebuilds, eliminating the need to re-approve permissions every time you rebuild the app.

## The Problem

By default, macOS treats each rebuild of TextEnhancer as a "different" app because the binary signature changes. This means:
- ❌ You must re-approve accessibility permissions after every rebuild
- ❌ The app disappears from System Preferences → Privacy & Security → Accessibility
- ❌ You have to manually delete old entries and re-add the app

## The Solution: Code Signing

Code signing makes macOS recognize your app as the same entity across rebuilds by using a consistent certificate and bundle identifier.

## Quick Setup (5 minutes)

### Step 1: Create a Development Certificate

1. **Open Xcode**
2. **Go to Preferences** (Xcode → Preferences or Cmd+,)
3. **Click "Accounts" tab**
4. **Add your Apple ID** if not already added
5. **Select your Apple ID** → Click "Manage Certificates..."
6. **Click the "+" button** → Select "Apple Development"
7. **Click "Done"**

### Step 2: Find Your Certificate Name

```bash
# List available certificates
make check-sign
```

Look for a line like:
```
1) 1234567890ABCDEF "Apple Development: Your Name (TEAM123ABC)"
```

### Step 3: Set Environment Variable

```bash
# Export your certificate name (replace with your actual certificate)
export SIGN_ID="Apple Development: Your Name (TEAM123ABC)"

# Optional: Add to your shell profile for persistence
echo 'export SIGN_ID="Apple Development: Your Name (TEAM123ABC)"' >> ~/.zshrc
```

### Step 4: Build and Install Signed Version

```bash
# Build, sign, and install to ~/Applications
./build.sh --bundle-signed
```

### Step 5: Grant Permissions (One Time Only!)

1. **Launch the app** (it should open automatically)
2. **When prompted for accessibility permissions**:
   - Click "Open System Preferences"
   - Click the lock icon and enter your password
   - Check the box next to "TextEnhancer"
   - Close System Preferences

**That's it!** From now on, accessibility permissions will persist across all rebuilds.

## Verification

### Check Installation Status
```bash
./build.sh --status
```

This will show:
- ✅ Installation location and status
- ✅ Whether the app is signed
- ✅ Available certificates

### Test Persistence
1. **Rebuild the app**: `./build.sh --bundle-signed`
2. **Launch it**: The app should work immediately without permission prompts
3. **Check System Preferences**: TextEnhancer should still be listed and enabled

## Build Commands Reference

| Command | Purpose | Permissions Persist? |
|---------|---------|---------------------|
| `./build.sh --run` | Debug version | ❌ No |
| `./build.sh --bundle` | Unsigned bundle | ❌ No |
| `./build.sh --bundle-signed` | Signed bundle | ✅ Yes |

## Troubleshooting

### "No code signing certificates found"

**Solution**: Create a development certificate in Xcode (see Step 1 above)

### "SIGN_ID not set"

**Solution**: Export your certificate name (see Steps 2-3 above)

### "codesign failed"

**Possible causes**:
- Certificate name is incorrect
- Certificate has expired
- Xcode needs to be updated

**Solution**: Run `make check-sign` to see available certificates

### Permissions still reset after signing

**Possible causes**:
- Using the wrong build command (use `--bundle-signed`)
- Running from wrong location (should run from `~/Applications/TextEnhancer.app`)
- Certificate changed between builds

**Solution**: 
1. Check installation: `./build.sh --status`
2. Rebuild with signing: `./build.sh --bundle-signed`
3. Always launch from: `open ~/Applications/TextEnhancer.app`

### Multiple TextEnhancer entries in accessibility settings

**Cause**: Mixed signed/unsigned builds

**Solution**:
1. Remove all TextEnhancer entries from accessibility settings
2. Use only signed builds: `./build.sh --bundle-signed`
3. Re-approve permissions once

## Advanced: Notarization (Optional)

For distribution outside your development machine:

### Setup Notarization
```bash
# One-time setup (requires Apple ID with app-specific password)
xcrun notarytool store-credentials TEXTENHANCER_NOTARY \
  --apple-id your-apple-id@example.com \
  --team-id TEAM123ABC \
  --password app-specific-password

# Set environment variable
export NOTARY_PROFILE=TEXTENHANCER_NOTARY
```

### Notarize Release
```bash
# Build, sign, and notarize
make bundle-signed
make notarize
```

## Technical Details

### Why This Works

macOS uses the **code signing requirement string** to identify apps in the TCC (Transparency, Consent, and Control) database. This string includes:
- Bundle identifier (`com.textenhancer.app`)
- Certificate chain (your Apple Developer certificate)

When both remain consistent across builds, macOS treats the app as the same entity.

### What Gets Signed

- Main executable (`TextEnhancer`)
- App bundle (`TextEnhancer.app`)
- Embedded entitlements and Info.plist

### Entitlements Used

- `com.apple.security.automation.apple-events` - For text capture/replacement
- `com.apple.security.network.client` - For API calls
- Hardened runtime options for security

## Development Workflow

### Daily Development
```bash
# Quick development cycle (permissions reset each time)
./build.sh --run

# Test with persistent permissions
./build.sh --bundle-signed
```

### Release Preparation
```bash
# Clean build with signing
make clean-sign
./build.sh --bundle-signed

# Optional: Notarize for distribution
make notarize
```

### Team Setup

Each developer needs their own certificate:
1. **Add Apple ID to Xcode**
2. **Create development certificate**
3. **Set their own SIGN_ID**

The bundle identifier (`com.textenhancer.app`) stays the same, but each developer uses their own certificate.

## FAQ

**Q: Do I need a paid Apple Developer account?**
A: No, a free Apple ID is sufficient for development certificates and local signing.

**Q: Will this work for other team members?**
A: Yes, each developer sets up their own certificate with the same bundle identifier.

**Q: Can I use this for App Store distribution?**
A: You'll need a "Developer ID Application" certificate for outside App Store distribution, or an "Apple Distribution" certificate for App Store submission.

**Q: What if I don't want to set up signing?**
A: You can still use unsigned builds, but you'll need to re-approve accessibility permissions after each rebuild.

**Q: Does this affect app functionality?**
A: No, the app functionality is identical. Only the permission persistence changes. 