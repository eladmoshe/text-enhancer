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
    
    // MARK: - Debug Mode Configuration Tests
    
    func test_defaultDebugModeIsFalse() {
        // Given: Default configuration
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Debug mode should default to false
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
    }
    
    func test_debugModeBackwardCompatibility() {
        // Given: Configuration JSON without debugModeEnabled property (existing config)
        let configJson = """
        {
            "shortcuts": [],
            "maxTokens": 1000,
            "timeout": 30.0,
            "showStatusIcon": true,
            "enableNotifications": true,
            "autoSave": true,
            "logLevel": "info",
            "apiProviders": {
                "claude": {"apiKey": "", "model": "claude-4-sonnet", "enabled": true},
                "openai": {"apiKey": "", "model": "gpt-4o", "enabled": false}
            },
            "compression": {"preset": "balanced", "enabled": true}
        }
        """
        
        let configData = configJson.data(using: .utf8)!
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // When: Loading configuration
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: debugModeEnabled should default to false for backward compatibility
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
    }
    
    func test_debugModeExplicitlySetToTrue() {
        // Given: Configuration with debug mode explicitly enabled
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders.default,
            compression: CompressionConfiguration.default,
            debugModeEnabled: true
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // When: Loading configuration
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: debugModeEnabled should be true
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
    }
    
    func test_debugModeExplicitlySetToFalse() {
        // Given: Configuration with debug mode explicitly disabled
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders.default,
            compression: CompressionConfiguration.default,
            debugModeEnabled: false
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // When: Loading configuration
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: debugModeEnabled should be false
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
    }
    
    func test_updateDebugModeToTrue() {
        // Given: Configuration manager with debug mode disabled
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
        
        // When: Updating debug mode to true
        configManager.updateDebugMode(true)
        
        // Wait for async configuration update
        let expectation = expectation(description: "Configuration update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Debug mode should be enabled and persisted
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
        
        // Verify persistence by creating new manager
        let newConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        XCTAssertTrue(newConfigManager.configuration.debugModeEnabled)
    }
    
    func test_updateDebugModeToFalse() {
        // Given: Configuration manager with debug mode enabled
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        configManager.updateDebugMode(true)
        
        // Wait for initial update
        let initialExpectation = expectation(description: "Initial update")
        DispatchQueue.main.async {
            initialExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
        
        // When: Updating debug mode to false
        configManager.updateDebugMode(false)
        
        // Wait for async update
        let expectation = expectation(description: "Configuration update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Debug mode should be disabled and persisted
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
        
        // Verify persistence by creating new manager
        let newConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        XCTAssertFalse(newConfigManager.configuration.debugModeEnabled)
    }
    
    func test_updateDebugModePreservesOtherSettings() {
        // Given: Configuration manager with specific settings
        let originalConfig = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "test-shortcut",
                    name: "Test Shortcut",
                    keyCode: 19,
                    modifiers: [.command],
                    prompt: "Test prompt",
                    provider: .claude,
                    model: "claude-4-opus",
                    includeScreenshot: true
                )
            ],
            maxTokens: 2000,
            timeout: 60.0,
            showStatusIcon: false,
            enableNotifications: false,
            autoSave: false,
            logLevel: "debug",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-key", model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "openai-key", model: "gpt-4o", enabled: true)
            ),
            compression: CompressionConfiguration(preset: .efficient, enabled: false),
            debugModeEnabled: false
        )
        
        let configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        configManager.saveConfiguration(originalConfig)
        
        // Wait for initial save
        let initialExpectation = expectation(description: "Initial save")
        DispatchQueue.main.async {
            initialExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // When: Updating debug mode
        configManager.updateDebugMode(true)
        
        // Wait for update
        let updateExpectation = expectation(description: "Debug mode update")
        DispatchQueue.main.async {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Debug mode should be updated while preserving all other settings
        let updatedConfig = configManager.configuration
        XCTAssertTrue(updatedConfig.debugModeEnabled)
        
        // Verify all other settings are preserved
        XCTAssertEqual(updatedConfig.shortcuts.count, 1)
        XCTAssertEqual(updatedConfig.shortcuts.first?.name, "Test Shortcut")
        XCTAssertEqual(updatedConfig.shortcuts.first?.keyCode, 19)
        XCTAssertEqual(updatedConfig.shortcuts.first?.modifiers, [.command])
        XCTAssertEqual(updatedConfig.shortcuts.first?.prompt, "Test prompt")
        XCTAssertEqual(updatedConfig.shortcuts.first?.provider, .claude)
        XCTAssertEqual(updatedConfig.shortcuts.first?.model, "claude-4-opus")
        XCTAssertTrue(updatedConfig.shortcuts.first?.effectiveIncludeScreenshot == true)
        
        XCTAssertEqual(updatedConfig.maxTokens, 2000)
        XCTAssertEqual(updatedConfig.timeout, 60.0)
        XCTAssertFalse(updatedConfig.showStatusIcon)
        XCTAssertFalse(updatedConfig.enableNotifications)
        XCTAssertFalse(updatedConfig.autoSave)
        XCTAssertEqual(updatedConfig.logLevel, "debug")
        
        XCTAssertEqual(updatedConfig.apiProviders.claude.apiKey, "test-key")
        XCTAssertEqual(updatedConfig.apiProviders.claude.model, "claude-4-sonnet")
        XCTAssertTrue(updatedConfig.apiProviders.claude.enabled)
        XCTAssertEqual(updatedConfig.apiProviders.openai.apiKey, "openai-key")
        XCTAssertEqual(updatedConfig.apiProviders.openai.model, "gpt-4o")
        XCTAssertTrue(updatedConfig.apiProviders.openai.enabled)
        
        XCTAssertEqual(updatedConfig.compression.preset, .efficient)
        XCTAssertFalse(updatedConfig.compression.enabled)
    }
    
    func test_debugModeEncodingDecoding() {
        // Given: Configuration with debug mode enabled
        let config = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders.default,
            compression: CompressionConfiguration.default,
            debugModeEnabled: true
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encodedData = try! encoder.encode(config)
        let decodedConfig = try! decoder.decode(AppConfiguration.self, from: encodedData)
        
        // Then: Debug mode should be preserved
        XCTAssertTrue(decodedConfig.debugModeEnabled)
    }
} 