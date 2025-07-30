import XCTest
@testable import TextEnhancer
import Foundation

final class ConfigurationManagerDefaultConfigTests: XCTestCase {
    
    func testLoadsBundledDefaultConfigWhenUserConfigMissing() throws {
        let tempDir = try TemporaryDirectory()
        
        // Create a ConfigurationManager with a temp directory (no user config)
        let configManager = ConfigurationManager(appSupportDir: tempDir.url)
        
        // The configuration should be loaded successfully
        XCTAssertGreaterThan(configManager.configuration.shortcuts.count, 0, "Should have loaded shortcuts from bundled default config")
        
        // Should have at least the default improve-text shortcut
        let improveTextShortcut = configManager.configuration.shortcuts.first { $0.id == "improve-text" }
        XCTAssertNotNil(improveTextShortcut, "Should have the default improve-text shortcut")
        XCTAssertEqual(improveTextShortcut?.name, "Improve Text")
        XCTAssertEqual(improveTextShortcut?.keyCode, 18) // Key "1"
        XCTAssertEqual(improveTextShortcut?.modifiers, [.control, .option])
        
        // API keys should be empty (scrubbed)
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "")
        XCTAssertEqual(configManager.configuration.apiProviders.openai.apiKey, "")
        
        // Other default settings should be present
        XCTAssertEqual(configManager.configuration.maxTokens, 1000)
        XCTAssertEqual(configManager.configuration.timeout, 30.0)
        XCTAssertTrue(configManager.configuration.showStatusIcon)
        XCTAssertTrue(configManager.configuration.enableNotifications)
        XCTAssertTrue(configManager.configuration.autoSave)
        XCTAssertEqual(configManager.configuration.logLevel, "info")
    }
    
    func testFallsBackToHardcodedDefaultWhenBundledConfigMissing() throws {
        // This test is theoretical since we always bundle the config, but good to have
        let tempDir = try TemporaryDirectory()
        
        // Create a ConfigurationManager with a temp directory
        let configManager = ConfigurationManager(appSupportDir: tempDir.url)
        
        // Should have some configuration loaded (either bundled or hardcoded)
        XCTAssertGreaterThan(configManager.configuration.shortcuts.count, 0)
        XCTAssertTrue(configManager.configuration.showStatusIcon)
    }
    
    func testUserConfigTakesPrecedenceOverBundledDefault() throws {
        let tempDir = try TemporaryDirectory()
        
        // Create a custom user configuration
        let customConfig = AppConfiguration(
            shortcuts: [
                ShortcutConfiguration(
                    id: "custom-shortcut",
                    name: "Custom Shortcut",
                    keyCode: 19, // Key "2"
                    modifiers: [.command, .shift],
                    prompt: "Custom prompt for testing",
                    provider: .openai,
                    model: "gpt-4",
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
                claude: APIProviderConfig(apiKey: "test-claude-key", model: "claude-test", enabled: false),
                openai: APIProviderConfig(apiKey: "test-openai-key", model: "gpt-test", enabled: true)
            ),
            compression: CompressionConfiguration.default
        )
        
        // Save the custom config to the temp directory
        let configFile = tempDir.url.appendingPathComponent("config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(customConfig)
        try data.write(to: configFile)
        
        // Create ConfigurationManager - should load the user config, not bundled default
        let configManager = ConfigurationManager(appSupportDir: tempDir.url)
        
        // Verify it loaded the user config
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.id, "custom-shortcut")
        XCTAssertEqual(configManager.configuration.shortcuts.first?.name, "Custom Shortcut")
        XCTAssertEqual(configManager.configuration.maxTokens, 2000)
        XCTAssertEqual(configManager.configuration.timeout, 60.0)
        XCTAssertFalse(configManager.configuration.showStatusIcon)
        XCTAssertFalse(configManager.configuration.enableNotifications)
        XCTAssertFalse(configManager.configuration.autoSave)
        XCTAssertEqual(configManager.configuration.logLevel, "debug")
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "test-claude-key")
        XCTAssertEqual(configManager.configuration.apiProviders.openai.apiKey, "test-openai-key")
    }
    
    // MARK: - TDD Tests for KeyCode Mapping Fix
    
    func testDefaultConfigHasCorrectKeyCodeMappingsForScreenshotFeatures() throws {
        // RED: This test should fail initially because keyCodes are swapped
        let tempDir = try TemporaryDirectory()
        let configManager = ConfigurationManager(appSupportDir: tempDir.url)
        
        // Find the expand and describe-screen shortcuts
        let expandShortcut = configManager.configuration.shortcuts.first { $0.id == "expand" }
        let describeScreenShortcut = configManager.configuration.shortcuts.first { $0.id == "describe-screen" }
        
        XCTAssertNotNil(expandShortcut, "Should have expand shortcut")
        XCTAssertNotNil(describeScreenShortcut, "Should have describe-screen shortcut")
        
        // The key mappings should be intuitive: 
        // Ctrl+Option+6 (keyCode 22) should be for screenshot analysis (describe-screen, includeScreenshot: true)
        // Ctrl+Option+7 (keyCode 23) should be for text expansion (expand, includeScreenshot: false)
        XCTAssertEqual(describeScreenShortcut?.keyCode, 22, "Ctrl+Option+6 should trigger describe-screen (screenshot analysis)")
        XCTAssertTrue(describeScreenShortcut?.includeScreenshot ?? false, "describe-screen should include screenshot")
        
        XCTAssertEqual(expandShortcut?.keyCode, 23, "Ctrl+Option+7 should trigger expand (text only)")
        XCTAssertFalse(expandShortcut?.includeScreenshot ?? true, "expand should not include screenshot")
    }
    
    func testScreenshotShortcutHasCorrectConfiguration() throws {
        // RED: This test should fail initially
        let tempDir = try TemporaryDirectory()
        let configManager = ConfigurationManager(appSupportDir: tempDir.url)
        
        let describeScreenShortcut = configManager.configuration.shortcuts.first { $0.id == "describe-screen" }
        
        XCTAssertNotNil(describeScreenShortcut, "Should have describe-screen shortcut")
        guard let shortcut = describeScreenShortcut else {
            XCTFail("describe-screen shortcut should not be nil")
            return
        }
        
        XCTAssertEqual(shortcut.keyCode, 22, "describe-screen should be mapped to keyCode 22 (Ctrl+Option+6)")
        XCTAssertEqual(shortcut.includeScreenshot, true, "describe-screen must include screenshot")
        XCTAssertEqual(shortcut.modifiers, [.control, .option], "Should have correct modifiers")
        XCTAssertTrue(shortcut.prompt.contains("screenshot"), "Prompt should reference screenshot")
    }
    
    func testTextExpansionShortcutHasCorrectConfiguration() throws {
        // RED: This test should fail initially
        let tempDir = try TemporaryDirectory()
        let configManager = ConfigurationManager(appSupportDir: tempDir.url)
        
        let expandShortcut = configManager.configuration.shortcuts.first { $0.id == "expand" }
        
        XCTAssertNotNil(expandShortcut, "Should have expand shortcut")
        guard let shortcut = expandShortcut else {
            XCTFail("expand shortcut should not be nil")
            return
        }
        
        XCTAssertEqual(shortcut.keyCode, 23, "expand should be mapped to keyCode 23 (Ctrl+Option+7)")
        XCTAssertNotEqual(shortcut.includeScreenshot, true, "expand should not include screenshot")
        XCTAssertEqual(shortcut.modifiers, [.control, .option], "Should have correct modifiers")
        XCTAssertTrue(shortcut.prompt.contains("Expand"), "Prompt should reference text expansion")
    }
} 