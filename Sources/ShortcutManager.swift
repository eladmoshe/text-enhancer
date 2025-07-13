import AppKit
import Carbon

class ShortcutManager: ObservableObject {
    private let textProcessor: TextProcessor
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    init(textProcessor: TextProcessor) {
        self.textProcessor = textProcessor
    }
    
    func registerShortcuts() {
        // Register the primary shortcut: Ctrl+Option+1
        registerHotKey(keyCode: 18, modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.handleShortcut1()
        }
    }
    
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let hotKeyHandler: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            let handler = Unmanaged<ClosureWrapper>.fromOpaque(userData).takeUnretainedValue()
            handler.closure()
            return noErr
        }
        
        let wrapper = ClosureWrapper(closure: handler)
        let userDataPtr = Unmanaged.passRetained(wrapper).toOpaque()
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyHandler,
            1,
            &eventType,
            userDataPtr,
            &eventHandler
        )
        
        if status == noErr {
            let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode(from: "TEnh")), id: 1)
            RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        }
    }
    
    private func handleShortcut1() {
        Task {
            await textProcessor.processSelectedText(with: .improveText)
        }
    }
    
    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

// Helper class to wrap closures for C callbacks
class ClosureWrapper {
    let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
}

// Helper function to convert string to FourCharCode
func fourCharCode(from string: String) -> UInt32 {
    let chars = Array(string.utf8)
    return UInt32(chars[0]) << 24 | UInt32(chars[1]) << 16 | UInt32(chars[2]) << 8 | UInt32(chars[3])
}

// Define enhancement types
enum EnhancementType {
    case improveText
    
    var prompt: String {
        switch self {
        case .improveText:
            return "Improve the writing quality and clarity of this text while maintaining its original meaning and tone."
        }
    }
} 