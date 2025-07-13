import AppKit
import ApplicationServices

class TextProcessor: ObservableObject {
    private let claudeService: ClaudeService
    
    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }
    
    func processSelectedText(with enhancementType: EnhancementType) async {
        // Check accessibility permissions first
        let accessEnabled = AXIsProcessTrusted()
        if !accessEnabled {
            // Prompt for permissions only when user tries to use the feature
            await MainActor.run {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.promptForAccessibilityPermissions()
                }
            }
            
            // Check again after prompting
            guard AXIsProcessTrusted() else {
                await showError("Accessibility permissions are required to capture and replace text. Please grant permissions in System Settings > Privacy & Security > Accessibility.")
                return
            }
        }
        
        // Notify that processing has started
        NotificationCenter.default.post(name: .textProcessingStarted, object: nil)
        
        defer {
            // Notify that processing has finished
            NotificationCenter.default.post(name: .textProcessingFinished, object: nil)
        }
        
        do {
            // Get selected text
            guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
                await showError("No text selected")
                return
            }
            
            // Process with Claude
            let enhancedText = try await claudeService.enhanceText(selectedText, with: enhancementType.prompt)
            
            // Replace selected text
            await replaceSelectedText(with: enhancedText)
            
        } catch {
            await showError("Failed to enhance text: \(error.localizedDescription)")
        }
    }
    
    private func getSelectedText() -> String? {
        // Create a system-wide accessibility object
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // Get the focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let focusedElement = focusedElement else {
            return nil
        }
        
        // Try to get selected text from the focused element
        var selectedText: CFTypeRef?
        let selectedTextResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        
        if selectedTextResult == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }
        
        // If no selected text attribute, try to get the value and assume it's all selected
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXValueAttribute as CFString, &value)
        
        if valueResult == .success, let text = value as? String, !text.isEmpty {
            return text
        }
        
        return nil
    }
    
    private func replaceSelectedText(with newText: String) async {
        // Use the pasteboard to replace selected text
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            
            // Clear and set new text
            pasteboard.clearContents()
            pasteboard.setString(newText, forType: .string)
            
            // Simulate Cmd+V to paste
            simulateKeyPress(keyCode: 9, modifiers: [.maskCommand]) // V key with Cmd
            
            // Note: We don't restore original pasteboard contents to avoid the crash
            // This is a reasonable trade-off for a text enhancement tool
        }
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDownEvent?.flags = modifiers
        keyUpEvent?.flags = modifiers
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    @MainActor
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "TextEnhancer Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
} 