import XCTest
@testable import TextEnhancer

final class TextProcessorTests: XCTestCase {
    
    func test_textProcessorInitialization() {
        // Given: A mock Claude service
        let tempDir = try! TemporaryDirectory()
        let configManager = ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
        let claudeService = ClaudeService(configManager: configManager)
        
        // When: Initialize TextProcessor
        let textProcessor = TextProcessor(claudeService: claudeService)
        
        // Then: Should initialize without error
        XCTAssertNotNil(textProcessor)
        
        tempDir.cleanup()
    }
    
    // TODO: Add more comprehensive tests once we extract protocols for:
    // - TextSelectionProvider (getSelectedText)
    // - TextReplacer (replaceSelectedText)
    // - AccessibilityChecker (AXIsProcessTrusted)
    // - PasteboardManager (NSPasteboard operations)
    // - KeyEventSimulator (CGEvent operations)
    
    // This will allow us to test the core logic without depending on
    // actual system accessibility APIs and pasteboard operations.
} 