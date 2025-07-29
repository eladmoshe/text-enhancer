import AppKit
import Carbon

class ShortcutManager: ObservableObject {
    private let textProcessor: TextProcessor
    private let configManager: ConfigurationManager
    private var registeredShortcuts: [RegisteredShortcut] = []
    private var eventHandler: EventHandlerRef?
    private var masterShortcutRef: EventHotKeyRef?
    
    // Master shortcut menu controller
    private lazy var menuController: ShortcutMenuController = {
        ShortcutMenuController(configManager: configManager, textProcessor: textProcessor)
    }()
    
    init(textProcessor: TextProcessor, configManager: ConfigurationManager) {
        self.textProcessor = textProcessor
        self.configManager = configManager
        
        // Listen for configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationChanged),
            name: .configurationChanged,
            object: nil
        )
    }
    
    func registerShortcuts() {
        // Unregister existing shortcuts first
        unregisterAllShortcuts()
        
        // Register master shortcut (Ctrl+Option+Tab)
        registerMasterShortcut()
        
        // Register shortcuts from configuration
        for shortcut in configManager.configuration.shortcuts {
            registerShortcut(from: shortcut)
        }
    }
    
    private func registerMasterShortcut() {
        // Tab key is keyCode 48, Ctrl+Option modifiers
        let keyCode: UInt32 = 48 // Tab key
        let modifiers: UInt32 = UInt32(controlKey) | UInt32(optionKey)
        
        NSLog("🔧 ShortcutManager: Registering master shortcut (Ctrl+Option+Tab)")
        NSLog("🔧 ShortcutManager: Using keyCode: \(keyCode), modifiers: \(modifiers)")
        
        // Register the master shortcut with ID 0 (reserved for master)
        let masterHotKeyID = EventHotKeyID(signature: OSType(fourCharCode(from: "TEnh")), id: 0)
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            masterHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &masterShortcutRef
        )
        
        if status == noErr {
            NSLog("✅ Registered master shortcut: Ctrl+Option+Tab (keyCode: \(keyCode), modifiers: \(modifiers))")
        } else {
            NSLog("❌ Failed to register master shortcut: \(status) (keyCode: \(keyCode), modifiers: \(modifiers))")
        }
    }
    
    private func registerShortcut(from config: ShortcutConfiguration) {
        let keyCode = UInt32(config.keyCode)
        let modifiers = config.modifiers.reduce(0) { $0 | $1.carbonValue }
        
        // Check for conflicts
        if let existingShortcut = registeredShortcuts.first(where: { $0.keyCode == keyCode && $0.modifiers == modifiers }) {
            print("⚠️  Shortcut conflict detected: \(config.name) conflicts with \(existingShortcut.name)")
            return
        }
        
        let registeredShortcut = RegisteredShortcut(
            id: config.id,
            name: config.name,
            keyCode: keyCode,
            modifiers: modifiers,
            prompt: config.prompt,
            hotKeyRef: nil
        )
        
        if registerHotKey(for: registeredShortcut) {
            registeredShortcuts.append(registeredShortcut)
            print("✅ Registered shortcut: \(config.name) (\(formatShortcutDisplay(config.modifiers, config.keyCode)))")
        } else {
            print("❌ Failed to register shortcut: \(config.name)")
        }
    }
    
    private func registerHotKey(for shortcut: RegisteredShortcut) -> Bool {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let hotKeyHandler: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(theEvent, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if status == noErr {
                manager.handleShortcut(with: hotKeyID)
            }
            
            return noErr
        }
        
        // Install event handler only once
        if eventHandler == nil {
            let userDataPtr = Unmanaged.passUnretained(self).toOpaque()
            let status = InstallEventHandler(
                GetEventDispatcherTarget(),
                hotKeyHandler,
                1,
                &eventType,
                userDataPtr,
                &eventHandler
            )
            
            if status != noErr {
                return false
            }
        }
        
        // Register the specific hotkey
        let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode(from: "TEnh")), id: UInt32(registeredShortcuts.count + 1))
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let hotKeyRef = hotKeyRef {
            // Update the registered shortcut with the hotkey reference
            if let index = registeredShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
                registeredShortcuts[index].hotKeyRef = hotKeyRef
            }
            return true
        }
        
        return false
    }
    
    private func handleShortcut(with hotKeyID: EventHotKeyID) {
        NSLog("🔧 ShortcutManager: Hotkey event received - ID: \(hotKeyID.id), signature: \(hotKeyID.signature)")
        
        if hotKeyID.id == 0 {
            // Master shortcut triggered
            NSLog("🔧 ShortcutManager: Master shortcut triggered")
            handleMasterShortcut()
        } else {
            // Find the shortcut by index (ID-1 since we start IDs at 1)
            let index = Int(hotKeyID.id) - 1
            
            if index >= 0 && index < registeredShortcuts.count {
                NSLog("🔧 ShortcutManager: Triggered shortcut: \(registeredShortcuts[index].name)")
                handleShortcut(registeredShortcuts[index])
            } else {
                NSLog("⚠️  ShortcutManager: Invalid shortcut index: \(index)")
            }
        }
    }
    
    private func handleMasterShortcut() {
        NSLog("🔧 ShortcutManager: Showing master shortcut menu")
        menuController.showMenu()
    }
    
    func showMasterShortcutMenu() {
        NSLog("🔧 ShortcutManager: Master shortcut menu triggered from menu bar")
        menuController.showMenu()
    }
    
    private func handleShortcut(_ shortcut: RegisteredShortcut) {
        print("🔧 ShortcutManager: Shortcut triggered - \(shortcut.name)")
        
        Task {
            await textProcessor.processSelectedText(with: shortcut.prompt)
        }
    }
    
    private func unregisterAllShortcuts() {
        // Unregister master shortcut
        if let masterShortcutRef = masterShortcutRef {
            UnregisterEventHotKey(masterShortcutRef)
            self.masterShortcutRef = nil
        }
        
        // Unregister all other shortcuts
        for shortcut in registeredShortcuts {
            if let hotKeyRef = shortcut.hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }
        registeredShortcuts.removeAll()
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
    
    @objc private func configurationChanged() {
        print("🔄 ShortcutManager: Configuration changed, re-registering shortcuts")
        registerShortcuts()
    }
    
    deinit {
        unregisterAllShortcuts()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// Structure to hold registered shortcut information
struct RegisteredShortcut {
    let id: String
    let name: String
    let keyCode: UInt32
    let modifiers: UInt32
    let prompt: String
    var hotKeyRef: EventHotKeyRef?
}

// Helper function to convert string to FourCharCode
func fourCharCode(from string: String) -> UInt32 {
    let chars = Array(string.utf8)
    return UInt32(chars[0]) << 24 | UInt32(chars[1]) << 16 | UInt32(chars[2]) << 8 | UInt32(chars[3])
} 