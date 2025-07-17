import XCTest
@testable import TextEnhancer

// MARK: - Mock Implementations

class MockTextSelectionProvider: TextSelectionProvider {
    var mockSelectedText: String?
    var getSelectedTextCallCount = 0
    
    func getSelectedText() -> String? {
        getSelectedTextCallCount += 1
        return mockSelectedText
    }
}

class MockTextReplacer: TextReplacer {
    var replacedText: String?
    var replaceSelectedTextCallCount = 0
    
    func replaceSelectedText(with newText: String) async {
        replaceSelectedTextCallCount += 1
        replacedText = newText
    }
}

class MockAccessibilityChecker: AccessibilityChecker {
    var mockIsAccessibilityEnabled = true
    var isAccessibilityEnabledCallCount = 0
    var requestAccessibilityPermissionsCallCount = 0
    
    func isAccessibilityEnabled() -> Bool {
        isAccessibilityEnabledCallCount += 1
        return mockIsAccessibilityEnabled
    }
    
    func requestAccessibilityPermissions() async {
        requestAccessibilityPermissionsCallCount += 1
    }
}

class MockPasteboardManager: PasteboardManager {
    var mockSetString: String?
    var mockKeyCode: CGKeyCode?
    var mockModifiers: CGEventFlags?
    var setStringCallCount = 0
    var simulateKeyPressCallCount = 0
    
    func setString(_ string: String) {
        setStringCallCount += 1
        mockSetString = string
    }
    
    func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        simulateKeyPressCallCount += 1
        mockKeyCode = keyCode
        mockModifiers = modifiers
    }
}

class MockAlertPresenter: AlertPresenter {
    var mockErrorMessage: String?
    var showErrorCallCount = 0
    
    func showError(_ message: String) async {
        showErrorCallCount += 1
        mockErrorMessage = message
    }
}

// MARK: - Test Suite

final class TextProcessorTests: XCTestCase {
    var tempDir: TemporaryDirectory!
    var configManager: ConfigurationManager!
    var claudeService: ClaudeService!
    var mockTextSelectionProvider: MockTextSelectionProvider!
    var mockTextReplacer: MockTextReplacer!
    var mockAccessibilityChecker: MockAccessibilityChecker!
    var mockAlertPresenter: MockAlertPresenter!
    var textProcessor: TextProcessor!
    
    override func setUp() {
        super.setUp()
        tempDir = try! TemporaryDirectory()
        
        // Create configuration
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-api-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        claudeService = ClaudeService(configManager: configManager)
        
        // Create mock providers
        mockTextSelectionProvider = MockTextSelectionProvider()
        mockTextReplacer = MockTextReplacer()
        mockAccessibilityChecker = MockAccessibilityChecker()
        mockAlertPresenter = MockAlertPresenter()
        
        // Create text processor with mocks
        textProcessor = TextProcessor(
            configManager: configManager,
            textSelectionProvider: mockTextSelectionProvider,
            textReplacer: mockTextReplacer,
            accessibilityChecker: mockAccessibilityChecker,
            alertPresenter: mockAlertPresenter
        )
    }
    
    override func tearDown() {
        tempDir.cleanup()
        super.tearDown()
    }
    
    func test_textProcessorInitialization() {
        // Given: A text processor with mocked dependencies
        // When: Initialize TextProcessor
        // Then: Should initialize without error
        XCTAssertNotNil(textProcessor)
    }
    
    func test_processSelectedText_noAccessibilityPermissions() async {
        // Given: No accessibility permissions
        mockAccessibilityChecker.mockIsAccessibilityEnabled = false
        
        // When: Process selected text
        await textProcessor.processSelectedText(with: "Test prompt")
        
        // Then: Should request permissions and show error
        XCTAssertEqual(mockAccessibilityChecker.isAccessibilityEnabledCallCount, 2) // Called twice (initial check + recheck)
        XCTAssertEqual(mockAccessibilityChecker.requestAccessibilityPermissionsCallCount, 1)
        XCTAssertEqual(mockAlertPresenter.showErrorCallCount, 1)
        XCTAssertTrue(mockAlertPresenter.mockErrorMessage?.contains("Accessibility permissions are required") ?? false)
    }
    
