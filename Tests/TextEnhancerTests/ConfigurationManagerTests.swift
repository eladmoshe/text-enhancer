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
        XCTAssertEqual(configManager.configuration.claudeApiKey, "")
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
    
    func test_claudeApiKeyReturnsValueWhenSet() throws {
        // Given: Configuration with API key
        let config = AppConfiguration(
            claudeApiKey: "test-api-key",
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info"
        )
        
        let configData = try JSONEncoder().encode(config)
        try configData.write(to: tempDir.configFile())
        
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: claudeApiKey should return the value
        XCTAssertEqual(configManager.claudeApiKey, "test-api-key")
    }
    
    func test_saveAndReloadRoundTrips() throws {
        // Given: A configuration manager
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // When: Save a modified configuration
        let modifiedConfig = AppConfiguration(
            claudeApiKey: "modified-key",
            shortcuts: [
                ShortcutConfiguration(
                    id: "test-shortcut",
                    name: "Test Shortcut",
                    keyCode: 42,
                    modifiers: [.command, .shift],
                    prompt: "Test prompt"
                )
            ],
            maxTokens: 2000,
            timeout: 60.0,
            showStatusIcon: false,
            enableNotifications: false,
            autoSave: false,
            logLevel: "debug"
        )
        
        configManager.saveConfiguration(modifiedConfig)
        
        // Then: A new instance should load the saved configuration
        let newConfigManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        XCTAssertEqual(newConfigManager.configuration.claudeApiKey, "modified-key")
        XCTAssertEqual(newConfigManager.configuration.maxTokens, 2000)
        XCTAssertEqual(newConfigManager.configuration.timeout, 60.0)
        XCTAssertFalse(newConfigManager.configuration.showStatusIcon)
        XCTAssertFalse(newConfigManager.configuration.enableNotifications)
        XCTAssertFalse(newConfigManager.configuration.autoSave)
        XCTAssertEqual(newConfigManager.configuration.logLevel, "debug")
        XCTAssertEqual(newConfigManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.id, "test-shortcut")
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.name, "Test Shortcut")
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.keyCode, 42)
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.modifiers, [.command, .shift])
        XCTAssertEqual(newConfigManager.configuration.shortcuts.first?.prompt, "Test prompt")
    }
    
    func test_loadsFallbackConfigWhenLocalMissing() throws {
        // Given: No local config but fallback exists
        try tempDir.createAppSupportDirectory()
        
        let fallbackConfig = AppConfiguration(
            claudeApiKey: "fallback-key",
            shortcuts: [],
            maxTokens: 1500,
            timeout: 45.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "warn"
        )
        
        let configData = try JSONEncoder().encode(fallbackConfig)
        try configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // When: Create configuration manager
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should load fallback configuration
        XCTAssertEqual(configManager.configuration.claudeApiKey, "fallback-key")
        XCTAssertEqual(configManager.configuration.maxTokens, 1500)
        XCTAssertEqual(configManager.configuration.timeout, 45.0)
        XCTAssertEqual(configManager.configuration.logLevel, "warn")
    }
    
    func test_localConfigTakesPrecedenceOverFallback() throws {
        // Given: Both local and fallback configs exist
        try tempDir.createAppSupportDirectory()
        
        let localConfig = AppConfiguration(
            claudeApiKey: "local-key",
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info"
        )
        
        let fallbackConfig = AppConfiguration(
            claudeApiKey: "fallback-key",
            shortcuts: [],
            maxTokens: 1500,
            timeout: 45.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "warn"
        )
        
        let localData = try JSONEncoder().encode(localConfig)
        let fallbackData = try JSONEncoder().encode(fallbackConfig)
        
        try localData.write(to: tempDir.configFile())
        try fallbackData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // When: Create configuration manager
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should load local configuration
        XCTAssertEqual(configManager.configuration.claudeApiKey, "local-key")
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.logLevel, "info")
    }
    
    func test_handlesCorruptedConfigFile() throws {
        // Given: A corrupted config file
        let corruptedData = "invalid json".data(using: .utf8)!
        try corruptedData.write(to: tempDir.configFile())
        
        // When: Create configuration manager
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        
        // Then: Should fall back to default configuration
        XCTAssertEqual(configManager.configuration.claudeApiKey, "")
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
    }
} 