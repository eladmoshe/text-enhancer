# TextEnhancer Startup Setup Guide

This guide explains how to set up TextEnhancer to run automatically when your Mac starts up.

## 🚀 Quick Setup (Recommended)

The easiest way to set up TextEnhancer for startup is using the provided script:

```bash
./install-startup.sh
```

This script will:
1. Build the app bundle
2. Install it to `/Applications/TextEnhancer.app`
3. Add it to your login items
4. Provide setup confirmation

## 🗑️ Uninstall from Startup

To remove TextEnhancer from startup:

```bash
./uninstall-startup.sh
```

## 📋 Manual Setup Options

### Option 1: System Settings (macOS Ventura 13.0+)

1. Build and install the app:
   ```bash
   make bundle
   cp -R TextEnhancer.app /Applications/
   ```

2. Open **System Settings** > **General** > **Login Items**
3. Click the **+** button under "Open at Login"
4. Navigate to `/Applications/TextEnhancer.app` and select it
5. The app will now start automatically on login

### Option 2: System Preferences (macOS Monterey 12.0 and earlier)

1. Build and install the app:
   ```bash
   make bundle
   cp -R TextEnhancer.app /Applications/
   ```

2. Open **System Preferences** > **Users & Groups**
3. Select your user account
4. Click the **Login Items** tab
5. Click the **+** button
6. Navigate to `/Applications/TextEnhancer.app` and select it
7. The app will now start automatically on login

### Option 3: Using AppleScript

You can also use AppleScript to add the app to login items:

```applescript
tell application "System Events"
    set appPath to POSIX file "/Applications/TextEnhancer.app"
    make login item at end with properties {path:appPath, hidden:false, name:"TextEnhancer"}
end tell
```

Run this script with:
```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:POSIX file "/Applications/TextEnhancer.app", hidden:false, name:"TextEnhancer"}'
```

## 🔧 Troubleshooting

### App Not Starting
- Ensure the app is in `/Applications/TextEnhancer.app`
- Check that it's properly added to login items
- Verify accessibility permissions are granted

### Accessibility Permissions
TextEnhancer requires accessibility permissions to capture and modify selected text. When you first run the app, you'll see a prompt to grant these permissions:

1. Click "Open System Preferences" when prompted
2. In **Security & Privacy** > **Privacy** > **Accessibility**
3. Click the lock icon and enter your password
4. Check the box next to "TextEnhancer"

### Global Shortcuts Not Working
- Ensure accessibility permissions are granted
- Check that no other apps are using the same keyboard shortcuts
- Default shortcuts:
  - `Ctrl+Alt+I`: Improve Text
  - `Ctrl+Alt+U`: Summarize
  - `Ctrl+Alt+V`: Expand

### App Not in Menu Bar
- The app runs as a background app (menu bar app)
- Look for the TextEnhancer icon in your menu bar (top-right area)
- If not visible, the app might not be running or might need permissions

## 🛠️ Advanced Configuration

### Custom Build Location
If you want to install the app in a different location:

```bash
# Build the app bundle
make bundle

# Install to custom location
CUSTOM_PATH="/Users/$(whoami)/Applications/TextEnhancer.app"
cp -R TextEnhancer.app "$CUSTOM_PATH"

# Add to login items using the custom path
osascript -e "tell application \"System Events\" to make login item at end with properties {path:POSIX file \"$CUSTOM_PATH\", hidden:false, name:\"TextEnhancer\"}"
```

### Running in Development Mode
For development, you can run the app directly without installing:

```bash
# Run debug version
./build.sh --run

# Run as app bundle
./build.sh --bundle
```

## 📝 Configuration

The app reads its configuration from `config.json` in the same directory as the executable. Make sure your Claude API key is properly configured before running.

## 🔍 Verification

To verify the app is set up for startup:

1. **Check Login Items**: 
   - System Settings > General > Login Items
   - Look for "TextEnhancer" in the list

2. **Test Startup**:
   - Log out and log back in
   - The app should appear in your menu bar
   - Global shortcuts should work

3. **Check Running Process**:
   ```bash
   ps aux | grep TextEnhancer
   ```

## 🆘 Getting Help

If you encounter issues:

1. Check the app logs in Console.app
2. Ensure all permissions are granted
3. Try rebuilding the app bundle: `make clean && make bundle`
4. Restart your Mac to test the startup process

## 🔄 Updates

When updating TextEnhancer:

1. Run `./uninstall-startup.sh` to remove the old version
2. Pull the latest changes
3. Run `./install-startup.sh` to install the new version

This ensures you always have the latest version set up for startup. 