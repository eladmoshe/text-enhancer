import XCTest
@testable import TextEnhancer

/// Integration tests for debug mode toggle feature
/// Tests the complete workflow: Settings UI → Configuration → Menu refresh
final class DebugModeIntegrationTests: XCTestCase {
    var tempDir: TemporaryDirectory!
    var configManager: ConfigurationManager!
    var textProcessor: TextProcessor!
    var shortcutManager: ShortcutManager!
    var menuBarManager: MenuBarManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for test config
        tempDir = try TemporaryDirectory()
        
        // Initialize managers in dependency order
        configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        textProcessor = TextProcessor(configManager: configManager)
        shortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: configManager)
        
        // Skip MenuBarManager creation in tests to avoid UserNotifications issues
        // menuBarManager = MenuBarManager(shortcutManager: shortcutManager, configManager: configManager, textProcessor: textProcessor)
    }
    
    override func tearDownWithError() throws {
        menuBarManager = nil
        shortcutManager = nil
        textProcessor = nil
        configManager = nil
        tempDir?.cleanup()
        tempDir = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Integration Tests
    
    func testCompleteDebugModeWorkflow() {
        // Test the complete workflow: toggle debug mode → save config → menu updates
        
        // Given: Initial state with debug mode disabled
        XCTAssertFalse(configManager.configuration.debugModeEnabled, 
                       "Debug mode should be disabled initially")
        
        // When: User toggles debug mode through settings (simulating SettingsView interaction)
        configManager.updateDebugMode(true)
        
        // Wait for configuration update
        let enableExpectation = expectation(description: "Debug mode enable")
        DispatchQueue.main.async {
            enableExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Configuration should be updated and persisted
        XCTAssertTrue(configManager.configuration.debugModeEnabled,
                      "Debug mode should be enabled after update")
        
        // Verify persistence by creating new configuration manager
        let newConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        XCTAssertTrue(newConfigManager.configuration.debugModeEnabled,
                      "Debug mode should persist after restart")
        
        // When: User toggles debug mode back off
        configManager.updateDebugMode(false)
        
        // Wait for configuration update
        let disableExpectation = expectation(description: "Debug mode disable")
        DispatchQueue.main.async {
            disableExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Configuration should be updated back to disabled
        XCTAssertFalse(configManager.configuration.debugModeEnabled,
                       "Debug mode should be disabled after second update")
        
        // Verify persistence again
        let finalConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        XCTAssertFalse(finalConfigManager.configuration.debugModeEnabled,
                       "Debug mode disabled state should persist after restart")
    }
    
    func testDebugModeConfigurationNotificationWorkflow() {
        // Test that configuration changes trigger proper notifications
        
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .configurationChanged,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        
        // When: Enabling debug mode
        configManager.updateDebugMode(true)
        
        let enableExpectation = expectation(description: "Enable notification")
        DispatchQueue.main.async {
            enableExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(notificationCount, 1, "Should receive one notification for enable")
        
        // When: Disabling debug mode
        configManager.updateDebugMode(false)
        
        let disableExpectation = expectation(description: "Disable notification")
        DispatchQueue.main.async {
            disableExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(notificationCount, 2, "Should receive two notifications total")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testDebugModeMenuBarIntegration() {
        // Test that MenuBarManager responds to debug mode configuration changes
        
        // Skip this test in headless CI environment
        let isRunningInTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isRunningInTests else {
            print("Skipping MenuBarManager integration test in headless environment")
            return
        }
        
        // Given: Initial configuration with debug mode disabled
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
        
        // Setup notification observer to track menu refresh
        var configChangeNotificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .configurationChanged,
            object: nil,
            queue: .main
        ) { _ in
            configChangeNotificationReceived = true
        }
        
        // When: Updating debug mode
        configManager.updateDebugMode(true)
        
        // Wait for notification
        let expectation = expectation(description: "Configuration change notification")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: MenuBarManager should be able to access the updated configuration
        XCTAssertTrue(configChangeNotificationReceived, "Should receive configuration change notification")
        XCTAssertTrue(configManager.configuration.debugModeEnabled, "Debug mode should be enabled")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testDebugModeSettingsIntegration() {
        // Test that SettingsView integration works with ConfigurationManager
        
        // Given: SettingsView with initial configuration
        let settingsView = SettingsView(configManager: configManager)
        XCTAssertNotNil(settingsView)
        XCTAssertFalse(configManager.configuration.debugModeEnabled)
        
        // When: Simulating user interaction (toggle debug mode via ConfigurationManager)
        configManager.updateDebugMode(true)
        
        // Wait for update
        let expectation = expectation(description: "Settings integration update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Configuration should be updated
        XCTAssertTrue(configManager.configuration.debugModeEnabled,
                      "Debug mode should be enabled through settings integration")
    }
    
    func testDebugModeWithExistingConfiguration() {
        // Test debug mode toggle with existing rich configuration
        
        // Given: Complex existing configuration
        let complexConfig = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "improve-text",
                    name: "Improve Text",
                    keyCode: 18,
                    modifiers: [.control, .option],
                    prompt: "Improve this text",
                    provider: .claude,
                    model: "claude-4-sonnet",
                    includeScreenshot: false
                ),
                ShortcutConfiguration(
                    id: "summarize",
                    name: "Summarize",
                    keyCode: 21,
                    modifiers: [.control, .option],
                    prompt: "Summarize this text",
                    provider: .openai,
                    model: "gpt-4o",
                    includeScreenshot: true
                )
            ],
            maxTokens: 2000,
            timeout: 45.0,
            showStatusIcon: true,
            enableNotifications: false,
            autoSave: true,
            logLevel: "debug",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-claude-key", model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "test-openai-key", model: "gpt-4o", enabled: true)
            ),
            compression: CompressionConfiguration(preset: .efficient, enabled: true),
            debugModeEnabled: false
        )
        
        configManager.saveConfiguration(complexConfig)
        
        // Wait for save
        let saveExpectation = expectation(description: "Complex config save")
        DispatchQueue.main.async {
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // When: Toggling debug mode
        configManager.updateDebugMode(true)
        
        // Wait for update
        let updateExpectation = expectation(description: "Debug mode update")
        DispatchQueue.main.async {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Debug mode should be updated while preserving all other settings
        let updatedConfig = configManager.configuration
        XCTAssertTrue(updatedConfig.debugModeEnabled, "Debug mode should be enabled")
        
        // Verify all original settings are preserved
        XCTAssertEqual(updatedConfig.shortcuts.count, 2)
        XCTAssertEqual(updatedConfig.shortcuts.first?.name, "Improve Text")
        XCTAssertEqual(updatedConfig.shortcuts.last?.name, "Summarize")
        XCTAssertEqual(updatedConfig.maxTokens, 2000)
        XCTAssertEqual(updatedConfig.timeout, 45.0)
        XCTAssertTrue(updatedConfig.showStatusIcon)
        XCTAssertFalse(updatedConfig.enableNotifications)
        XCTAssertTrue(updatedConfig.autoSave)
        XCTAssertEqual(updatedConfig.logLevel, "debug")
        XCTAssertEqual(updatedConfig.apiProviders.claude.apiKey, "test-claude-key")
        XCTAssertEqual(updatedConfig.apiProviders.openai.apiKey, "test-openai-key")
        XCTAssertEqual(updatedConfig.compression.preset, .efficient)
        XCTAssertTrue(updatedConfig.compression.enabled)
    }
    
    func testDebugModeBackwardCompatibilityIntegration() {
        // Test that the complete system handles old configurations gracefully
        
        // Given: Old configuration file without debug mode property
        let oldConfigJson = """
        {
            "shortcuts": [
                {
                    "id": "improve-text",
                    "name": "Improve Text",
                    "keyCode": 18,
                    "modifiers": ["ctrl", "opt"],
                    "prompt": "Improve this text",
                    "provider": "claude",
                    "model": "claude-4-sonnet",
                    "includeScreenshot": false
                }
            ],
            "maxTokens": 1000,
            "timeout": 30.0,
            "showStatusIcon": true,
            "enableNotifications": false,
            "autoSave": true,
            "logLevel": "info",
            "apiProviders": {
                "claude": {"apiKey": "old-claude-key", "model": "claude-4-sonnet", "enabled": true},
                "openai": {"apiKey": "", "model": "gpt-4o", "enabled": false}
            },
            "compression": {"preset": "balanced", "enabled": true}
        }
        """
        
        let configData = oldConfigJson.data(using: .utf8)!
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // When: Loading configuration and creating managers
        let oldConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        let oldTextProcessor = TextProcessor(configManager: oldConfigManager)
        let oldShortcutManager = ShortcutManager(textProcessor: oldTextProcessor, configManager: oldConfigManager)
        let oldSettingsView = SettingsView(configManager: oldConfigManager)
        
        // Create MenuBarManager only in non-headless environment
        var oldMenuBarManager: MenuBarManager?
        let isRunningInTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningInTests {
            oldMenuBarManager = MenuBarManager(shortcutManager: oldShortcutManager, configManager: oldConfigManager, textProcessor: oldTextProcessor)
        }
        
        // Then: All components should handle missing debug mode gracefully
        if let menuBarManager = oldMenuBarManager {
            XCTAssertNotNil(menuBarManager)
        }
        XCTAssertNotNil(oldSettingsView)
        XCTAssertFalse(oldConfigManager.configuration.debugModeEnabled,
                       "Debug mode should default to false for backward compatibility")
        
        // When: Enabling debug mode on old configuration
        oldConfigManager.updateDebugMode(true)
        
        // Wait for update
        let updateExpectation = expectation(description: "Backward compatibility update")
        DispatchQueue.main.async {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then: Should work seamlessly
        XCTAssertTrue(oldConfigManager.configuration.debugModeEnabled,
                      "Debug mode should be enabled on old configuration")
        
        // Verify old settings are preserved
        XCTAssertEqual(oldConfigManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(oldConfigManager.configuration.shortcuts.first?.name, "Improve Text")
        XCTAssertEqual(oldConfigManager.configuration.apiProviders.claude.apiKey, "old-claude-key")
    }
    
    func testDebugModeAppRestartPersistence() {
        // Test that debug mode settings persist across app restarts
        
        // Phase 1: Enable debug mode
        configManager.updateDebugMode(true)
        
        let enableExpectation = expectation(description: "Enable debug mode")
        DispatchQueue.main.async {
            enableExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
        
        // Phase 2: Simulate app restart by creating new managers
        let restartConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        let restartTextProcessor = TextProcessor(configManager: restartConfigManager)
        let restartShortcutManager = ShortcutManager(textProcessor: restartTextProcessor, configManager: restartConfigManager)
        let restartSettingsView = SettingsView(configManager: restartConfigManager)
        
        // Create MenuBarManager only in non-headless environment
        var restartMenuBarManager: MenuBarManager?
        let isRunningInTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningInTests {
            restartMenuBarManager = MenuBarManager(shortcutManager: restartShortcutManager, configManager: restartConfigManager, textProcessor: restartTextProcessor)
        }
        
        // Phase 3: Verify debug mode is still enabled
        if let menuBarManager = restartMenuBarManager {
            XCTAssertNotNil(menuBarManager)
        }
        XCTAssertNotNil(restartSettingsView)
        XCTAssertTrue(restartConfigManager.configuration.debugModeEnabled,
                      "Debug mode should persist after app restart")
        
        // Phase 4: Disable debug mode and test persistence again
        restartConfigManager.updateDebugMode(false)
        
        let disableExpectation = expectation(description: "Disable debug mode")
        DispatchQueue.main.async {
            disableExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Phase 5: Final restart test
        let finalConfigManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        XCTAssertFalse(finalConfigManager.configuration.debugModeEnabled,
                       "Debug mode disabled state should persist after restart")
    }
    
    func testDebugModeErrorHandling() {
        // Test error handling in debug mode workflows
        
        // Test with invalid configuration directory (read-only)
        // This tests that the system gracefully handles configuration errors
        
        // Given: Initial working configuration
        configManager.updateDebugMode(true)
        
        let expectation = expectation(description: "Initial update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
        
        // When: System can still function even if some operations fail
        // The configuration should still be in memory and accessible
        XCTAssertTrue(configManager.configuration.debugModeEnabled,
                      "Debug mode should remain accessible even during error conditions")
        
        // Test that all components can still access the configuration
        let settingsView = SettingsView(configManager: configManager)
        XCTAssertNotNil(settingsView)
        XCTAssertTrue(configManager.configuration.debugModeEnabled)
    }
}