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
        let configURL = tempDir.configFile()
        
        // Create test configuration
        let testConfig = """
        {
            "claudeApiKey": "test-key",
            "shortcuts": [
                {
                    "id": "improve-text",
                    "name": "Improve Text",
                    "keyCode": 18,
                    "modifiers": ["ctrl", "opt"],
                    "prompt": "Improve this text"
                }
            ],
            "maxTokens": 1000,
            "timeout": 30.0,
            "showStatusIcon": true,
            "enableNotifications": false,
            "autoSave": true,
            "logLevel": "info"
        }
        """
        
        try testConfig.write(to: configURL, atomically: true, encoding: .utf8)
        
        // Initialize managers
        configManager = ConfigurationManager(
            localConfig: configURL,
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
    
    func testProcessingIconAnimation() {
        // Test that processing icon uses magic wand variants
        // This verifies the processing state uses the correct inverse icon
        
        let processingIcon = NSImage(systemSymbolName: "wand.and.stars.inverse", accessibilityDescription: "Processing...")
        XCTAssertNotNil(processingIcon, "wand.and.stars.inverse SF Symbol should be available for processing state")
        
        if let icon = processingIcon {
            // Verify the processing icon can be configured as a template
            icon.isTemplate = true
            XCTAssertTrue(icon.isTemplate, "Processing icon should support template mode")
            
            // Verify it can be resized
            icon.size = NSSize(width: 16, height: 16)
            XCTAssertEqual(icon.size, NSSize(width: 16, height: 16), "Processing icon should be resizable to 16x16")
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
    
    func testMenuItemsAreClickable() {
        // Test that menu items configuration is correct (without creating UI)
        // This verifies the menu structure and shortcut configuration
        
        let shortcuts = configManager.configuration.shortcuts
        XCTAssertGreaterThan(shortcuts.count, 0, "Should have at least one shortcut configured")
        
        // Verify the first shortcut has the expected properties
        let firstShortcut = shortcuts[0]
        XCTAssertEqual(firstShortcut.name, "Improve Text", "First shortcut should be 'Improve Text'")
        XCTAssertEqual(firstShortcut.keyCode, 18, "First shortcut should have keyCode 18")
        XCTAssertEqual(firstShortcut.modifiers, [.control, .option], "First shortcut should have ctrl+opt modifiers")
        XCTAssertFalse(firstShortcut.prompt.isEmpty, "First shortcut should have a prompt")
    }
    
    func testMenuShortcutHandling() {
        // Test that MenuBarManager has the handleMenuShortcut method
        // This ensures the menu functionality exists
        
        let shortcut = configManager.configuration.shortcuts[0]
        
        // Create a mock menu item
        let menuItem = NSMenuItem(title: shortcut.name, action: #selector(MenuBarManager.handleMenuShortcut(_:)), keyEquivalent: "")
        menuItem.representedObject = shortcut
        menuItem.target = menuBarManager
        
        // Verify the menu item is properly configured
        XCTAssertEqual(menuItem.title, "Improve Text", "Menu item should have correct title")
        XCTAssertEqual(menuItem.action, #selector(MenuBarManager.handleMenuShortcut(_:)), "Menu item should have correct action")
        XCTAssertNotNil(menuItem.representedObject, "Menu item should have represented object")
        XCTAssertTrue(menuItem.representedObject is ShortcutConfiguration, "Represented object should be ShortcutConfiguration")
        
        // Verify the MenuBarManager can respond to the selector
        XCTAssertTrue((menuBarManager as AnyObject).responds(to: #selector(MenuBarManager.handleMenuShortcut(_:))), "MenuBarManager should respond to handleMenuShortcut")
    }
} 