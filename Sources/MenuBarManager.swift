import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private let shortcutManager: ShortcutManager
    private let configManager: ConfigurationManager
    @Published var isProcessing = false
    
    init(shortcutManager: ShortcutManager, configManager: ConfigurationManager) {
        self.shortcutManager = shortcutManager
        self.configManager = configManager
        
        // Listen for processing status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processingStarted),
            name: .textProcessingStarted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processingFinished),
            name: .textProcessingFinished,
            object: nil
        )
    }
    
    func setupMenu(for statusItem: NSStatusItem) {
        let menu = NSMenu()
        
        // Status item
        let statusMenuItem = NSMenuItem(title: "TextEnhancer", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Shortcut info
        let shortcutInfoItem = NSMenuItem(title: "⌃⌥1 - Improve Text", action: nil, keyEquivalent: "")
        shortcutInfoItem.isEnabled = false
        menu.addItem(shortcutInfoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Configuration info
        let configItem = NSMenuItem(title: "Edit config.json to configure", action: nil, keyEquivalent: "")
        configItem.isEnabled = false
        menu.addItem(configItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit TextEnhancer", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    

    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func processingStarted() {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.updateStatusIcon()
        }
    }
    
    @objc private func processingFinished() {
        DispatchQueue.main.async {
            self.isProcessing = false
            self.updateStatusIcon()
        }
    }
    
    private func updateStatusIcon() {
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let statusItem = appDelegate.statusItem,
              let button = statusItem.button else { return }
        
        // Clear any existing title
        button.title = ""
        
        // Use proper SF Symbol icons
        if isProcessing {
            button.image = NSImage(systemSymbolName: "wand.and.stars.inverse", accessibilityDescription: "Processing...")
        } else {
            button.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Text Enhancer")
        }
        
        button.image?.size = NSSize(width: 18, height: 18)
        button.appearsDisabled = false
    }
}

// Notification names
extension Notification.Name {
    static let textProcessingStarted = Notification.Name("textProcessingStarted")
    static let textProcessingFinished = Notification.Name("textProcessingFinished")
} 