# Contributing to TextEnhancer

Thank you for your interest in contributing to TextEnhancer! This guide will help you get started with contributing to this macOS text enhancement application.

## 🚀 Quick Start

1. **Fork the repository**
2. **Clone your fork**:
   ```bash
   git clone git@github.com:yourusername/text-enhancer.git
   cd text-enhancer
   ```
3. **Build and test**:
   ```bash
   ./build.sh --help
   swift test
   ```

## 📋 Table of Contents

- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Building and Testing](#building-and-testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)
- [Development Workflow](#development-workflow)

## 🛠️ Development Setup

### Prerequisites

- **macOS 13+** (Ventura or later)
- **Xcode 15+** with Swift 5.9+
- **Git**

### Optional Tools

- **SwiftLint** for code linting:
  ```bash
  brew install swiftlint
  ```
- **SwiftFormat** for code formatting:
  ```bash
  brew install swiftformat
  ```

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone git@github.com:eladmoshe/text-enhancer.git
   cd text-enhancer
   ```

2. **Build the project**:
   ```bash
   # For development (fast iteration)
   ./build.sh --run
   
   # For production (signed bundle)
   ./build.sh --bundle-signed
   ```

3. **Run tests**:
   ```bash
   swift test
   ```

4. **Set up API keys** (optional for testing):
   ```bash
   cp config.example.json config.json
   # Edit config.json with your API keys
   ```

## 📁 Project Structure

```
text-enhancer/
├── Sources/                    # Main source code
│   ├── main.swift             # Application entry point
│   ├── ConfigurationManager.swift
│   ├── TextProcessor.swift    # Core text processing logic
│   ├── ClaudeService.swift    # Claude API integration
│   ├── OpenAIService.swift    # OpenAI API integration
│   ├── MenuBarManager.swift   # Menu bar interface
│   ├── ShortcutManager.swift  # Keyboard shortcuts
│   └── ScreenCaptureService.swift
├── Tests/                     # Test suite
│   └── TextEnhancerTests/
├── docs/                      # Documentation
├── .github/                   # GitHub Actions workflows
├── build.sh                   # Build script
├── Makefile                   # Build targets
└── Package.swift              # Swift package configuration
```

## 🔨 Building and Testing

### Build Commands

```bash
# Development build (fast iteration, permissions reset on rebuild)
./build.sh --run

# Production build (signed bundle, persistent permissions)
./build.sh --bundle-signed

# Check build status
./build.sh --status

# Get help
./build.sh --help
```

### Testing

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter TextProcessorTests

# Run custom test runner
swift run TextEnhancer test
```

### Code Quality

```bash
# Lint code
swiftlint lint

# Auto-fix linting issues
swiftlint --fix

# Format code
swiftformat Sources/ Tests/

# Check formatting
swiftformat --lint Sources/ Tests/
```

## 🎨 Code Style

We follow Swift's official style guidelines with some project-specific conventions:

### SwiftLint Configuration

The project uses SwiftLint with a custom configuration (`.swiftlint.yml`). Key rules:

- **Line length**: 120 characters (warning), 150 (error)
- **Function length**: 60 lines (warning), 100 (error)
- **File length**: 500 lines (warning), 1200 (error)
- **No force unwrapping** in production code
- **Prefer guard statements** for early returns

### SwiftFormat Configuration

Code formatting is handled by SwiftFormat (`.swiftformat`):

- **Indentation**: 4 spaces
- **Trailing commas**: Required
- **Import organization**: Testable imports at bottom
- **Self keywords**: Removed where possible

### Naming Conventions

- **Classes/Structs/Protocols**: PascalCase (`TextProcessor`)
- **Functions/Variables**: camelCase (`processText`)
- **Constants**: camelCase (`maxTokens`)
- **Files**: PascalCase matching main type (`TextProcessor.swift`)

### Documentation

- **Public APIs** must have documentation comments (`///`)
- **Complex functions** should have inline comments
- **Use clear, descriptive names** for variables and functions

## 📤 Submitting Changes

### Branch Naming

- **Feature branches**: `feature/short-description`
- **Bug fixes**: `fix/short-description`
- **Documentation**: `docs/short-description`
- **Refactoring**: `refactor/short-description`

### Commit Messages

Use conventional commit format:

```
type(scope): brief description

Longer description if needed

- Specific change 1
- Specific change 2

Fixes #123
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Scopes**: `api`, `ui`, `shortcuts`, `build`, `config`, `tests`

### Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Make your changes** following the code style guidelines

3. **Add tests** for new functionality

4. **Update documentation** if needed

5. **Run the full test suite**:
   ```bash
   swift test
   swiftlint lint
   swiftformat --lint Sources/ Tests/
   ```

6. **Build and test the app**:
   ```bash
   ./build.sh --bundle-signed
   # Test manually with keyboard shortcuts
   ```

7. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat(api): add new text processing method"
   ```

8. **Push and create PR**:
   ```bash
   git push origin feature/my-new-feature
   ```

9. **Fill out the PR template** with detailed information

### PR Requirements

- [ ] **Tests pass** (`swift test`)
- [ ] **Code is linted** (`swiftlint lint`)
- [ ] **Code is formatted** (`swiftformat --lint`)
- [ ] **App builds** (`./build.sh --bundle-signed`)
- [ ] **Manual testing** completed (if applicable)
- [ ] **Documentation** updated (if needed)
- [ ] **PR template** filled out completely

## 🐛 Reporting Issues

### Before Reporting

1. **Search existing issues** to avoid duplicates
2. **Try the latest version** from the main branch
3. **Check the documentation** for known limitations

### Bug Reports

Use the bug report template and include:

- **macOS version**
- **TextEnhancer version**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Logs/error messages**
- **Screenshots** (if applicable)

### Feature Requests

Use the feature request template and include:

- **Problem statement**
- **Proposed solution**
- **Use cases**
- **Alternative solutions considered**

## 🔄 Development Workflow

### Setting Up for Development

1. **Enable accessibility permissions**:
   - System Preferences → Security & Privacy → Accessibility
   - Add TextEnhancer to the list

2. **Enable screen recording permissions** (for screenshot features):
   - System Preferences → Security & Privacy → Screen Recording
   - Add TextEnhancer to the list

3. **Configure API keys**:
   ```bash
   cp config.example.json config.json
   # Edit config.json with your API keys
   ```

### Testing Workflow

1. **Unit tests**: `swift test`
2. **Manual testing**: Use keyboard shortcuts with the built app
3. **Integration testing**: Test with real API calls
4. **Permission testing**: Test accessibility and screen recording

### Debugging

1. **Console logs**: Check Console.app for runtime logs
2. **Debug builds**: Use `./build.sh --run` for debug output
3. **Print debugging**: Add print statements (remove before committing)
4. **Xcode debugging**: Open Package.swift in Xcode for full debugging

### Common Development Tasks

#### Adding a New Keyboard Shortcut

1. **Update `ShortcutConfiguration`** in ConfigurationManager.swift
2. **Add the shortcut** to default configuration
3. **Update menu items** in MenuBarManager.swift
4. **Add processing logic** in TextProcessor.swift
5. **Write tests** for the new functionality

#### Adding a New API Provider

1. **Create service class** (e.g., `NewAPIService.swift`)
2. **Implement `TextEnhancementService` protocol**
3. **Add configuration options**
4. **Update `TextProcessor`** to use the new service
5. **Add comprehensive tests**

#### Modifying Text Processing

1. **Update `TextProcessor.swift`**
2. **Ensure error handling** is robust
3. **Add logging** for debugging
4. **Update tests** to cover new behavior
5. **Test with various text inputs**

## 🤝 Community Guidelines

- **Be respectful** and inclusive
- **Help others** learn and contribute
- **Provide constructive feedback**
- **Ask questions** if you're unsure
- **Share knowledge** and best practices

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and community interaction
- **Code Review**: Learn from PR feedback
- **Documentation**: Check the docs/ directory

## 🎯 Good First Issues

Look for issues labeled:
- `good first issue`: Perfect for newcomers
- `help wanted`: Community contributions welcome
- `documentation`: Help improve docs
- `tests`: Add test coverage

## 📚 Additional Resources

- [Swift Style Guide](https://google.github.io/swift/)
- [macOS App Development](https://developer.apple.com/macos/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

---

Thank you for contributing to TextEnhancer! Your efforts help make this tool better for everyone. 🚀 