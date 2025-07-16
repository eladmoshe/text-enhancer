import XCTest
@testable import TextEnhancer

final class ShortcutManagerTests: XCTestCase {
    var tempDir: TemporaryDirectory!
    var configManager: ConfigurationManager!
    var claudeService: ClaudeService!
    var textProcessor: TextProcessor!
    var shortcutManager: ShortcutManager!
    
    override func setUp() {
        super.setUp()
        tempDir = try! TemporaryDirectory()
        
        // Create configuration with multiple shortcuts
        let testConfig = AppConfiguration(
            claudeApiKey: "test-key",
            shortcuts: [
                ShortcutConfiguration(
                    id: "improve-text",
                    name: "Improve Text",
                    keyCode: 18,
                    modifiers: [.control, .option],
                    prompt: "Improve the writing quality and clarity of this text.",
                    provider: nil,
                    includeScreenshot: nil
                ),
                ShortcutConfiguration(
                    id: "make-formal",
                    name: "Make Formal",
                    keyCode: 19,
                    modifiers: [.control, .option],
                    prompt: "Rewrite this text in a formal tone.",
                    provider: nil,
                    includeScreenshot: nil
                ),
                ShortcutConfiguration(
                    id: "summarize",
                    name: "Summarize",
                    keyCode: 20,
                    modifiers: [.control, .option],
                    prompt: "Provide a concise summary of this text.",
                    provider: nil,
                    includeScreenshot: nil
                )
            ],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: nil
        )
        
        let configData = try! JSONEncoder().encode(testConfig)
        try! configData.write(to: tempDir.configFile())
        
        configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        claudeService = ClaudeService(configManager: configManager)
        textProcessor = TextProcessor(configManager: configManager)
        shortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: configManager)
    }
    
    override func tearDown() {
        tempDir.cleanup()
        super.tearDown()
    }
    
    func test_shortcutManagerInitialization() {
        // Given: A shortcut manager with multiple shortcuts configured
        // When: Initialize the shortcut manager
        // Then: Should initialize without error
        XCTAssertNotNil(shortcutManager)
    }
    
    func test_multipleShortcutsConfiguration() {
        // Given: Configuration with multiple shortcuts
        let shortcuts = configManager.configuration.shortcuts
        
        // Then: Should have multiple shortcuts configured
        XCTAssertEqual(shortcuts.count, 3)
        XCTAssertEqual(shortcuts[0].id, "improve-text")
        XCTAssertEqual(shortcuts[0].name, "Improve Text")
        XCTAssertEqual(shortcuts[0].keyCode, 18)
        XCTAssertEqual(shortcuts[0].modifiers, [.control, .option])
        XCTAssertEqual(shortcuts[0].prompt, "Improve the writing quality and clarity of this text.")
        
        XCTAssertEqual(shortcuts[1].id, "make-formal")
        XCTAssertEqual(shortcuts[1].name, "Make Formal")
        XCTAssertEqual(shortcuts[1].keyCode, 19)
        XCTAssertEqual(shortcuts[1].modifiers, [.control, .option])
        XCTAssertEqual(shortcuts[1].prompt, "Rewrite this text in a formal tone.")
        
        XCTAssertEqual(shortcuts[2].id, "summarize")
        XCTAssertEqual(shortcuts[2].name, "Summarize")
        XCTAssertEqual(shortcuts[2].keyCode, 20)
        XCTAssertEqual(shortcuts[2].modifiers, [.control, .option])
        XCTAssertEqual(shortcuts[2].prompt, "Provide a concise summary of this text.")
    }
    
    func test_shortcutConflictDetection() {
        // Given: Configuration with conflicting shortcuts
        let conflictingConfig = AppConfiguration(
            claudeApiKey: "test-key",
            shortcuts: [
                ShortcutConfiguration(
                    id: "first",
                    name: "First Shortcut",
                    keyCode: 18,
                    modifiers: [.control, .option],
                    prompt: "First prompt",
                    provider: nil,
                    includeScreenshot: nil
                ),
                ShortcutConfiguration(
                    id: "second",
                    name: "Second Shortcut",
                    keyCode: 18, // Same key code
                    modifiers: [.control, .option], // Same modifiers
                    prompt: "Second prompt",
                    provider: nil,
                    includeScreenshot: nil
                )
            ],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: nil
        )
        
        let configData = try! JSONEncoder().encode(conflictingConfig)
        try! configData.write(to: tempDir.configFile())
        
        let conflictConfigManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // When: Initialize shortcut manager with conflicting shortcuts
        let conflictShortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: conflictConfigManager)
        
        // Then: Should not crash and should handle conflicts gracefully
        XCTAssertNotNil(conflictShortcutManager)
        XCTAssertEqual(conflictConfigManager.configuration.shortcuts.count, 2)
    }
    
    func test_emptyShortcutsConfiguration() {
        // Given: Configuration with no shortcuts
        let emptyConfig = AppConfiguration(
            claudeApiKey: "test-key",
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: nil
        )
        
        let configData = try! JSONEncoder().encode(emptyConfig)
        try! configData.write(to: tempDir.configFile())
        
        let emptyConfigManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // When: Initialize shortcut manager with empty shortcuts
        let emptyShortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: emptyConfigManager)
        
        // Then: Should handle empty configuration gracefully
        XCTAssertNotNil(emptyShortcutManager)
        XCTAssertEqual(emptyConfigManager.configuration.shortcuts.count, 0)
    }
} 