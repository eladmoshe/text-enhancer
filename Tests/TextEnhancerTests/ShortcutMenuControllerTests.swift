import XCTest
import AppKit
@testable import TextEnhancer

final class ShortcutMenuControllerTests: XCTestCase {
    private var configManager: ConfigurationManager!
    private var textProcessor: TextProcessor!
    private var shortcutManager: ShortcutManager!
    private var tempDir: TemporaryDirectory!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = try TemporaryDirectory()
        try tempDir.createAppSupportDirectory()

        // Minimal configuration with a single shortcut so the menu shows.
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
            enableNotifications: false,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders.default,
            compression: CompressionConfiguration.default
        )
        let data = try JSONEncoder().encode(testConfig)
        try data.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))

        configManager = ConfigurationManager(appSupportDir: tempDir.appSupportDirectory())
        textProcessor = TextProcessor(configManager: configManager)
        shortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: configManager)
    }

    override func tearDownWithError() throws {
        shortcutManager = nil
        textProcessor = nil
        configManager = nil
        tempDir?.cleanup()
        tempDir = nil
        try super.tearDownWithError()
    }

    func testShowAndHideMenuDoesNotCrash() {
        let controller = ShortcutMenuController(configManager: configManager, textProcessor: textProcessor)

        // Show the menu on main thread
        let showHideExpectation = expectation(description: "Show and hide menu")

        // Perform show/hide asynchronously on the main queue to avoid deadlock if the current
        // test is already executing on the main thread. Using async guarantees the closure will
        // run even when we are on the main queue, preventing the crash we observed on CI.
        DispatchQueue.main.async {
            controller.showMenu()
            controller.hideMenu()
            showHideExpectation.fulfill()
        }

        wait(for: [showHideExpectation], timeout: 1.0)
        // Allow asynchronous cleanup to finish
        let cleanupExpectation = XCTestExpectation(description: "Wait for hide clean up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        // If we reached here without a crash, the test passes
        XCTAssertTrue(true)
    }
} 