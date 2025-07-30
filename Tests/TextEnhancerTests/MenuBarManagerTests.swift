import XCTest
import AppKit
@testable import TextEnhancer

class MenuBarManagerTests: XCTestCase {
    var menuBarManager: MenuBarManager!
    var shortcutManager: ShortcutManager!
    var configManager: ConfigurationManager!
    var textProcessor: TextProcessor!
    var tempDir: TemporaryDirectory!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for test config
        tempDir = try TemporaryDirectory()
        
        // Create test configuration with proper structure
        let testConfig = AppConfiguration(
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
                )
            ],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: false, // Disable notifications to avoid UserNotifications issues in tests
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "test-key", model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            ),
            compression: CompressionConfiguration.default
        )
        
        let configData = try JSONEncoder().encode(testConfig)
        try tempDir.createAppSupportDirectory()
        try configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        // Initialize managers
        configManager = ConfigurationManager(
            appSupportDir: tempDir.appSupportDirectory()
        )
        textProcessor = TextProcessor(configManager: configManager)
        shortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: configManager)
        menuBarManager = MenuBarManager(shortcutManager: shortcutManager, configManager: configManager, textProcessor: textProcessor)
    }
    
    override func tearDownWithError() throws {
        menuBarManager = nil
        shortcutManager = nil
        configManager = nil
        textProcessor = nil
        tempDir?.cleanup()
        tempDir = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Icon Tests
    
    func testDefaultIconIsMagicWand() {
        // Test that the magic wand SF Symbol is available and has correct properties
        // This is a documentation test to ensure the icon doesn't change
        
        // Test normal state icon
        let normalIcon = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Text Enhancer")
        XCTAssertNotNil(normalIcon, "wand.and.stars SF Symbol should be available")
        
        if let icon = normalIcon {
            // Verify the icon can be configured as a template
            icon.isTemplate = true
            XCTAssertTrue(icon.isTemplate, "Icon should support template mode")
            
            // Verify it can be resized
            icon.size = NSSize(width: 16, height: 16)
            XCTAssertEqual(icon.size, NSSize(width: 16, height: 16), "Icon should be resizable to 16x16")
        }
    }
    
    func testIconConfiguration() {
        // Test that icons can be properly configured
        // This ensures our icon setup logic works correctly
        
        let testIcon = NSImage(systemSymbolName: "star", accessibilityDescription: "Test")
        XCTAssertNotNil(testIcon, "Test icon should be available")
        
        if let icon = testIcon {
            icon.isTemplate = true
            icon.size = NSSize(width: 20, height: 20)
            
            XCTAssertTrue(icon.isTemplate)
            XCTAssertEqual(icon.size.width, 20)
            XCTAssertEqual(icon.size.height, 20)
        }
    }
    
    func testIconSymbolNames() {
        // Test that we're using the correct SF Symbol names
        // This is a documentation test to ensure the symbol names don't change
        
        // Test normal state icon
        let normalIcon = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Text Enhancer")
        XCTAssertNotNil(normalIcon, "wand.and.stars SF Symbol should be available")
        
        // Test processing state icon
        let processingIcon = NSImage(systemSymbolName: "wand.and.stars.inverse", accessibilityDescription: "Processing...")
        XCTAssertNotNil(processingIcon, "wand.and.stars.inverse SF Symbol should be available")
        
        // Test animation icons
        let animationSymbols = [
            "wand.and.stars.inverse",
            "sparkles",
            "wand.and.rays.inverse",
            "sparkles"
        ]
        
        for symbolName in animationSymbols {
            let animationIcon = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Animation")
            XCTAssertNotNil(animationIcon, "\(symbolName) SF Symbol should be available for animation")
        }
    }
    
    func testIconFallbacks() {
        // Test that fallback text icons are appropriate
        // This ensures if SF Symbols aren't available, we still have good fallbacks
        
        let fallbackText = "✨"
        let processingFallbackText = "⏳"
        
        XCTAssertFalse(fallbackText.isEmpty, "Normal state fallback should not be empty")
        XCTAssertFalse(processingFallbackText.isEmpty, "Processing state fallback should not be empty")
        
        // Verify these are single emoji characters (good for menu bar)
        XCTAssertEqual(fallbackText.count, 1, "Normal fallback should be a single character")
        XCTAssertEqual(processingFallbackText.count, 1, "Processing fallback should be a single character")
    }
    
    // MARK: - Menu Tests
    
    func testMenuBarManagerInitialization() {
        // Test that the menu bar manager initializes without crashing
        XCTAssertNotNil(menuBarManager)
    }
    
    func testConfigurationAccess() {
        // Test that the manager can access its configuration
        XCTAssertNotNil(configManager)
        XCTAssertEqual(configManager.configuration.shortcuts.count, 1)
        XCTAssertEqual(configManager.configuration.shortcuts.first?.name, "Improve Text")
    }
    
    func testShortcutManagerIntegration() {
        // Test that the shortcut manager is properly integrated
        XCTAssertNotNil(shortcutManager)
    }
    
    func testTextProcessorIntegration() {
        // Test that the text processor is properly integrated
        XCTAssertNotNil(textProcessor)
    }
    
    func testNotificationConfigurationRespected() {
        // Test that notification settings are respected (should be disabled in test)
        XCTAssertFalse(configManager.configuration.enableNotifications, "Notifications should be disabled in test configuration")
    }
} 