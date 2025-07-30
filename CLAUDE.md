- Markdown docs should go to the docs/ folder
- After changes, always run the new version of the app so the user can tests it. Validate that the app is running using ps command
- Change the buildNumber on every build when we need to check something in the logs. When you check logs at /Users/elad.moshe/Library/Logs/TextEnhancer/debug.log verify the version match.

## CRITICAL BUILD PROCESS

**This app is USELESS without accessibility permissions. NEVER run builds from DerivedData.**

### Primary Build Method
Always use: `./build-and-install.sh`
- Ensures proper installation to /Applications/
- Verifies bundle identifier consistency  
- Provides clear permission setup instructions
- Tracks build numbers properly

### Quick Development
For rapid iteration: `./quick-dev.sh`
- Still installs to /Applications/ (required for permissions)
- Faster than full verification script

### Bundle Identifier Management
- Current: `com.lemonadeinc.textenhancer.v2`
- Must match in BOTH Info.plist AND project.pbxproj
- Version number prevents permission conflicts
- NEVER reuse bundle IDs that had permission issues

### Verification Steps After Any Build
1. Check app runs from /Applications/: `ps aux | grep "/Applications/TextEnhancer"`
2. Verify bundle ID: `codesign -dv --verbose=4 "/Applications/TextEnhancer.app" | grep Identifier`
3. Test accessibility: Click menu bar icon, enable permissions, test shortcuts
4. Check logs for correct version: `tail /Users/elad.moshe/Library/Logs/TextEnhancer/debug.log`

### If Permissions Break
1. Reset: `sudo tccutil reset Accessibility`
2. Rebuild: `./build-and-install.sh`
3. Follow permission setup in script output

### System Requirements
- this project only supports MacOS 15.5 or later