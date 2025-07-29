import AppKit
import SwiftUI

class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()

    var settingsWindow: NSWindow?
    var windowDelegate: SettingsWindowDelegate?

    private init() {}

    func showSettings(configManager: ConfigurationManager) {
        if let window = settingsWindow {
            window.orderFront(nil)
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(configManager: configManager)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "TextEnhancer Settings"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        // Set minimum size
        window.minSize = NSSize(width: 600, height: 500)

        // Handle window closing
        windowDelegate = SettingsWindowDelegate()
        window.delegate = windowDelegate

        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
        windowDelegate = nil
    }
}

class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_: Notification) {
        SettingsWindowManager.shared.settingsWindow = nil
        SettingsWindowManager.shared.windowDelegate = nil
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        true
    }
}
