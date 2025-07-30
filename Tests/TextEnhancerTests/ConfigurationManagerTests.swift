import XCTest
@testable import TextEnhancer

final class ConfigurationManagerTests: XCTestCase {
    var tempDir: TemporaryDirectory!
    
    override func setUp() {
        super.setUp()
        tempDir = try! TemporaryDirectory()
    }
    
    override func tearDown() {
        tempDir.cleanup()
        super.tearDown()
    }
    
    func test_loadsDefaultWhenNoFileExists() {
        // Given: No config file exists
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should load default configuration
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "")
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.timeout, 30.0)
        XCTAssertTrue(configManager.configuration.showStatusIcon)
        XCTAssertTrue(configManager.configuration.enableNotifications)
        XCTAssertTrue(configManager.configuration.autoSave)
        XCTAssertEqual(configManager.configuration.logLevel, "info")
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.id, "improve-text")
        XCTAssertEqual(configManager.configuration.shortcuts.first?.model, "claude-sonnet-4-20250514")
    }
    
    func test_claudeApiKeyReturnsNilWhenEmpty() {
        // Given: Configuration with empty API key
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: claudeApiKey should return nil
        XCTAssertNil(configManager.claudeApiKey)
    }
    
    func test_claudeApiKeyReturnsValueWhenSet() {
        // Given: Configuration with API key
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-api-key", model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-4o", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: claudeApiKey should return the value
        XCTAssertEqual(configManager.claudeApiKey, "test-api-key")
    }
    
    func test_saveAndLoadConfiguration() {
        // Given: Configuration manager
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // When: Save a modified configuration
        let modifiedConfig = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "test-shortcut",
                    name: "Test Shortcut",
                    keyCode: 20,
                    modifiers: [.command, .shift],
                    prompt: "Test prompt",
                    provider: .claude,
                    model: "claude-4-opus",
                    includeScreenshot: false
                )
            ],
            maxTokens: 2000,
            timeout: 60.0,
            showStatusIcon: false,
            enableNotifications: false,
            autoSave: false,
            logLevel: "debug",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "modified-key", model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-4o", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        configManager.saveConfiguration(modifiedConfig)
        
        let newConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        XCTAssertEqual(newConfigManager.configuration.apiProviders.claude.apiKey, "modified-key")
        XCTAssertEqual(newConfigManager.configuration.maxTokens, 2000)
        XCTAssertEqual(newConfigManager.configuration.timeout, 60.0)
        XCTAssertEqual(newConfigManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.id, "test-shortcut")
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.model, "claude-4-opus")
    }
    
    func test_loadConfigurationFromAppSupportDirectory() {
        // Given: Configuration file in app support directory
        try! tempDir.createAppSupportDirectory()
        
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1500,
            timeout: 45.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "warn",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "app-support-key", model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-4o", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should load configuration from app support directory
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "app-support-key")
        XCTAssertEqual(configManager.configuration.maxTokens, 1500)
        XCTAssertEqual(configManager.configuration.timeout, 45.0)
    }
    
    func test_fallsBackToDefaultWhenNoConfigurationFound() {
        // Given: No configuration files exist
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should fall back to default configuration
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "")
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.model, "claude-sonnet-4-20250514")
    }
    
    // MARK: - Compression Configuration Tests
    
    func test_defaultCompressionConfiguration() {
        // Given: Default configuration
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should have default compression settings
        XCTAssertNotNil(configManager.configuration.compression)
        XCTAssertEqual(configManager.configuration.compression.preset, .balanced)
        XCTAssertTrue(configManager.configuration.compression.enabled)
        XCTAssertNil(configManager.configuration.compression.customQuality)
        XCTAssertNil(configManager.configuration.compression.maxSizeBytes)
    }
    
    func test_compressionConfigurationPersistence() throws {
        // Given: Configuration with custom compression settings
        let customCompression = CompressionConfiguration(
            preset: .efficient,
            enabled: true,
            customQuality: 0.8,
            maxSizeBytes: 50000
        )
        
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders.default,
            compression: customCompression
        )
        
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // When: Save and reload configuration
        configManager.saveConfiguration(config)
        
        let newConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Compression settings should persist
        XCTAssertEqual(newConfigManager.configuration.compression.preset, .efficient)
        XCTAssertTrue(newConfigManager.configuration.compression.enabled)
        XCTAssertEqual(newConfigManager.configuration.compression.customQuality, 0.8)
        XCTAssertEqual(newConfigManager.configuration.compression.maxSizeBytes, 50000)
    }
    
    func test_compressionConfigurationWithDisabledCompression() {
        // Given: Configuration with compression disabled
        let disabledCompression = CompressionConfiguration(
            preset: .ultraHigh,
            enabled: false
        )
        
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders.default,
            compression: disabledCompression
        )
        
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        configManager.saveConfiguration(config)
        
        // Wait for async configuration update
        let expectation = expectation(description: "Configuration update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Should preserve disabled state
        XCTAssertFalse(configManager.configuration.compression.enabled)
        XCTAssertEqual(configManager.configuration.compression.preset, .ultraHigh)
    }
} 