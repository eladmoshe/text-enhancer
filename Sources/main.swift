import SwiftUI
import AppKit

@main
struct TextEnhancerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar app without main window
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
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
        
        // Initialize configuration manager
        configManager = ConfigurationManager()
        
        // Initialize Claude service
        claudeService = ClaudeService(configManager: configManager)
        
        // Initialize text processor
        textProcessor = TextProcessor(claudeService: claudeService)
        
        // Initialize shortcut manager
        shortcutManager = ShortcutManager(textProcessor: textProcessor)
        
        // Initialize menu bar manager
        menuBarManager = MenuBarManager(shortcutManager: shortcutManager, configManager: configManager)
        
        // Setup menu bar
        setupMenuBar()
        
        // Register keyboard shortcuts
        shortcutManager.registerShortcuts()
        
        // Request accessibility permissions
        requestAccessibilityPermissions()
        
        print("=== TextEnhancer Ready ===")
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
        }
    }
    

} 