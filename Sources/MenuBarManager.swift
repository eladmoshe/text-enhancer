import AppKit
import SwiftUI
import UserNotifications

class MenuBarManager: ObservableObject {
    private let shortcutManager: ShortcutManager
    private let configManager: ConfigurationManager
    private var statusItem: NSStatusItem?
    @Published var isProcessing = false
    private var animationTimer: Timer?
    private var animationPhase = 0
    
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
        
        // Request notification permissions if enabled
        if configManager.configuration.enableNotifications {
            requestNotificationPermissions()
        }
    }
    
    func setupMenu(for statusItem: NSStatusItem) {
        self.statusItem = statusItem
        
        let menu = NSMenu()
        
        // Status item
        let statusMenuItem = NSMenuItem(title: "TextEnhancer", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Shortcut info - display all configured shortcuts
        let shortcuts = configManager.configuration.shortcuts
        if shortcuts.isEmpty {
            let noShortcutsItem = NSMenuItem(title: "No shortcuts configured", action: nil, keyEquivalent: "")
            noShortcutsItem.isEnabled = false
            menu.addItem(noShortcutsItem)
        } else {
            for shortcut in shortcuts {
                let shortcutDisplay = formatShortcutDisplay(shortcut.modifiers, shortcut.keyCode)
                let shortcutInfoItem = NSMenuItem(title: "\(shortcutDisplay) - \(shortcut.name)", action: nil, keyEquivalent: "")
                shortcutInfoItem.isEnabled = false
                menu.addItem(shortcutInfoItem)
            }
        }

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
    
    private func formatShortcutDisplay(_ modifiers: [ModifierKey], _ keyCode: Int) -> String {
        let modifierString = modifiers.map { $0.displayName }.joined()
        let keyName = keyCodeToString(keyCode)
        return "\(modifierString)\(keyName)"
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "5"
        case 23: return "6"
        case 24: return "7"
        case 25: return "8"
        case 26: return "9"
        case 29: return "0"
        default: return "Key\(keyCode)"
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func processingStarted() {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.updateStatusIcon()
            self.startProcessingAnimation()
            self.showNotification(title: "TextEnhancer", message: "Processing text...", isStarting: true)
        }
    }
    
    @objc private func processingFinished() {
        DispatchQueue.main.async {
            self.isProcessing = false
            self.stopProcessingAnimation()
            self.updateStatusIcon()
            self.showNotification(title: "TextEnhancer", message: "Text enhancement complete!", isStarting: false)
        }
    }
    
    private func startProcessingAnimation() {
        // Stop any existing animation
        animationTimer?.invalidate()
        animationPhase = 0
        
        // Start new animation timer
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.animateProcessingIcon()
        }
    }
    
    private func stopProcessingAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
    }
    
    private func animateProcessingIcon() {
        guard let statusItem = self.statusItem,
              let button = statusItem.button else { return }
        
        animationPhase = (animationPhase + 1) % 4
        
        // Create animated icons
        let animationIcons = ["⏳", "⌛", "⏳", "⌛"]
        let animationSymbols = [
            "wand.and.stars.inverse",
            "sparkles",
            "wand.and.rays.inverse",
            "sparkles"
        ]
        
        // Try to use SF Symbols first
        if let image = NSImage(systemSymbolName: animationSymbols[animationPhase], accessibilityDescription: "Processing...") {
            button.image = image
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
            button.title = ""
        } else {
            // Fallback to text animation
            button.image = nil
            button.title = animationIcons[animationPhase]
        }
    }
    
    func updateStatusIcon() {
        guard let statusItem = self.statusItem,
              let button = statusItem.button else { return }
        
        // Clear any existing content
        button.image = nil
        button.title = ""
        
        // Use appropriate SF Symbols with fallbacks
        if isProcessing {
            // This will be overridden by animation, but set initial state
            if let image = NSImage(systemSymbolName: "wand.and.stars.inverse", accessibilityDescription: "Processing...") {
                button.image = image
                button.image?.size = NSSize(width: 16, height: 16)
                button.image?.isTemplate = true
            } else {
                button.title = "⏳"
            }
        } else {
            if let image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Text Enhancer") {
                button.image = image
                button.image?.size = NSSize(width: 16, height: 16)
                button.image?.isTemplate = true
            } else {
                button.title = "✨"
            }
        }
        
        button.appearsDisabled = false
    }
    
    private func requestNotificationPermissions() {
        // Check if we're running in a proper app bundle and not from swift run
        guard Bundle.main.bundleIdentifier != nil,
              !Bundle.main.bundlePath.contains("/.build/") else {
            print("ℹ️  Skipping notification permissions request - not running in app bundle")
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("⚠️  Notification permission error: \(error)")
            } else if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied")
            }
        }
    }
    
    private func showNotification(title: String, message: String, isStarting: Bool) {
        guard configManager.configuration.enableNotifications else { return }
        
        // Check if we're running in a proper app bundle and not from swift run
        guard Bundle.main.bundleIdentifier != nil,
              !Bundle.main.bundlePath.contains("/.build/") else {
            print("ℹ️  Skipping notification - not running in app bundle")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default
        
        // Different icons for different states
        if isStarting {
            content.badge = 1
        } else {
            content.badge = 0
        }
        
        let identifier = isStarting ? "text-processing-started" : "text-processing-finished"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️  Failed to show notification: \(error)")
            }
        }
    }
    
    deinit {
        animationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// Notification names
extension Notification.Name {
    static let textProcessingStarted = Notification.Name("textProcessingStarted")
    static let textProcessingFinished = Notification.Name("textProcessingFinished")
} 