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
            apiProviders: APIProviders.default
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
        DispatchQueue.main.sync {
            controller.showMenu()
            controller.hideMenu()
        }

        // Allow asynchronous cleanup to finish
        let expectation = XCTestExpectation(description: "Wait for hide clean up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        // If we reached here without a crash, the test passes
        XCTAssertTrue(true)
    }
} 