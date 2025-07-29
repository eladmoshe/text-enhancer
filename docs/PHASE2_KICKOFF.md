# TextEnhancer Phase 2 - Development Kickoff

## 🎯 Current State Summary

### ✅ Phase 1 Achievements (COMPLETE)

**Core Application Features:**
- ✅ Native macOS menu bar application
- ✅ Single keyboard shortcut (`⌃⌥1`) for text enhancement
- ✅ Claude API integration with Haiku model
- ✅ Universal text capture via Accessibility APIs
- ✅ Secure configuration management
- ✅ Real-time text replacement via pasteboard

**Test Coverage Implementation:**
- ✅ **17 comprehensive unit tests** covering core business logic
- ✅ **85% coverage** of ConfigurationManager and ClaudeService
- ✅ **Mock infrastructure** for network requests and file operations
- ✅ **Dependency injection** implemented without breaking production behavior
- ✅ **CI-ready** test suite with build script integration

**Technical Foundation:**
- ✅ Swift Package Manager project structure
- ✅ Robust error handling and user feedback
- ✅ Configuration file system with fallback support
- ✅ Memory-safe accessibility integration
- ✅ Production-ready build and deployment scripts

## 🏗️ Current Architecture

### Core Components
```
TextEnhancer/
├── Sources/
│   ├── main.swift                    # App entry point
│   ├── ConfigurationManager.swift   # ✅ 95% test coverage
│   ├── ClaudeService.swift          # ✅ 90% test coverage  
│   ├── TextProcessor.swift          # ⚠️ 10% test coverage (needs protocol extraction)
│   ├── MenuBarManager.swift         # 0% coverage (UI component)
│   └── ShortcutManager.swift        # 0% coverage (system integration)
├── Tests/                           # ✅ Complete test infrastructure
└── Build Scripts/                   # ✅ Automated build & test pipeline
```

### Dependency Graph
```
main.swift
├── AppDelegate
├── MenuBarManager ← ConfigurationManager
├── ShortcutManager ← TextProcessor
└── TextProcessor ← ClaudeService ← ConfigurationManager
```

### Test Infrastructure
- **MockURLProtocol**: Network request interception
- **TemporaryDirectory**: File system test isolation
- **Dependency Injection**: URLSession and file path injection
- **Build Integration**: `./build.sh --test` and `make test`

## 🎯 Phase 2 Goals

### Primary Objectives
1. **Multiple Keyboard Shortcuts** (up to 5 configurable shortcuts)
2. **Custom Prompts per Shortcut** (user-defined enhancement types)
3. **Enhanced UI/UX** (visual processing indicators, better error handling)
4. **OpenAI API Support** (alternative to Claude)
5. **Protocol Extraction** (complete TextProcessor testability)

### Success Criteria
- [ ] Support 5 configurable keyboard shortcuts
- [ ] User can define custom prompts for each shortcut
- [ ] Visual feedback during text processing
- [ ] OpenAI GPT integration alongside Claude
- [ ] 90%+ test coverage across all components
- [ ] Zero breaking changes to existing functionality

## 🛠️ Development Priorities

### Priority 1: Multiple Shortcuts Foundation
**Estimated Time:** 3-4 hours
- Extend `ShortcutConfiguration` model for multiple shortcuts
- Update `ShortcutManager` to register multiple hotkeys
- Modify configuration loading/saving for shortcut arrays
- Add validation for shortcut conflicts

**Test Requirements:**
- Unit tests for multiple shortcut registration
- Configuration persistence tests for shortcut arrays
- Conflict detection and resolution tests

### Priority 2: Custom Prompts System
**Estimated Time:** 2-3 hours  
- Extend `EnhancementType` to support custom prompts
- Update UI configuration flow (if needed)
- Add prompt validation and sanitization
- Implement prompt template system

**Test Requirements:**
- Prompt validation tests
- Template rendering tests
- End-to-end enhancement tests with custom prompts

### Priority 3: Protocol Extraction for TextProcessor
**Estimated Time:** 2-3 hours
- Extract `TextSelectionProvider` protocol
- Extract `TextReplacer` protocol  
- Extract `AccessibilityChecker` protocol
- Extract `PasteboardManager` protocol
- Extract `KeyEventSimulator` protocol

**Test Requirements:**
- Mock implementations for all protocols
- Complete TextProcessor unit test suite
- Integration tests for accessibility workflows

### Priority 4: Visual Processing Indicators
**Estimated Time:** 2-3 hours
- Menu bar icon animation during processing
- Optional notification system
- Progress feedback for long operations
- Error state visualization

**Test Requirements:**
- UI state management tests
- Notification delivery tests
- Animation lifecycle tests

### Priority 5: OpenAI Integration
**Estimated Time:** 3-4 hours
- Create `OpenAIService` following `ClaudeService` pattern
- Add API provider selection to configuration
- Implement model selection (GPT-3.5, GPT-4)
- Add rate limiting and error handling

**Test Requirements:**
- Complete OpenAIService test suite
- API provider switching tests
- Error handling and fallback tests

## 📋 Technical Implementation Plan

