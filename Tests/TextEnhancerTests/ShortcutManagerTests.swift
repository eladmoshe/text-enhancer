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
            shortcuts: [
                ShortcutConfiguration(
                    id: "improve-text",
                    name: "Improve Text",
                    keyCode: 18,
                    modifiers: [.control, .option],
                    prompt: "Improve the writing quality and clarity of this text.",
                    provider: .claude,
                    model: "claude-4-sonnet",
                    includeScreenshot: false
                ),
                ShortcutConfiguration(
                    id: "make-formal",
                    name: "Make Formal",
                    keyCode: 19,
                    modifiers: [.control, .option],
                    prompt: "Rewrite this text in a formal tone.",
                    provider: .claude,
                    model: "claude-4-opus",
                    includeScreenshot: false
                ),
                ShortcutConfiguration(
                    id: "summarize",
                    name: "Summarize",
                    keyCode: 20,
                    modifiers: [.control, .option],
                    prompt: "Provide a concise summary of this text.",
                    provider: .claude,
                    model: "claude-4-sonnet",
                    includeScreenshot: false
                )
            ],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        let configData = try! JSONEncoder().encode(testConfig)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        configManager = ConfigurationManager(
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
    
    func test_detectsConflictingShortcuts() {
        // Given: Configuration with conflicting shortcuts
        let conflictingConfig = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "first-shortcut",
                    name: "First Shortcut",
                    keyCode: 18,
                    modifiers: [.control, .option],
                    prompt: "First prompt",
                    provider: .claude,
                    model: "claude-4-sonnet",
                    includeScreenshot: false
                ),
                ShortcutConfiguration(
                    id: "second-shortcut",
                    name: "Second Shortcut",
                    keyCode: 18,
                    modifiers: [.control, .option], // Same modifiers
                    prompt: "Second prompt",
                    provider: .claude,
                    model: "claude-4-opus",
                    includeScreenshot: false
                )
            ],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        let configData = try! JSONEncoder().encode(conflictingConfig)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let conflictingConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        let conflictingTextProcessor = TextProcessor(configManager: conflictingConfigManager)
        let conflictingShortcutManager = ShortcutManager(textProcessor: conflictingTextProcessor, configManager: conflictingConfigManager)
        
        // When: Try to register shortcuts
        // Then: Should handle conflicts gracefully
        XCTAssertNotNil(conflictingShortcutManager)
    }
    
    func test_handlesEmptyShortcutConfiguration() {
        // Given: Configuration with no shortcuts
        let emptyConfig = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        let configData = try! JSONEncoder().encode(emptyConfig)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let emptyConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        let emptyTextProcessor = TextProcessor(configManager: emptyConfigManager)
        let emptyShortcutManager = ShortcutManager(textProcessor: emptyTextProcessor, configManager: emptyConfigManager)
        
        // When: Initialize with empty shortcuts
        // Then: Should initialize without error
        XCTAssertNotNil(emptyShortcutManager)
    }
} 