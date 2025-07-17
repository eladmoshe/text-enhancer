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
        XCTAssertEqual(configManager.configuration.shortcuts.first?.model, "claude-4-sonnet")
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
            )
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
}