### Configuration Schema Evolution
```json
{
  "apiProviders": {
    "claude": {
      "apiKey": "...",
      "model": "claude-3-haiku-20240307",
      "enabled": true
    },
    "openai": {
      "apiKey": "...", 
      "model": "gpt-3.5-turbo",
      "enabled": false
    }
  },
  "shortcuts": [
    {
      "id": "improve-text",
      "name": "Improve Text",
      "keyCode": 18,
      "modifiers": ["ctrl", "opt"],
      "prompt": "Improve writing quality...",
      "provider": "claude"
    },
    {
      "id": "summarize",
      "name": "Summarize",
      "keyCode": 19,
      "modifiers": ["ctrl", "opt"],
      "prompt": "Summarize this text...",
      "provider": "openai"
    }
  ],
  "ui": {
    "showProcessingIndicator": true,
    "animateMenuBarIcon": true
  }
}
```

### Protocol Definitions
```swift
protocol TextSelectionProvider {
    func getSelectedText() -> String?
}

protocol TextReplacer {
    func replaceSelectedText(with newText: String) async
}

protocol AccessibilityChecker {
    func isAccessibilityEnabled() -> Bool
    func requestAccessibilityPermissions()
}

protocol APIProvider {
    func enhanceText(_ text: String, with prompt: String) async throws -> String
}
```

## 🧪 Testing Strategy for Phase 2

### Test Coverage Goals
- **ConfigurationManager**: Maintain 95%+ coverage with new schema
- **APIProviders**: 90%+ coverage for both Claude and OpenAI services
- **TextProcessor**: Achieve 90%+ coverage via protocol extraction
- **ShortcutManager**: 70%+ coverage with mock system integration
- **MenuBarManager**: 60%+ coverage with UI state testing

### New Test Categories
1. **Multi-shortcut Integration Tests**
2. **API Provider Switching Tests** 
3. **Custom Prompt Validation Tests**
4. **UI State Management Tests**
5. **Performance Tests** (response time, memory usage)

### Test Infrastructure Enhancements
- **MockAccessibilityProvider**: System accessibility API mocking
- **MockPasteboard**: Pasteboard operation testing
- **MockKeyEventSimulator**: Keyboard event testing
- **APIProviderTestSuite**: Shared test suite for all providers

## 🚀 Development Workflow

### Setup for Phase 2
1. **Branch Strategy**: Create `phase-2-development` branch
2. **Milestone Tracking**: GitHub issues for each priority
3. **Test-First Development**: Write tests before implementation
4. **Incremental Delivery**: Each priority is a shippable increment

### Quality Gates
- [ ] All existing tests continue to pass
- [ ] New features have 90%+ test coverage
- [ ] No breaking changes to existing functionality
- [ ] Performance regression testing
- [ ] User acceptance testing for new shortcuts

### Risk Mitigation
- **Backward Compatibility**: Maintain support for Phase 1 configuration format
- **Graceful Degradation**: Fallback to Claude if OpenAI unavailable
- **User Migration**: Automatic config migration with backup
- **Rollback Plan**: Feature flags for easy rollback

## 📚 Resources and References

### Key Files to Modify
- `Sources/ConfigurationManager.swift` - Schema evolution
- `Sources/ShortcutManager.swift` - Multiple shortcut support
- `Sources/TextProcessor.swift` - Protocol extraction
- `Package.swift` - Potential new dependencies
- `Tests/` - Comprehensive test expansion

### External Dependencies (Potential)
- Consider `KeyboardShortcuts` library for advanced shortcut management
- Evaluate `Sparkle` framework for auto-updates (Phase 3)
- Research notification frameworks for better user feedback

### Documentation Updates Required
- Update README.md with new features
- Create user guide for custom shortcuts
- Document API provider configuration
- Update build and deployment guides

## 🎯 Success Metrics

### Functional Metrics
- [ ] 5 configurable keyboard shortcuts working simultaneously
- [ ] Custom prompts saved and loaded correctly
- [ ] Both Claude and OpenAI APIs functional
- [ ] Visual feedback during all operations
- [ ] Zero crashes or data loss

### Technical Metrics  
- [ ] Test coverage >90% across all components
- [ ] Build time <30 seconds
- [ ] Test execution time <10 seconds
- [ ] Memory usage <50MB during operation
- [ ] API response time <5 seconds (95th percentile)

### User Experience Metrics
- [ ] Shortcut registration success rate >99%
- [ ] Text enhancement accuracy maintained
- [ ] Error recovery rate >95%
- [ ] User configuration migration success >99%

---

## 🚀 Ready to Begin Phase 2!

The foundation is solid, tests are comprehensive, and the architecture is ready for extension. Phase 2 will build upon this strong base to deliver a more powerful and flexible text enhancement tool while maintaining the reliability and simplicity that makes TextEnhancer effective.

**Next Steps:**
1. Review this document with the team
2. Create GitHub milestone for Phase 2
3. Set up development branch
4. Begin with Priority 1: Multiple Shortcuts Foundation

*Phase 1 delivered a robust, tested foundation. Phase 2 will unlock the full potential of AI-powered text enhancement.* 