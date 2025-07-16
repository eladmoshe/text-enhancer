import AppKit
import Carbon

class ShortcutManager: ObservableObject {
    private let textProcessor: TextProcessor
    private let configManager: ConfigurationManager
    private var registeredShortcuts: [RegisteredShortcut] = []
    private var eventHandler: EventHandlerRef?
    
    init(textProcessor: TextProcessor, configManager: ConfigurationManager) {
        self.textProcessor = textProcessor
        self.configManager = configManager
    }
    
    func registerShortcuts() {
        // Unregister existing shortcuts first
        unregisterAllShortcuts()
        
        // Register shortcuts from configuration
        for shortcut in configManager.configuration.shortcuts {
            registerShortcut(from: shortcut)
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
        // Find the shortcut by index (ID-1 since we start IDs at 1)
        let index = Int(hotKeyID.id) - 1
        
        if index >= 0 && index < registeredShortcuts.count {
            print("🔧 ShortcutManager: Triggered shortcut: \(registeredShortcuts[index].name)")
            handleShortcut(registeredShortcuts[index])
        } else {
            print("⚠️  ShortcutManager: Invalid shortcut index: \(index)")
        }
    }
    
    private func handleShortcut(_ shortcut: RegisteredShortcut) {
        let debugMsg = "🔧 ShortcutManager: Shortcut triggered - ID: \(shortcut.id), Name: \(shortcut.name), Prompt: '\(shortcut.prompt)'"
        print(debugMsg)
        
        // Also write to debug file
        try? (debugMsg + "\n").write(to: URL(fileURLWithPath: "/Users/elad.moshe/my-code/text-llm-modify/debug.log"), atomically: false, encoding: .utf8)
        
        Task {
            await textProcessor.processSelectedText(with: shortcut.prompt)
        }
    }
    
    private func unregisterAllShortcuts() {
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
    
    deinit {
        unregisterAllShortcuts()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
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