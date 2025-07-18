import AppKit
import SwiftUI

class ShortcutMenuController: ObservableObject {
    private var menuWindow: NSWindow?
    private let configManager: ConfigurationManager
    private let textProcessor: TextProcessor
    private var eventMonitor: Any?
    
    init(configManager: ConfigurationManager, textProcessor: TextProcessor) {
        self.configManager = configManager
        self.textProcessor = textProcessor
    }
    
    func showMenu() {
        // Don't show menu if already visible
        if menuWindow != nil {
            return
        }
        
        let shortcuts = configManager.configuration.shortcuts
        
        // Don't show menu if no shortcuts are configured
        if shortcuts.isEmpty {
            print("🔧 ShortcutMenuController: No shortcuts configured, not showing menu")
            return
        }
        
        print("🔧 ShortcutMenuController: Showing menu with \(shortcuts.count) shortcuts")
        
        // Create the menu view
        let menuView = ShortcutMenuView(
            shortcuts: shortcuts,
            onSelectShortcut: { [weak self] shortcut in
                self?.executeShortcut(shortcut)
            },
            onDismiss: { [weak self] in
                self?.hideMenu()
            }
        )
        
        // Create the hosting view controller
        let hostingController = NSHostingController(rootView: menuView)
        
        // Create a custom responder to handle keyboard events
        let customResponder = MenuKeyboardResponder(menuView: menuView)
        hostingController.view.addSubview(customResponder)
        
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = NSWindow.Level.popUpMenu
        window.isMovable = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center the window on screen
        centerWindowOnScreen(window)
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // Make the custom responder the first responder
        window.makeFirstResponder(customResponder)
        
        // Store reference
        menuWindow = window
        
        // Set up event monitoring for auto-dismiss
        setupEventMonitoring()
    }
    
    func hideMenu() {
        print("🔧 ShortcutMenuController: Hiding menu")
        
        // Clean up event monitoring
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        
        // Close and remove window
        menuWindow?.close()
        menuWindow = nil
    }
    
    private func executeShortcut(_ shortcut: ShortcutConfiguration) {
        print("🔧 ShortcutMenuController: Executing shortcut: \(shortcut.name)")
        
        // Hide menu first
        hideMenu()
        
        // Handle screenshot timing if needed
        if shortcut.effectiveIncludeScreenshot {
            // Add a small delay to ensure menu is fully closed before screenshot
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task {
                    await self.textProcessor.processSelectedText(with: shortcut.prompt, shortcut: shortcut)
                }
            }
        } else {
            // Execute immediately for non-screenshot shortcuts
            Task {
                await self.textProcessor.processSelectedText(with: shortcut.prompt, shortcut: shortcut)
            }
        }
    }
    
    private func centerWindowOnScreen(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        
        let x = screenRect.midX - windowRect.width / 2
        let y = screenRect.midY - windowRect.height / 2
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func setupEventMonitoring() {
        // Monitor for clicks outside the menu to auto-dismiss
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.menuWindow else { return }
            
            let clickLocation = event.locationInWindow
            let windowFrame = window.frame
            
            // Check if click is outside the menu window
            if !windowFrame.contains(clickLocation) {
                self.hideMenu()
            }
        }
    }
    
    deinit {
        hideMenu()
    }
}

// Custom responder to handle keyboard events for the menu
class MenuKeyboardResponder: NSView {
    private let menuView: ShortcutMenuView
    
    init(menuView: ShortcutMenuView) {
        self.menuView = menuView
        super.init(frame: .zero)
        
        // Make this view accept first responder
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        menuView.handleKeyEvent(event)
    }
}