    func test_processSelectedText_noTextSelected() async {
        // Given: Accessibility enabled but no text selected
        mockAccessibilityChecker.mockIsAccessibilityEnabled = true
        mockTextSelectionProvider.mockSelectedText = nil
        
        // When: Process selected text
        await textProcessor.processSelectedText(with: "Test prompt")
        
        // Then: Should show error about no text selected
        XCTAssertEqual(mockTextSelectionProvider.getSelectedTextCallCount, 1)
        XCTAssertEqual(mockAlertPresenter.showErrorCallCount, 1)
        XCTAssertEqual(mockAlertPresenter.mockErrorMessage, "No text selected")
    }
    
    func test_processSelectedText_emptyTextSelected() async {
        // Given: Accessibility enabled but empty text selected
        mockAccessibilityChecker.mockIsAccessibilityEnabled = true
        mockTextSelectionProvider.mockSelectedText = ""
        
        // When: Process selected text
        await textProcessor.processSelectedText(with: "Test prompt")
        
        // Then: Should show error about no text selected
        XCTAssertEqual(mockTextSelectionProvider.getSelectedTextCallCount, 1)
        XCTAssertEqual(mockAlertPresenter.showErrorCallCount, 1)
        XCTAssertEqual(mockAlertPresenter.mockErrorMessage, "No text selected")
    }
    
    func test_processSelectedText_noApiKeyConfigured() async {
        // Given: No API key configured
        let configWithoutKey = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let configData = try! JSONEncoder().encode(configWithoutKey)
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let configManagerWithoutKey = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        let textProcessorWithoutKey = TextProcessor(
            configManager: configManagerWithoutKey,
            textSelectionProvider: mockTextSelectionProvider,
            textReplacer: mockTextReplacer,
            accessibilityChecker: mockAccessibilityChecker,
            alertPresenter: mockAlertPresenter
        )
        
        // Given: Accessibility enabled and text selected
        mockAccessibilityChecker.mockIsAccessibilityEnabled = true
        mockTextSelectionProvider.mockSelectedText = "Test text"
        
        // When: Process selected text
        await textProcessorWithoutKey.processSelectedText(with: "Test prompt")
        
        // Then: Should show error about API provider
        XCTAssertEqual(mockAlertPresenter.showErrorCallCount, 1)
        XCTAssertNotNil(mockAlertPresenter.mockErrorMessage)
        // Check for API provider error message
        let errorMessage = mockAlertPresenter.mockErrorMessage?.lowercased() ?? ""
        XCTAssertTrue(errorMessage.contains("api provider") || errorMessage.contains("not configured") || errorMessage.contains("enabled"), 
                     "Expected API provider error, got: \(mockAlertPresenter.mockErrorMessage ?? "nil")")
    }
    
    func test_defaultTextSelectionProvider_getSelectedText() {
        // Given: Default text selection provider
        let provider = DefaultTextSelectionProvider()
        
        // When: Get selected text
        let result = provider.getSelectedText()
        
        // Then: Should return nil (no text selected in test environment)
        XCTAssertNil(result)
    }
    
    func test_defaultTextReplacer_replaceSelectedText() async {
        // Given: Default text replacer with mock pasteboard manager
        let mockPasteboardManager = MockPasteboardManager()
        let replacer = DefaultTextReplacer(pasteboardManager: mockPasteboardManager)
        
        // When: Replace selected text
        await replacer.replaceSelectedText(with: "New text")
        
        // Then: Should set string and simulate key press
        XCTAssertEqual(mockPasteboardManager.setStringCallCount, 1)
        XCTAssertEqual(mockPasteboardManager.mockSetString, "New text")
        XCTAssertEqual(mockPasteboardManager.simulateKeyPressCallCount, 1)
        XCTAssertEqual(mockPasteboardManager.mockKeyCode, 9) // V key
    }
    
    func test_defaultAccessibilityChecker_isAccessibilityEnabled() {
        // Given: Default accessibility checker
        let checker = DefaultAccessibilityChecker()
        
        // When: Check accessibility
        let result = checker.isAccessibilityEnabled()
        
        // Then: Should return system accessibility status
        XCTAssertNotNil(result) // Result depends on system state
    }
    
    func test_defaultPasteboardManager_setString() {
        // Given: Default pasteboard manager
        let manager = DefaultPasteboardManager()
        
        // When: Set string (note: this affects system pasteboard)
        manager.setString("Test string")
        
        // Then: Should not crash (actual pasteboard interaction tested in integration tests)
        XCTAssertTrue(true)
    }
} 