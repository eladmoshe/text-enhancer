# TextEnhancer - Phase 1 MVP

A native macOS application that captures selected text, enhances it using Claude AI, and replaces the original text via keyboard shortcuts.

## Features (Phase 1)

- **Single Keyboard Shortcut**: `⌃⌥1` (Control+Option+1) to improve selected text
- **Claude AI Integration**: Uses Anthropic's Claude API for text enhancement
- **Menu Bar App**: Runs in the background as a menu bar application
- **Secure API Key Storage**: API keys stored securely in macOS Keychain
- **Universal Text Capture**: Works with any macOS application that supports text selection

## Requirements

- macOS 14.0 (Sonoma) or later
- Claude API key from [Anthropic Console](https://console.anthropic.com/)
- Swift 5.9 or later (for development)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd text-llm-modify
   ```

2. Build and run the application:
   ```bash
   # Recommended: Signed app bundle (persistent accessibility permissions)
   ./build.sh --bundle-signed
   
   # Or unsigned app bundle (permissions reset on rebuild)
   ./build.sh --bundle
   
   # Or debug executable (permissions reset on rebuild)
   ./build.sh --run
   
   # Or build manually
   swift build -c release
   make bundle
   open TextEnhancer.app
   ```

### First-Time Setup

1. **Grant Accessibility Permissions**: 
   - The app will prompt you to grant accessibility permissions
   - Go to System Settings > Privacy & Security > Accessibility
   - Add TextEnhancer to the list of allowed applications

2. **For Persistent Permissions** (Recommended):
   - By default, accessibility permissions reset after each rebuild
   - To make permissions persist across rebuilds, use code signing
   - See [Accessibility Permissions Setup Guide](docs/ACCESSIBILITY_PERMISSIONS.md) for detailed instructions
   - Quick setup: Create development certificate in Xcode, then use `./build.sh --bundle-signed`

3. **Set Up Claude API Key**:
   - Right-click the TextEnhancer icon in the menu bar
   - Select "Settings..."
   - Enter your Claude API key from https://console.anthropic.com/
   - Click "Save API Key"

## Usage

1. **Select text** in any macOS application (Notes, Safari, Mail, Slack, etc.)
2. **Press `⌃⌥1`** (Control+Option+1)
3. **Wait for processing** - the menu bar icon will show a spinning indicator
4. **Text is replaced** automatically with the enhanced version

### Default Prompt

The Phase 1 prompt is: *"Improve the writing quality and clarity of this text while maintaining its original meaning and tone."*

## Architecture

```
TextEnhancer/
├── main.swift              # App entry point and setup
├── MenuBarManager.swift    # Menu bar UI and status management
├── ShortcutManager.swift   # Global keyboard shortcut handling
├── TextProcessor.swift     # Text capture and replacement logic
├── ClaudeService.swift     # Claude API integration
├── ConfigurationManager.swift # Settings and keychain management
└── SettingsView.swift      # SwiftUI settings interface
```

## Privacy & Security

- **API keys** are stored securely in macOS Keychain
- **No text logging** - selected text is sent directly to Claude API and not stored locally
- **Accessibility permissions** are required only for text capture and replacement
- **Network requests** are made only to Anthropic's API (api.anthropic.com)

## Configuration

The app creates a configuration directory at:
```
~/Library/Application Support/TextEnhancer/
└── config.json
```

## Troubleshooting

### Common Issues

1. **"No text selected" error**:
   - Make sure text is actually selected (highlighted) before pressing the shortcut
   - Some apps may not support text selection via accessibility APIs

2. **API key errors**:
   - Verify your Claude API key is valid
   - Check your Anthropic account has sufficient credits
   - Ensure internet connectivity

3. **Accessibility permissions showing wrong app name**:
   - **Problem**: Permission dialog shows "Cursor", "Warp", or terminal name instead of "TextEnhancer"
   - **Solution**: Use the app bundle approach: `./build.sh --bundle` or `make run-bundle`
   - **Why**: Running raw executables from terminal inherits the parent process identity

4. **Accessibility permissions**:
   - Go to System Settings > Privacy & Security > Accessibility
   - Remove and re-add TextEnhancer if permissions seem corrupted
   - Use app bundle for proper identification

5. **Keyboard shortcut not working**:
   - Check if another app is using the same shortcut
   - Restart the app after permission changes

### Debug Mode

To see detailed logs, run from terminal:
```bash
.build/release/TextEnhancer
```

## Development

### Project Structure

- **Swift Package Manager** for dependency management
- **SwiftUI** for settings interface
- **AppKit** for menu bar integration
- **Carbon framework** for global keyboard shortcuts
- **Accessibility APIs** for text capture/replacement

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests (when available)
swift test
```

### Quick Commands

```bash
# Build and run (debug executable)
make run

# Build and run as app bundle (recommended)
make run-bundle

# Release build
make release

# Clean build
make clean

# Create app bundle
make bundle
```

### Developer Tools

#### Extract Default Configuration

Use the `extract-shortcuts.sh` script to capture your current shortcuts and set them as defaults for clean installations:

```bash
# Extract current shortcuts and create default configuration
./extract-shortcuts.sh

# Preview what would be extracted without saving
./extract-shortcuts.sh --preview

# Show help
./extract-shortcuts.sh --help
```

This script:
- Reads your current configuration from `~/Library/Application Support/TextEnhancer/config.json`
- Scrubs sensitive data (API keys)
- Creates `config.default.json` in the project root
- The default configuration is automatically bundled with the app for clean installations

### Dependencies

- **No external dependencies** - Phase 1 uses only native macOS frameworks

## Testing

The project includes comprehensive unit tests for the core components:

- **ConfigurationManager**: Tests configuration loading, saving, and fallback behavior
- **ClaudeService**: Tests API request creation, error handling, and response parsing
- **TextProcessor**: Basic initialization tests (more comprehensive tests require protocol extraction)

**Note**: Due to XCTest framework limitations with Swift Package Manager and Command Line Tools only (without full Xcode), the standard `swift test` command may not work. We provide alternative testing approaches:

#### Option 1: Install Full Xcode (Recommended)
```bash
# Install Xcode from Mac App Store, then:
swift test --enable-code-coverage
```

#### Option 2: Use Simple Test Runner
```bash
# Run basic tests without XCTest dependency (requires module access setup)
# Note: This demonstrates test logic but needs proper module integration
swift Tests/SimpleTestRunner.swift
```

#### Option 3: Use Build Script
```bash
./build.sh --test  # Attempts to run tests with coverage
make test          # Alternative make target
```

## Roadmap

### Phase 2 (Coming Soon)
- Multiple keyboard shortcuts (up to 5)
- Custom prompts per shortcut
- OpenAI API support
- Visual processing indicators
- Enhanced error handling

### Phase 3 (Future)
- Prompt templates library
- Processing history
- Auto-updates
- Advanced configuration UI

## License

This project is for personal use. See license file for details.

## Support

For issues and feature requests, please create an issue in the repository.

## API Usage

The app uses Claude 3 Haiku model with the following default settings:
- **Model**: claude-3-haiku-20240307
- **Max tokens**: 1000
- **Timeout**: 30 seconds

Average API cost per text enhancement: ~$0.001-0.01 depending on text length. 