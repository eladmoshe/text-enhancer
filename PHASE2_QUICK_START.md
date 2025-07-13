# Phase 2 Quick Start Guide

## 🚀 Getting Started

### Prerequisites
- Full Xcode installed (required for XCTest)
- Swift 5.9+
- macOS 13+

### Setup Commands
```bash
# Clone and setup
git clone <repo-url>
cd text-llm-modify

# Verify Phase 1 foundation
swift build                    # Should build successfully
swift test --enable-code-coverage  # All 17 tests should pass
./build.sh --test             # Alternative test command
make test                      # Make target

# Switch to Phase 2 branch (when created)
git checkout -b phase-2-development
```

## 📊 Current Test Status
```
✅ ConfigurationManagerTests: 7/7 tests passing
✅ ClaudeServiceTests: 9/9 tests passing  
✅ TextProcessorTests: 1/1 tests passing
✅ Total: 17/17 tests passing
✅ Core business logic coverage: ~85%
```

## 🏗️ Architecture Overview

### Key Components (Phase 1)
- **ConfigurationManager**: ✅ Fully tested (95% coverage)
- **ClaudeService**: ✅ Fully tested (90% coverage)
- **TextProcessor**: ⚠️ Needs protocol extraction (10% coverage)
- **MenuBarManager**: 📋 UI component (0% coverage)
- **ShortcutManager**: 📋 System integration (0% coverage)

### Test Infrastructure Available
- **MockURLProtocol**: Network request mocking
- **TemporaryDirectory**: File system isolation
- **Dependency Injection**: URLSession and file paths
- **Build Integration**: Automated test execution

## 🎯 Phase 2 Development Priorities

### 1. Multiple Shortcuts (Priority 1)
**Files to modify:**
- `Sources/ShortcutManager.swift`
- `Sources/ConfigurationManager.swift`
- `Tests/TextEnhancerTests/ShortcutManagerTests.swift` (new)

**Key changes:**
- Support array of shortcuts instead of single shortcut
- Hotkey conflict detection and resolution
- Dynamic shortcut registration/unregistration

### 2. Custom Prompts (Priority 2)
**Files to modify:**
- `Sources/ConfigurationManager.swift`
- `Sources/TextProcessor.swift`
- Configuration schema evolution

**Key changes:**
- User-defined prompts per shortcut
- Prompt validation and sanitization
- Template system for dynamic prompts

### 3. Protocol Extraction (Priority 3)
**Files to modify:**
- `Sources/TextProcessor.swift`
- `Tests/TextEnhancerTests/TextProcessorTests.swift`
- New protocol files

**Key changes:**
- Extract system dependencies into protocols
- Create mock implementations for testing
- Achieve 90%+ TextProcessor test coverage

## 🧪 Testing Guidelines

### Test-First Development
```bash
# Always run tests before starting
swift test --enable-code-coverage

# Write tests first, then implementation
# Follow existing test patterns in Tests/TextEnhancerTests/

# Verify no regressions
swift test --enable-code-coverage  # Should still be 17/17 passing
```

### Test Patterns to Follow
```swift
// Configuration testing pattern
func test_newFeature_expectedBehavior() throws {
    // Given: Setup test conditions
    let tempDir = try! TemporaryDirectory()
    
    // When: Execute the functionality
    let result = systemUnderTest.doSomething()
    
    // Then: Verify expectations
    XCTAssertEqual(result, expectedValue)
    
    tempDir.cleanup()
}
```

### Mock Infrastructure Usage
```swift
// Network mocking pattern (see ClaudeServiceTests.swift)
MockURLProtocol.requestHandler = { request in
    // Verify request properties
    XCTAssertEqual(request.url?.absoluteString, expectedURL)
    
    // Return mock response
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, ...)
    return (response, mockData)
}
```

## 📝 Configuration Schema Evolution

### Current Schema (Phase 1)
```json
{
  "claudeApiKey": "...",
  "shortcuts": [{ "id": "improve-text", ... }],
  "maxTokens": 1000,
  "timeout": 30.0
}
```

### Proposed Schema (Phase 2)
```json
{
  "apiProviders": {
    "claude": { "apiKey": "...", "enabled": true },
    "openai": { "apiKey": "...", "enabled": false }
  },
  "shortcuts": [
    { "id": "improve", "prompt": "...", "provider": "claude" },
    { "id": "summarize", "prompt": "...", "provider": "openai" }
  ]
}
```

## 🛠️ Development Commands

### Build & Test
```bash
swift build                    # Build application
swift test --enable-code-coverage  # Run tests with coverage
./build.sh --test             # Build script with tests
make test                      # Make target for tests
```

### Coverage Analysis
```bash
# After running tests with coverage
xcrun llvm-cov show .build/debug/TextEnhancerPackageTests.xctest/Contents/MacOS/TextEnhancerPackageTests -instr-profile .build/debug/codecov/default.profdata
```

### App Testing
```bash
./build.sh --bundle           # Create and run app bundle
./build.sh --run              # Run debug executable
```

## 🚨 Important Notes

### Backward Compatibility
- **MUST** maintain Phase 1 configuration format support
- **MUST** not break existing keyboard shortcut (`⌃⌥1`)
- **MUST** preserve all existing functionality

### Quality Gates
- All existing tests must continue passing
- New features require 90%+ test coverage
- No performance regressions
- No memory leaks or crashes

### Dependencies
- Avoid external dependencies unless absolutely necessary
- Use native macOS frameworks when possible
- Document any new dependencies thoroughly

## 📚 Reference Files

### Key Implementation Files
- `Sources/ConfigurationManager.swift` - Configuration handling
- `Sources/ClaudeService.swift` - API service pattern
- `Sources/TextProcessor.swift` - Core text processing logic
- `Sources/ShortcutManager.swift` - Keyboard shortcut management

### Key Test Files
- `Tests/TextEnhancerTests/ConfigurationManagerTests.swift` - Configuration testing patterns
- `Tests/TextEnhancerTests/ClaudeServiceTests.swift` - API service testing patterns
- `Tests/TextEnhancerTests/TestHelpers/` - Reusable test infrastructure

### Documentation
- `TESTING_SUMMARY.md` - Complete testing overview
- `README.md` - User-facing documentation
- `PHASE2_KICKOFF.md` - Detailed Phase 2 plan

## 🎯 Success Criteria

### Must Achieve
- [ ] 5 configurable keyboard shortcuts
- [ ] Custom prompts per shortcut
- [ ] 90%+ test coverage on new components
- [ ] Zero breaking changes to Phase 1 functionality
- [ ] Performance maintained or improved

### Nice to Have
- [ ] OpenAI API integration
- [ ] Visual processing indicators
- [ ] Advanced prompt templating
- [ ] Shortcut management UI

---

## 🚀 Ready to Code!

Phase 1 provides a solid, tested foundation. Follow the test-first approach, maintain backward compatibility, and build incrementally. The architecture is ready for extension!

**First Task:** Review `PHASE2_KICKOFF.md` for detailed planning, then start with Priority 1: Multiple Shortcuts Foundation. 