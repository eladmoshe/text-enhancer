import AppKit
import SwiftUI

class ShortcutMenuController: NSObject, ObservableObject, NSWindowDelegate {
    private var menuWindow: NSWindow?
    private var hostingController: NSHostingController<ShortcutMenuView>?
    private let configManager: ConfigurationManager
    private let textProcessor: TextProcessor
    private var eventMonitor: Any?
    
    init(configManager: ConfigurationManager, textProcessor: TextProcessor) {
        self.configManager = configManager
        self.textProcessor = textProcessor
        super.init()
    }
    
    func showMenu() {
        // Don't show menu if already visible
        if menuWindow != nil {
            return
        }
        
        let shortcuts = configManager.configuration.shortcuts
        
        // Don't show menu if no shortcuts are configured
        if shortcuts.isEmpty {
            NSLog("🔧 ShortcutMenuController: No shortcuts configured, not showing menu")
            return
        }
        
        NSLog("🔧 ShortcutMenuController: Showing menu with \(shortcuts.count) shortcuts")
        
        // Create the menu view
        let menuView = ShortcutMenuView(
            shortcuts: shortcuts,
            onSelectShortcut: { [weak self] shortcut in
                self?.executeShortcut(shortcut)
            },
            onDismiss: { [weak self] in
                // Defer hideMenu to next run loop to avoid UIKit/AppKit reentrancy crashes
                DispatchQueue.main.async {
                    self?.hideMenu()
                }
            }
        )
        
        // Create the hosting view controller
        let hostingController = NSHostingController(rootView: menuView)
        self.hostingController = hostingController
        
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isReleasedWhenClosed = false // Avoid premature deallocation that could cause crashes
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = NSWindow.Level.floating
        window.isMovable = true
        window.collectionBehavior = [.canJoinAllSpaces]
        window.delegate = self
        
        // Center the window on screen
        centerWindowOnScreen(window)
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // Store reference
        menuWindow = window
        
        // Add event monitor to detect clicks outside the window
        setupClickOutsideMonitor()
        
        NSLog("🔧 ShortcutMenuController: Window created and displayed")
    }
    
    func hideMenu() {
        guard let window = menuWindow else { return }
        NSLog("🔧 ShortcutMenuController: Hiding menu (orderOut)")

        // Remove event monitor
        removeClickOutsideMonitor()

        // Hide the window without destroying it immediately to avoid autorelease-pool crashes
        window.orderOut(nil)

        // Clean up after a slight delay to allow AppKit to finish its event processing safely
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.menuWindow = nil
            // Note: keep hostingController retained to avoid use-after-free in SwiftUI
        }
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        NSLog("🔧 ShortcutMenuController: Window will close")
        // Clean up references when window closes
        removeClickOutsideMonitor()
        menuWindow = nil
        // Keep hostingController retained to avoid potential SwiftUI deallocation timing crash
    }
    
    // MARK: - Click Outside Monitor
    private func setupClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.menuWindow else { return }
            
            // Get click location in screen coordinates
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            
            // Check if click is outside the window
            if !windowFrame.contains(clickLocation) {
                NSLog("🔧 ShortcutMenuController: Click outside detected, hiding menu")
                DispatchQueue.main.async {
                    self.hideMenu()
                }
            }
        }
    }
    
    private func removeClickOutsideMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func executeShortcut(_ shortcut: ShortcutConfiguration) {
        NSLog("🔧 ShortcutMenuController: Executing shortcut: \(shortcut.name)")
        
        // Hide menu first
        hideMenu()
        
        // Add safer execution with error handling
        Task { [weak self] in
            guard let self = self else { 
                NSLog("🔧 ShortcutMenuController: Self is nil, aborting execution")
                return 
            }
            
            do {
                NSLog("🔧 ShortcutMenuController: About to call textProcessor.processSelectedText")
                
                // Handle screenshot timing if needed
                if shortcut.effectiveIncludeScreenshot {
                    // Add a small delay to ensure menu is fully closed before screenshot
                    try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
                
                await self.textProcessor.processSelectedText(with: shortcut.prompt, shortcut: shortcut)

                NSLog("🔧 ShortcutMenuController: Successfully executed shortcut: \(shortcut.name)")
                
            } catch {
                NSLog("🔧 ShortcutMenuController: Error executing shortcut: \(error)")
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
    
    
    deinit {
        removeClickOutsideMonitor()
        hideMenu()
    }
}

