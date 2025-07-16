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
            localConfig: tempDir.configFile(),
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
    }
    
    func test_claudeApiKeyReturnsNilWhenEmpty() {
        // Given: Configuration with empty API key
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
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
                claude: APIProviderConfig(apiKey: "test-api-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! configData.write(to: tempDir.configFile())
        
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: claudeApiKey should return the value
        XCTAssertEqual(configManager.claudeApiKey, "test-api-key")
    }
    
    func test_saveAndLoadConfiguration() {
        // Given: Configuration manager
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
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
                claude: APIProviderConfig(apiKey: "modified-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        configManager.saveConfiguration(modifiedConfig)
        
        let newConfigManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        XCTAssertEqual(newConfigManager.configuration.apiProviders.claude.apiKey, "modified-key")
        XCTAssertEqual(newConfigManager.configuration.maxTokens, 2000)
        XCTAssertEqual(newConfigManager.configuration.timeout, 60.0)
        XCTAssertEqual(newConfigManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.id, "test-shortcut")
    }
    
    func test_loadConfigurationFromFallbackLocation() {
        // Given: Fallback configuration file
        try! tempDir.createAppSupportDirectory()
        
        let fallbackConfig = AppConfiguration(
            shortcuts: [],
            maxTokens: 1500,
            timeout: 45.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "warn",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "fallback-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let fallbackConfigData = try! JSONEncoder().encode(fallbackConfig)
        try! fallbackConfigData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should load fallback configuration
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "fallback-key")
        XCTAssertEqual(configManager.configuration.maxTokens, 1500)
        XCTAssertEqual(configManager.configuration.timeout, 45.0)
    }
    
    func test_localConfigurationTakesPrecedenceOverFallback() {
        // Given: Both local and fallback configuration files exist
        try! tempDir.createAppSupportDirectory()
        
        let localConfig = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "local-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let fallbackConfig = AppConfiguration(
            shortcuts: [],
            maxTokens: 1500,
            timeout: 45.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "warn",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "fallback-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let localConfigData = try! JSONEncoder().encode(localConfig)
        let fallbackConfigData = try! JSONEncoder().encode(fallbackConfig)
        
        try! localConfigData.write(to: tempDir.configFile())
        try! fallbackConfigData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should load local configuration
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "local-key")
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.logLevel, "info")
    }
    
    func test_fallsBackToDefaultWhenNoConfigurationFound() {
        // Given: No configuration files exist
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should fall back to default configuration
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "")
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
    }
} 