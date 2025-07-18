import AppKit
import SwiftUI
import UserNotifications

class MenuBarManager: ObservableObject {
    private let shortcutManager: ShortcutManager
    private let configManager: ConfigurationManager
    private let textProcessor: TextProcessor
    private var statusItem: NSStatusItem?
    @Published var isProcessing = false
    private var animationTimer: Timer?
    private var animationPhase = 0
    private var permissionCheckTimer: Timer?
    private var lastAccessibilityStatus = false
    
    init(shortcutManager: ShortcutManager, configManager: ConfigurationManager, textProcessor: TextProcessor) {
        self.shortcutManager = shortcutManager
        self.configManager = configManager
        self.textProcessor = textProcessor
        
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
        
        // Set initial accessibility status and log it
        lastAccessibilityStatus = AXIsProcessTrusted()
        print("🔍 Initial accessibility status: \(lastAccessibilityStatus)")
        print("📋 Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        
        // Start periodic permission checking
        startPermissionMonitoring()
        
        // Listen for configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationChanged),
            name: .configurationChanged,
            object: nil
        )
    }
    
    func setupMenu(for statusItem: NSStatusItem) {
        NSLog("🔧 MenuBarManager: Setting up menu...")
        self.statusItem = statusItem
        
        let menu = NSMenu()
        
        // Force a fresh permission check every time the menu is set up
        // This ensures we get current permission status
        forcePermissionRefresh()
        
        // Status item
        let statusMenuItem = NSMenuItem(title: "TextEnhancer", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        NSLog("🔧 MenuBarManager: Added status item")

        menu.addItem(NSMenuItem.separator())

        // Master shortcut menu item
        let masterShortcutItem = NSMenuItem(title: "⌃⌥⇥ - Show All Shortcuts", action: #selector(showMasterShortcutMenu), keyEquivalent: "")
        masterShortcutItem.target = self
        masterShortcutItem.toolTip = "Show floating menu with all shortcuts"
        menu.addItem(masterShortcutItem)
        
        // Shortcut actions - make them clickable from menu
        let shortcuts = configManager.configuration.shortcuts
        if shortcuts.isEmpty {
            let noShortcutsItem = NSMenuItem(title: "No shortcuts configured", action: nil, keyEquivalent: "")
            noShortcutsItem.isEnabled = false
            menu.addItem(noShortcutsItem)
        } else {
            for shortcut in shortcuts {
                let shortcutDisplay = formatShortcutDisplay(shortcut.modifiers, shortcut.keyCode)
                let shortcutMenuItem = NSMenuItem(title: "\(shortcutDisplay) - \(shortcut.name)", action: #selector(handleMenuShortcut(_:)), keyEquivalent: "")
                shortcutMenuItem.target = self
                shortcutMenuItem.representedObject = shortcut
                shortcutMenuItem.toolTip = "Click to \(shortcut.name.lowercased())"
                menu.addItem(shortcutMenuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Accessibility permission status - always get fresh status
        NSLog("🔧 MenuBarManager: Adding accessibility item...")
        let accessibilityStatus = AXIsProcessTrusted()
        let accessibilityItem = NSMenuItem(
            title: accessibilityStatus ? "✅ Accessibility: Enabled" : "⚠️ Accessibility: Disabled (Click to enable)",
            action: accessibilityStatus ? #selector(debugPermissionStatus) : #selector(requestAccessibilityPermissions),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.isEnabled = true
        menu.addItem(accessibilityItem)
        NSLog("🔧 MenuBarManager: Added accessibility item: '\(accessibilityItem.title)'")

        // Screen recording permission status - always get fresh status
        NSLog("🔧 MenuBarManager: Adding screen recording item...")
        let screenRecordingStatus: Bool
        if #available(macOS 10.15, *) {
            screenRecordingStatus = CGPreflightScreenCaptureAccess()
        } else {
            screenRecordingStatus = true // Always enabled on older macOS
        }
        
        let screenRecordingItem = NSMenuItem(
            title: screenRecordingStatus ? "✅ Screen Recording: Enabled" : "⚠️ Screen Recording: Disabled (Click to enable)",
            action: screenRecordingStatus ? #selector(debugPermissionStatus) : #selector(requestScreenRecordingPermissions),
            keyEquivalent: ""
        )
        screenRecordingItem.target = self
        screenRecordingItem.isEnabled = true
        menu.addItem(screenRecordingItem)
        NSLog("🔧 MenuBarManager: Added screen recording item: '\(screenRecordingItem.title)'")

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Force restart option
        let restartItem = NSMenuItem(title: "🔄 Force Restart App", action: #selector(forceRestartApp), keyEquivalent: "r")
        restartItem.target = self
        menu.addItem(restartItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit TextEnhancer", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        NSLog("🔧 MenuBarManager: Menu setup complete! Total items: \(menu.items.count)")
        NSLog("🔧 MenuBarManager: Menu items: \(menu.items.map { $0.title })")
    }
    
    private func refreshMenu() {
        guard let statusItem = self.statusItem else { return }
        setupMenu(for: statusItem)
    }
    
    private func startPermissionMonitoring() {
        // Check permissions every 2 seconds to detect changes
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissionChanges()
        }
    }
    
    private func checkPermissionChanges() {
        let currentStatus = AXIsProcessTrusted()
        
        // Always log current status for debugging
        if currentStatus != lastAccessibilityStatus {
            print("🔄 Accessibility permission status changed: \(lastAccessibilityStatus) -> \(currentStatus)")
            print("📋 Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
            print("📋 Bundle path: \(Bundle.main.bundlePath)")
            lastAccessibilityStatus = currentStatus
            
            DispatchQueue.main.async {
                self.updateStatusIcon()
                self.refreshMenu()
            }
        }
    }
    
    private func forcePermissionRefresh() {
        // Force update the permission status by simulating a change
        let currentStatus = AXIsProcessTrusted()
        let previousStatus = lastAccessibilityStatus
        
        print("🔄 Force refreshing permission status...")
        print("   Current accessibility status: \(currentStatus)")
        print("   Last known status: \(previousStatus)")
        
        // Update our internal state
        lastAccessibilityStatus = currentStatus
        
        // Update the status icon
        updateStatusIcon()
        
        // Also check screen recording for completeness
        let screenRecordingStatus: Bool
        if #available(macOS 10.15, *) {
            screenRecordingStatus = CGPreflightScreenCaptureAccess()
        } else {
            screenRecordingStatus = true
        }
        print("   Current screen recording status: \(screenRecordingStatus)")
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
    
    @objc func handleMenuShortcut(_ sender: NSMenuItem) {
        guard let shortcut = sender.representedObject as? ShortcutConfiguration else { return }
        
        Task {
            await textProcessor.processSelectedText(with: shortcut.prompt)
        }
    }
    
    @objc func showMasterShortcutMenu() {
        // Trigger the master shortcut menu
        shortcutManager.showMasterShortcutMenu()
    }
    
    @objc private func requestAccessibilityPermissions() {
        print("🔐 MenuBarManager: Permission request triggered from menu")
        
        // Direct permission check and request
        let currentStatus = AXIsProcessTrusted()
        print("🔐 MenuBarManager: Current accessibility status: \(currentStatus)")
        
        if !currentStatus {
            print("🔐 MenuBarManager: Requesting accessibility permissions...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let newStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("🔐 MenuBarManager: Permission request result: \(newStatus)")
            
            // Also try through app delegate as backup
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.promptForAccessibilityPermissions()
            }
        } else {
            print("🔐 MenuBarManager: Permissions already granted")
        }
        
        // Update the menu after requesting permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshMenu()
        }
    }
    
    @objc private func requestScreenRecordingPermissions() {
        print("🔐 MenuBarManager: Screen recording permission request triggered from menu")
        
        // Check current screen recording permission status
        let currentStatus = CGPreflightScreenCaptureAccess()
        print("🔐 MenuBarManager: Current screen recording status: \(currentStatus)")
        
        if !currentStatus {
            print("🔐 MenuBarManager: Opening System Preferences for screen recording permission")
            
            // Always open System Preferences directly for screen recording permissions
            // CGRequestScreenCaptureAccess() doesn't work reliably in unsigned apps
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
                
                // Show alert with instructions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let alert = NSAlert()
                    alert.messageText = "Screen Recording Permission Required"
                    alert.informativeText = """
                    To enable screenshot functionality:
                    
                    1. In System Settings > Privacy & Security > Screen Recording
                    2. Click the '+' button
                    3. Navigate to and select TextEnhancer.app
                    4. Enable the checkbox next to TextEnhancer
                    5. Restart TextEnhancer
                    
                    App location: \(Bundle.main.bundlePath)
                    """
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        } else {
            print("🔐 MenuBarManager: Screen recording permissions already granted")
        }
        
        // Update the menu after requesting permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshMenu()
        }
    }
    
    @objc private func debugPermissionStatus() {
        let accessibilityStatus = AXIsProcessTrusted()
        let screenRecordingStatus = CGPreflightScreenCaptureAccess()
        print("🔍 COMPREHENSIVE Permission Diagnostic:")
        print("   AXIsProcessTrusted(): \(accessibilityStatus)")
        print("   CGPreflightScreenCaptureAccess(): \(screenRecordingStatus)")
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("   Bundle path: \(Bundle.main.bundlePath)")
        print("   Executable path: \(Bundle.main.executablePath ?? "nil")")
        print("   Last known status: \(lastAccessibilityStatus)")
        print("   Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("   Process name: \(ProcessInfo.processInfo.processName)")
        print("   Is running from Applications?: \(Bundle.main.bundlePath.hasPrefix("/Applications/"))")
        
        // Check if we're the installed version
        let installedPath = "/Applications/TextEnhancer.app"
        let isInstalledVersion = Bundle.main.bundlePath == installedPath
        print("   Is installed version?: \(isInstalledVersion)")
        
        if !isInstalledVersion {
            print("   ⚠️  WARNING: Not running from Applications folder!")
            print("   Expected: \(installedPath)")
            print("   Actual: \(Bundle.main.bundlePath)")
        }
        
        // Test actual accessibility functionality
        testAccessibilityCapability()
        
        // Force refresh the status
        lastAccessibilityStatus = !accessibilityStatus // Force change detection
        checkPermissionChanges()
    }
    
    private func testAccessibilityCapability() {
        print("🧪 Testing actual accessibility capability...")
        
        // Try to access system-wide accessibility
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        print("   AXUIElementCopyAttributeValue result: \(result.rawValue)")
        print("   Success means: \(result == .success)")
        
        if result != .success {
            print("   ❌ Cannot access accessibility - this explains the permission issue")
        } else {
            print("   ✅ Can access accessibility - permissions should be working")
        }
    }
    
    @objc private func forceRestartApp() {
        print("🔄 Force restarting TextEnhancer...")
        
        // Get the app bundle path
        let appPath = Bundle.main.bundlePath
        print("   App path: \(appPath)")
        
        // Verify this is the expected installation path to prevent old version launches
        let expectedPath = "/Users/\(NSUserName())/Applications/TextEnhancer.app"
        if !appPath.contains("/Applications/TextEnhancer.app") {
            print("⚠️  WARNING: App running from unexpected location: \(appPath)")
            print("   Expected: \(expectedPath)")
            print("   This may cause restart issues. Consider reinstalling.")
        }
        
        // Create a restart script that specifically targets the current running version
        let restartScript = """
        #!/bin/bash
        sleep 1
        open "\(appPath)"
        """
        
        // Write script to temporary file
        let tempScript = "/tmp/restart_textenhancer.sh"
        do {
            try restartScript.write(toFile: tempScript, atomically: true, encoding: .utf8)
            
            // Make it executable and run it
            let process = Process()
            process.launchPath = "/bin/chmod"
            process.arguments = ["+x", tempScript]
            process.launch()
            process.waitUntilExit()
            
            // Launch the restart script
            let restartProcess = Process()
            restartProcess.launchPath = "/bin/bash"
            restartProcess.arguments = [tempScript]
            restartProcess.launch()
            
            // Quit this instance
            NSApp.terminate(nil)
            
        } catch {
            print("❌ Failed to create restart script: \(error)")
        }
    }
    
    @objc private func openSettings() {
        SettingsWindowManager.shared.showSettings(configManager: configManager)
    }
    
    @objc private func configurationChanged() {
        print("🔄 MenuBarManager: Configuration changed, refreshing menu")
        DispatchQueue.main.async {
            self.refreshMenu()
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
        
        let accessibilityEnabled = AXIsProcessTrusted()
        
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
        } else if !accessibilityEnabled {
            // Show different warning icons based on whether we're running in bundle or not
            let isBundle = !Bundle.main.bundlePath.contains("/.build/")
            
            if isBundle {
                // Production (bundled): Use triangle with exclamation mark
                if let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Accessibility permissions required") {
                    button.image = image
                    button.image?.size = NSSize(width: 16, height: 16)
                    button.image?.isTemplate = true
                } else {
                    button.title = "⚠️"
                }
            } else {
                // Development (non-bundled): Use wrench to indicate development mode
                if let image = NSImage(systemSymbolName: "wrench", accessibilityDescription: "Development mode - permissions required") {
                    button.image = image
                    button.image?.size = NSSize(width: 16, height: 16)
                    button.image?.isTemplate = true
                } else {
                    button.title = "🔧"
                }
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
        permissionCheckTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// Notification names
extension Notification.Name {
    static let textProcessingStarted = Notification.Name("textProcessingStarted")
    static let textProcessingFinished = Notification.Name("textProcessingFinished")
} 