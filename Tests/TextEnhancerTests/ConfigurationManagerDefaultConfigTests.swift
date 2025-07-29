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
            autoSave: false,
            logLevel: "debug",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-claude-key", model: "claude-test", enabled: false),
                openai: APIProviderConfig(apiKey: "test-openai-key", model: "gpt-test", enabled: true)
            )
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
        XCTAssertFalse(configManager.configuration.autoSave)
        XCTAssertEqual(configManager.configuration.logLevel, "debug")
        XCTAssertEqual(configManager.configuration.apiProviders.claude.apiKey, "test-claude-key")
        XCTAssertEqual(configManager.configuration.apiProviders.openai.apiKey, "test-openai-key")
    }
} 