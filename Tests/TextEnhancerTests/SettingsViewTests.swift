import XCTest
import SwiftUI
@testable import TextEnhancer

class SettingsViewTests: XCTestCase {
    var configManager: ConfigurationManager!
    var tempDir: TemporaryDirectory!
    
    override func setUp() {
        super.setUp()
        do {
            tempDir = try TemporaryDirectory()
            configManager = ConfigurationManager(
                appSupportDir: tempDir.url.appendingPathComponent("AppSupport")
            )
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }
    }
    
    override func tearDown() {
        tempDir = nil
        configManager = nil
        super.tearDown()
    }
    
    func testSettingsViewInitialization() {
        let settingsView = SettingsView(configManager: configManager)
        
        XCTAssertNotNil(settingsView)
        XCTAssertNotNil(settingsView.configManager)
    }
    
    func testSettingsViewWithDefaultConfiguration() {
        let settingsView = SettingsView(configManager: configManager)
        
        XCTAssertNotNil(settingsView)
        
        // Should have default shortcut configuration
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.name, "Improve Text")
        XCTAssertEqual(configManager.configuration.shortcuts.first?.provider, .claude)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.model, "claude-sonnet-4-20250514")
        XCTAssertEqual(configManager.configuration.shortcuts.first?.keyCode, 18)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.modifiers, [.control, .option])
    }
    
    func testSettingsViewWithCustomConfiguration() {
        let customConfig = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "test-shortcut",
                    name: "Test Shortcut",
                    keyCode: 19,
                    modifiers: [.command, .shift],
                    prompt: "Test prompt",
                    provider: .openai,
                    model: "gpt-4o",
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
                claude: APIProviderConfig(
                    apiKey: "test-claude-key",
                    model: "claude-4-sonnet",
                    enabled: true
                ),
                openai: APIProviderConfig(
                    apiKey: "test-openai-key",
                    model: "gpt-4o",
                    enabled: true
                )
            ),
            compression: CompressionConfiguration.default
        )
        
        configManager.configuration = customConfig
        let settingsView = SettingsView(configManager: configManager)
        
        XCTAssertNotNil(settingsView)
        
        // Should have custom shortcut configuration
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.name, "Test Shortcut")
        XCTAssertEqual(configManager.configuration.shortcuts.first?.provider, .openai)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.model, "gpt-4o")
        XCTAssertEqual(configManager.configuration.shortcuts.first?.keyCode, 19)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.modifiers, [.command, .shift])
        XCTAssertEqual(configManager.configuration.shortcuts.first?.effectiveIncludeScreenshot, true)
    }
    
    func testShortcutConfigurationIdentifiable() {
        let shortcut = ShortcutConfiguration(
            id: "test-id",
            name: "Test",
            keyCode: 18,
            modifiers: [.control],
            prompt: "Test prompt",
            provider: .claude,
            model: "claude-4-sonnet",
            includeScreenshot: false
        )
        
        XCTAssertEqual(shortcut.id, "test-id")
        
        // Test that ShortcutConfiguration conforms to Identifiable
        let identifiableShortcut: any Identifiable = shortcut
        XCTAssertEqual(identifiableShortcut.id as? String, "test-id")
    }
    
    func testShortcutConfigurationDefaults() {
        let shortcut = ShortcutConfiguration(
            id: "test-id",
            name: "Test",
            keyCode: 18,
            modifiers: [.control],
            prompt: "Test prompt",
            provider: .claude,
            model: "claude-4-sonnet",
            includeScreenshot: nil
        )
        
        XCTAssertEqual(shortcut.effectiveProvider, .claude)
        XCTAssertEqual(shortcut.effectiveModel, "claude-4-sonnet")
        XCTAssertEqual(shortcut.effectiveIncludeScreenshot, false)
        
        let shortcutWithScreenshot = ShortcutConfiguration(
            id: "test-id-2",
            name: "Test 2",
            keyCode: 19,
            modifiers: [.option],
            prompt: "Test prompt 2",
            provider: .openai,
            model: "gpt-4o",
            includeScreenshot: true
        )
        
        XCTAssertEqual(shortcutWithScreenshot.effectiveProvider, .openai)
        XCTAssertEqual(shortcutWithScreenshot.effectiveModel, "gpt-4o")
        XCTAssertEqual(shortcutWithScreenshot.effectiveIncludeScreenshot, true)
    }
    
    func testAPIProviderDisplayNames() {
        XCTAssertEqual(APIProvider.claude.displayName, "Claude")
        XCTAssertEqual(APIProvider.openai.displayName, "OpenAI")
    }
    
    func testModifierKeyDisplayNames() {
        XCTAssertEqual(ModifierKey.command.displayName, "⌘")
        XCTAssertEqual(ModifierKey.control.displayName, "⌃")
        XCTAssertEqual(ModifierKey.option.displayName, "⌥")
        XCTAssertEqual(ModifierKey.shift.displayName, "⇧")
    }
    
    func testTestPromptInitialState() {
        let settingsView = SettingsView(configManager: configManager)
        
        XCTAssertNotNil(settingsView)
        
        // Test that the test prompt functionality is properly initialized
        // We can't directly access the @State variables, but we can verify the view exists
        XCTAssertNotNil(settingsView.configManager)
        XCTAssertTrue(settingsView.configManager === configManager)
    }
    
    func testAPIKeyLockInitialState() {
        // Test with empty API keys - should start unlocked
        let emptyConfig = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(
                    apiKey: "",
                    model: "claude-4-sonnet",
                    enabled: true
                ),
                openai: APIProviderConfig(
                    apiKey: "",
                    model: "gpt-4o",
                    enabled: true
                )
            ),
            compression: CompressionConfiguration.default
        )
        
        configManager.configuration = emptyConfig
        let settingsView = SettingsView(configManager: configManager)
        
        // With empty keys, the view should be initialized and lock states should be based on key presence
        XCTAssertNotNil(settingsView)
        
        // Test with keys present - should start locked
        let configWithKeys = AppConfiguration(
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(
                    apiKey: "test-claude-key",
                    model: "claude-4-sonnet",
                    enabled: true
                ),
                openai: APIProviderConfig(
                    apiKey: "test-openai-key",
                    model: "gpt-4o",
                    enabled: true
                )
            ),
            compression: CompressionConfiguration.default
        )
        
        configManager.configuration = configWithKeys
        let settingsViewWithKeys = SettingsView(configManager: configManager)
        
        // With keys present, the view should be initialized properly
        XCTAssertNotNil(settingsViewWithKeys)
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "test-claude-key")
        XCTAssertEqual(configManager.configuration.apiProviders.openai.apiKey, "test-openai-key")
    }
    
    // MARK: - Debug Mode Toggle Tests
    
    func testSettingsViewDebugModeDefaultState() {
        // Test that SettingsView reflects the default debug mode state
        let settingsView = SettingsView(configManager: configManager)
        
        XCTAssertNotNil(settingsView)
        XCTAssertFalse(configManager.configuration.debugModeEnabled, "Debug mode should be disabled by default")
    }
    
    func testSettingsViewDebugModeEnabledState() {
        // Given: Configuration with debug mode enabled
        let debugConfig = AppConfiguration(
            shortcuts: configManager.configuration.shortcuts,
            maxTokens: configManager.configuration.maxTokens,
            timeout: configManager.configuration.timeout,
            showStatusIcon: configManager.configuration.showStatusIcon,
            enableNotifications: configManager.configuration.enableNotifications,
            autoSave: configManager.configuration.autoSave,
            logLevel: configManager.configuration.logLevel,
            apiProviders: configManager.configuration.apiProviders,
            compression: configManager.configuration.compression,
            debugModeEnabled: true
        )
        configManager.configuration = debugConfig
        
        // When: Creating SettingsView
        let settingsView = SettingsView(configManager: configManager)
        
        // Then: Should reflect enabled debug mode
        XCTAssertNotNil(settingsView)
        XCTAssertTrue(configManager.configuration.debugModeEnabled, "Debug mode should be enabled when set to true")
    }
    
    func testSettingsViewDebugModeDisabledState() {
        // Given: Configuration with debug mode explicitly disabled
        let debugConfig = AppConfiguration(
            shortcuts: configManager.configuration.shortcuts,
            maxTokens: configManager.configuration.maxTokens,
            timeout: configManager.configuration.timeout,
            showStatusIcon: configManager.configuration.showStatusIcon,
            enableNotifications: configManager.configuration.enableNotifications,
            autoSave: configManager.configuration.autoSave,
            logLevel: configManager.configuration.logLevel,
            apiProviders: configManager.configuration.apiProviders,
            compression: configManager.configuration.compression,
            debugModeEnabled: false
        )
        configManager.configuration = debugConfig
        
        // When: Creating SettingsView
        let settingsView = SettingsView(configManager: configManager)
        
        // Then: Should reflect disabled debug mode
        XCTAssertNotNil(settingsView)
        XCTAssertFalse(configManager.configuration.debugModeEnabled, "Debug mode should be disabled when set to false")
    }
    
    func testSettingsViewInitializationWithDebugMode() {
        // Test that SettingsView initializes correctly with debug mode configuration
        
        // Test with debug mode enabled
        let enabledConfig = AppConfiguration(
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
        configManager.configuration = enabledConfig
        
        let settingsViewEnabled = SettingsView(configManager: configManager)
        XCTAssertNotNil(settingsViewEnabled)
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
        
        // Test with debug mode disabled
        let disabledConfig = AppConfiguration(
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
        configManager.configuration = disabledConfig
        
        let settingsViewDisabled = SettingsView(configManager: configManager)
        XCTAssertNotNil(settingsViewDisabled)
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
    }
    
    func testDebugModeConfigurationIntegration() {
        // Test that SettingsView properly integrates with ConfigurationManager for debug mode
        
        // Given: Initial configuration
        let initialDebugState = configManager.configuration.debugModeEnabled
        let settingsView = SettingsView(configManager: configManager)
        
        XCTAssertNotNil(settingsView)
        
        // When: Updating debug mode through ConfigurationManager
        configManager.updateDebugMode(!initialDebugState)
        
        // Wait for configuration update
        let expectation = expectation(description: "Configuration update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Configuration should be updated
        XCTAssertEqual(configManager.configuration.debugModeEnabled, !initialDebugState,
                       "Debug mode should be toggled through ConfigurationManager")
    }
    
    func testDebugModeToggleWithOtherSettings() {
        // Test that debug mode toggle works alongside other settings
        
        // Given: Configuration with specific settings
        let config = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "test-shortcut",
                    name: "Test Shortcut",
                    keyCode: 18,
                    modifiers: [.control, .option],
                    prompt: "Test prompt",
                    provider: .claude,
                    model: "claude-4-sonnet",
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
                claude: APIProviderConfig(apiKey: "test-key", model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-4o", enabled: false)
            ),
            compression: CompressionConfiguration.default,
            debugModeEnabled: false
        )
        configManager.saveConfiguration(config)
        
        // Wait for save
        let saveExpectation = expectation(description: "Configuration save")
        DispatchQueue.main.async {
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // When: Creating SettingsView and updating debug mode
        let settingsView = SettingsView(configManager: configManager)
        XCTAssertNotNil(settingsView)
        
        configManager.updateDebugMode(true)
        
        // Wait for update
        let updateExpectation = expectation(description: "Debug mode update")
        DispatchQueue.main.async {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Debug mode should be updated while preserving other settings
        let updatedConfig = configManager.configuration
        XCTAssertTrue(updatedConfig.debugModeEnabled, "Debug mode should be enabled")
        
        // Verify other settings are preserved
        XCTAssertEqual(updatedConfig.shortcuts.count, 1)
        XCTAssertEqual(updatedConfig.shortcuts.first?.name, "Test Shortcut")
        XCTAssertEqual(updatedConfig.maxTokens, 2000)
        XCTAssertEqual(updatedConfig.timeout, 60.0)
        XCTAssertFalse(updatedConfig.showStatusIcon)
        XCTAssertFalse(updatedConfig.enableNotifications)
        XCTAssertFalse(updatedConfig.autoSave)
        XCTAssertEqual(updatedConfig.logLevel, "debug")
        XCTAssertEqual(updatedConfig.apiProviders.claude.apiKey, "test-key")
    }
    
    func testDebugModeBackwardCompatibilityInSettingsView() {
        // Test that SettingsView handles configurations without debug mode property
        
        // Given: Configuration JSON without debugModeEnabled (simulating existing user config)
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
        
        // When: Creating new ConfigurationManager and SettingsView
        let newConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        let settingsView = SettingsView(configManager: newConfigManager)
        
        // Then: Should handle missing debug mode gracefully
        XCTAssertNotNil(settingsView)
        XCTAssertFalse(newConfigManager.configuration.debugModeEnabled,
                       "Debug mode should default to false for backward compatibility")
    }
}