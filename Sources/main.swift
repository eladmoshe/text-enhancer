import SwiftUI
import AppKit

@main
struct TextEnhancerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar only app - no windows
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menuBarManager: MenuBarManager!
    var shortcutManager: ShortcutManager!
    var textProcessor: TextProcessor!
    var claudeService: ClaudeService!
    var configManager: ConfigurationManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== TextEnhancer Starting ===")
        
        // Hide from dock and prevent main window
        NSApp.setActivationPolicy(.accessory)
        
        // Check for existing instances and prevent multiple launches
        if !ensureSingleInstance() {
            print("❌ Another instance of TextEnhancer is already running")
            NSApp.terminate(nil)
            return
        }
        
        // Initialize configuration manager
        configManager = ConfigurationManager()
        
        // Initialize Claude service
        claudeService = ClaudeService(configManager: configManager)
        
        // Initialize text processor
        textProcessor = TextProcessor(configManager: configManager)
        
        // Initialize shortcut manager
        shortcutManager = ShortcutManager(textProcessor: textProcessor, configManager: configManager)
        
        // Initialize menu bar manager
        menuBarManager = MenuBarManager(shortcutManager: shortcutManager, configManager: configManager, textProcessor: textProcessor)
        
        // Setup menu bar
        setupMenuBar()
        
        // Register keyboard shortcuts
        shortcutManager.registerShortcuts()
        
        // Request accessibility permissions
        requestAccessibilityPermissions()
        
        print("=== TextEnhancer Ready ===")
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Prevent reopening windows - this is a menu bar only app
        return false
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        // No dock menu since we're an accessory app
        return nil
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.toolTip = "TextEnhancer - Enhance selected text"
        }
        
        // Use the MenuBarManager to setup the menu and icon
        menuBarManager.setupMenu(for: statusItem)
        
        // Ensure the initial icon is properly set
        menuBarManager.updateStatusIcon()
    }
    
    private func requestAccessibilityPermissions() {
        let accessEnabled = AXIsProcessTrusted()
        
        if accessEnabled {
            print("✅ Accessibility permissions already granted")
        } else {
            print("⚠️  Accessibility permissions not granted - will prompt when needed")
            // Don't prompt immediately - wait until user tries to use the shortcut
        }
    }
    
    func promptForAccessibilityPermissions() {
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            print("🔐 Prompting for accessibility permissions...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("🔐 Permission dialog should have appeared - please grant permissions and try again")
        } else {
            print("✅ Accessibility permissions already granted")
        }
    }
    
    private func ensureSingleInstance() -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.textenhancer.app"
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Count instances of this app (excluding ourselves)
        let instances = runningApps.filter { app in
            app.bundleIdentifier == bundleIdentifier && app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        
        if !instances.isEmpty {
            print("🔍 Found \(instances.count) existing TextEnhancer instance(s)")
            
            // Try to activate the existing instance
            if let existingInstance = instances.first {
                existingInstance.activate(options: [.activateIgnoringOtherApps])
                print("✅ Activated existing TextEnhancer instance")
            }
            
            return false
        }
        
        print("✅ No other TextEnhancer instances found, proceeding...")
        return true
    }

} 