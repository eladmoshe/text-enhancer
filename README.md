# TextEnhancer

A macOS menu bar app that enhances selected text using AI (Claude/OpenAI) with keyboard shortcuts.

## ⚠️ CRITICAL: Accessibility Permissions Required

**This app is COMPLETELY USELESS without accessibility permissions.** It cannot capture or replace text without them.

## Quick Start

### Option 1: Automated Build & Install (Recommended)
```bash
./build-and-install.sh
```
This script ensures proper installation and guides you through permission setup.

### Option 2: Quick Development Build
```bash
./quick-dev.sh
```
For rapid iteration during development.

### Option 3: Xcode Build
1. Open `TextEnhancer.xcodeproj` in Xcode
2. Build & Run (⌘+R)
3. The post-build script automatically installs to Applications

## Permission Setup (REQUIRED)

After building, you MUST enable accessibility permissions:

1. **Launch the app** - it will appear in your menu bar with a ⚠️ icon
2. **Click the warning icon** - System Settings will open
3. **Enable TextEnhancer** in Privacy & Security → Accessibility
4. **Verify**: The warning icon should disappear

### If Permissions Don't Work

If you see persistent permission issues:
```bash
# Reset all accessibility permissions
sudo tccutil reset Accessibility

# Then rebuild and reinstall
./build-and-install.sh
```

## Development

### Build Requirements
- macOS 15.5+
- Xcode 16.0+
- Valid Apple Developer certificate (for code signing)

### Architecture
- **Bundle ID**: `com.lemonadeinc.textenhancer.v2` (versioned to avoid permission conflicts)
- **Installation Path**: `/Applications/TextEnhancer.app` (required for permissions)
- **Build Number**: Auto-incremented for tracking

### Why Applications Folder is Required

macOS treats apps differently based on location:
- ✅ `/Applications/`: Trusted, eligible for accessibility permissions
- ❌ `DerivedData/`: Temporary, restricted permissions
- ❌ Other locations: May not get proper permission handling

### Bundle Identifier Management

The bundle identifier is CRITICAL for permissions:
- Must be consistent across `Info.plist` and `project.pbxproj`
- Versioned (`v2`) to avoid conflicts with previous builds
- Never reuse bundle IDs that had permission issues

## Features

- **Keyboard Shortcuts**: Customizable shortcuts for different prompts
- **Multi-Provider**: Supports Claude and OpenAI APIs
- **Screenshot Analysis**: Can capture and analyze screen content
- **Menu Bar Interface**: Quick access to all functions

## Configuration

1. Click the menu bar icon → Settings
2. Configure API keys for Claude/OpenAI
3. Set up custom keyboard shortcuts
4. Test prompts with the built-in test feature

## Troubleshooting

### App Shows Warning Icon
- Accessibility permissions not granted
- Follow permission setup steps above

### Keyboard Shortcuts Don't Work
- Check accessibility permissions
- Verify app is running from `/Applications/`
- Check logs: `~/Library/Logs/TextEnhancer/debug.log`

### "Cannot Remove from Accessibility Settings"
- This indicates bundle ID conflicts
- Run `./build-and-install.sh` to rebuild with fresh bundle ID

### Build Issues
- Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/TextEnhancer-*`
- Verify code signing certificate is valid
- Check bundle ID consistency

## Project Structure

```
TextEnhancer/
├── build-and-install.sh      # Primary build script
├── quick-dev.sh              # Quick development builds
├── TextEnhancer/
│   ├── main.swift            # App entry point & version
│   ├── MenuBarManager.swift  # Menu bar interface
│   ├── TextProcessor.swift   # Core text processing
│   ├── SettingsView.swift    # Settings UI
│   └── Info.plist           # Bundle configuration
├── docs/
│   └── ACCESSIBILITY_PERMISSIONS_GUIDE.md  # Detailed permission troubleshooting
└── README.md                 # This file
```

## License

Copyright © 2024 TextEnhancer. All rights reserved.

---

**Remember**: This app is useless without accessibility permissions. Always build using the provided scripts to ensure proper installation and permissions.