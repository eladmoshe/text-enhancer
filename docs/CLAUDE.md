# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TextEnhancer is a native macOS application that captures selected text, enhances it using Claude AI, and replaces the original text via keyboard shortcuts. It's currently in Phase 1 MVP with plans for Phase 2 multi-shortcut support.

## Best Practices

- Markdown files that document the app structure and behavior should be in the docs folder
- **Use bundled versions (--bundle or --bundle-signed) as much as possible** for persistent permissions
- **Use non-bundled version (--run) only for active development** when you need immediate code changes

## Build Commands

### Primary Build Commands

**Production (Bundled - Use for final testing and release):**
```bash
./build.sh --bundle-signed   # Signed bundle (persistent permissions) - RECOMMENDED
./build.sh --bundle          # Unsigned bundle (permissions reset on rebuild)
```

**Development (Non-bundled - Use for active development):**
```bash
./build.sh --run             # Debug binary (no bundle, permissions reset every time)
```

**🎯 Key Rule: Use bundled versions (--bundle or --bundle-signed) as much as possible for persistent permissions!**

**🔍 Visual Indicators:**
- **🔧 Wrench icon**: Development (non-bundled) version without permissions
- **⚠️ Triangle icon**: Production (bundled) version without permissions  
- **✨ Stars icon**: Either version with permissions granted

### Testing
```bash
# Run tests with coverage (requires full Xcode)
swift test --enable-code-coverage

# Alternative testing with build script
./build.sh --test

# Alternative make target
make test
```

### Linting and Formatting
```bash
# Format Swift code
make format  # Uses swift-format

# Lint Swift code
make lint    # Uses swiftlint
```

### Development Shortcuts
```bash
make run           # Build and run debug (stops existing instances)
make run-bundle    # Create and run as app bundle (stops existing instances)
make stop          # Stop any running TextEnhancer instances
make clean         # Clean build artifacts
make deps          # Resolve dependencies
make help          # Show all make targets
```

### Debugging and Development Notes

**CRITICAL: Use the right version for the right purpose**
- **Development (Non-bundled)**: Use `./build.sh --run` for immediate code changes - picks up changes instantly, but permissions reset every time
- **Production (Bundled)**: Use `./build.sh --bundle` or `./build.sh --bundle-signed` for testing with persistent permissions

```bash
# Development workflow (for active coding)
./build.sh --run              # Debug binary (no bundle, permissions reset every time)

# Production workflow (for testing with permissions)
./build.sh --bundle           # Unsigned bundle (permissions reset on rebuild)
./build.sh --bundle-signed    # Signed bundle (persistent permissions)
```

**Debug Output:**
- Debug binary: Outputs NSLog messages to console/terminal
- App bundle: Outputs to Console.app (search for "TextEnhancer")
- Use NSLog() instead of print() for release builds

### Critical Development Issues

**IMPORTANT: App Installation and Versioning**

The app can have multiple installations that cause conflicts:
1. **Debug binary:** `.build/debug/TextEnhancer` (no permissions, development only)
2. **Local bundle:** `./TextEnhancer.app` (created by build script)
3. **User Applications:** `~/Applications/TextEnhancer.app` (primary installation)
4. **System Applications:** `/Applications/TextEnhancer.app` (potential old version)

**To prevent version conflicts:**
```bash
# Before each development session
find /Applications ~/Applications -name "TextEnhancer.app" -exec rm -rf {} \; 2>/dev/null

# Always build fresh
./build.sh --bundle
cp -R TextEnhancer.app ~/Applications/
```

**Restart Mechanism:**
- App restart uses `Bundle.main.bundlePath` to relaunch
- If multiple versions exist, macOS may launch the wrong one
- Always ensure only one TextEnhancer.app exists in Applications directories

## Architecture

### Core Components Structure
- **main.swift** - App entry point with dependency injection setup
- **MenuBarManager.swift** - Menu bar UI, status icons, and notification handling
- **ShortcutManager.swift** - Global keyboard shortcut registration (Carbon framework)
- **TextProcessor.swift** - Text capture and replacement via Accessibility APIs
- **ClaudeService.swift** - Claude API integration with timeout and error handling
- **ConfigurationManager.swift** - Settings persistence and Keychain API key storage

### Key Design Patterns
- **Dependency Injection**: All services injected through main.swift AppDelegate
- **Observer Pattern**: NotificationCenter for processing state changes
- **Single Instance Enforcement**: Application-level and build-script-level instance checking
- **App Bundle Distribution**: Uses custom bundle creation for proper macOS integration
- **Accessibility APIs**: AX* functions for text capture/replacement across all apps

### Frameworks Used
- **SwiftUI** for settings interface
- **AppKit** for menu bar integration
- **Carbon framework** for global keyboard shortcuts
- **Accessibility APIs** for universal text manipulation
- **Keychain Services** for secure API key storage

## Testing Architecture

The project uses XCTest with mock objects for API dependencies:
- **MockURLProtocol** for HTTP request mocking
- **TemporaryDirectory** helper for filesystem testing
- **SimpleTestRunner.swift** alternative for Command Line Tools only environments

## Configuration

### API Keys
API keys are stored securely in macOS Keychain via ConfigurationManager. Never commit API keys to the repository.

### App Configuration
Runtime config stored at: `~/Library/Application Support/TextEnhancer/config.json`

### Default Settings
- Model: claude-3-haiku-20240307
- Max tokens: 1000
- Timeout: 30 seconds
- Shortcut: ⌃⌥1 (Control+Option+1)

## Accessibility Requirements

The app requires accessibility permissions to function. Always test with app bundle (`make run-bundle`) rather than raw executable to ensure proper permission dialog identification.

## Single Instance Management

The application enforces single instance execution at multiple levels:
- **Application Level**: Uses NSWorkspace to detect existing instances and activates them instead of launching duplicates
- **Build Scripts**: All run commands (`./build.sh --run`, `./build.sh --bundle`, `make run*`) automatically stop existing instances before launching
- **Installation**: `./install-startup.sh` kills running instances before building and installing the latest version

This ensures that when you build and run a new version, you're always using the latest code without conflicts.

## Phase 2 Planning

Upcoming features include:
- Multiple keyboard shortcuts (up to 5)
- Custom prompts per shortcut
- OpenAI API support
- Enhanced error handling and visual indicators