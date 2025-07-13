import AppKit
import ApplicationServices

// MARK: - Protocols

protocol TextSelectionProvider {
    func getSelectedText() -> String?
}

protocol TextReplacer {
    func replaceSelectedText(with newText: String) async
}

protocol AccessibilityChecker {
    func isAccessibilityEnabled() -> Bool
    func requestAccessibilityPermissions() async
}

protocol PasteboardManager {
    func setString(_ string: String)
    func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags)
}

protocol AlertPresenter {
    func showError(_ message: String) async
}

// MARK: - Default Implementations

class DefaultTextSelectionProvider: TextSelectionProvider {
    func getSelectedText() -> String? {
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
}

class DefaultTextReplacer: TextReplacer {
    private let pasteboardManager: PasteboardManager
    
    init(pasteboardManager: PasteboardManager) {
        self.pasteboardManager = pasteboardManager
    }
    
    func replaceSelectedText(with newText: String) async {
        await MainActor.run {
            pasteboardManager.setString(newText)
            pasteboardManager.simulateKeyPress(keyCode: 9, modifiers: [.maskCommand]) // V key with Cmd
        }
    }
}

class DefaultAccessibilityChecker: AccessibilityChecker {
    func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermissions() async {
        await MainActor.run {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.promptForAccessibilityPermissions()
            }
        }
    }
}

class DefaultPasteboardManager: PasteboardManager {
    func setString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
    
    func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDownEvent?.flags = modifiers
        keyUpEvent?.flags = modifiers
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
}

class DefaultAlertPresenter: AlertPresenter {
    @MainActor
    func showError(_ message: String) async {
        let alert = NSAlert()
        alert.messageText = "TextEnhancer Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - API Provider Protocol

protocol APIProviderService {
    func enhanceText(_ text: String, with prompt: String) async throws -> String
}

// MARK: - API Provider Factory

class APIProviderFactory {
    static func createService(for provider: APIProvider, configManager: ConfigurationManager) -> APIProviderService? {
        switch provider {
        case .claude:
            guard configManager.claudeApiKey != nil else { return nil }
            return ClaudeService(configManager: configManager)
        case .openai:
            guard configManager.openaiApiKey != nil else { return nil }
            return OpenAIService(configManager: configManager)
        }
    }
}

// MARK: - Extensions for API Provider Services

extension ClaudeService: APIProviderService {}
extension OpenAIService: APIProviderService {}

// MARK: - TextProcessor

class TextProcessor: ObservableObject {
    private let configManager: ConfigurationManager
    private let textSelectionProvider: TextSelectionProvider
    private let textReplacer: TextReplacer
    private let accessibilityChecker: AccessibilityChecker
    private let alertPresenter: AlertPresenter
    
    init(
        configManager: ConfigurationManager,
        textSelectionProvider: TextSelectionProvider = DefaultTextSelectionProvider(),
        textReplacer: TextReplacer? = nil,
        accessibilityChecker: AccessibilityChecker = DefaultAccessibilityChecker(),
        alertPresenter: AlertPresenter = DefaultAlertPresenter()
    ) {
        self.configManager = configManager
        self.textSelectionProvider = textSelectionProvider
        self.accessibilityChecker = accessibilityChecker
        self.alertPresenter = alertPresenter
        
        // Initialize text replacer with default pasteboard manager if not provided
        if let textReplacer = textReplacer {
            self.textReplacer = textReplacer
        } else {
            self.textReplacer = DefaultTextReplacer(pasteboardManager: DefaultPasteboardManager())
        }
    }
    
    func processSelectedText(with prompt: String) async {
        // Find the appropriate shortcut configuration
        let shortcut = configManager.configuration.shortcuts.first { $0.prompt == prompt }
        let provider = shortcut?.effectiveProvider ?? .claude
        
        await processSelectedText(with: prompt, using: provider)
    }
    
    func processSelectedText(with prompt: String, using provider: APIProvider) async {
        // Check accessibility permissions first
        if !accessibilityChecker.isAccessibilityEnabled() {
            await accessibilityChecker.requestAccessibilityPermissions()
            
            // Check again after prompting
            guard accessibilityChecker.isAccessibilityEnabled() else {
                await alertPresenter.showError("Accessibility permissions are required to capture and replace text. Please grant permissions in System Settings > Privacy & Security > Accessibility.")
                return
            }
        }
        
        // Create appropriate API service
        guard let apiService = APIProviderFactory.createService(for: provider, configManager: configManager) else {
            await alertPresenter.showError("API provider \(provider.displayName) is not configured or enabled.")
            return
        }
        
        // Notify that processing has started
        NotificationCenter.default.post(name: .textProcessingStarted, object: nil)
        
        defer {
            // Notify that processing has finished
            NotificationCenter.default.post(name: .textProcessingFinished, object: nil)
        }
        
        do {
            // Get selected text
            guard let selectedText = textSelectionProvider.getSelectedText(), !selectedText.isEmpty else {
                await alertPresenter.showError("No text selected")
                return
            }
            
            // Process with the appropriate API service
            let enhancedText = try await apiService.enhanceText(selectedText, with: prompt)
            
            // Replace selected text
            await textReplacer.replaceSelectedText(with: enhancedText)
            
        } catch {
            await alertPresenter.showError("Failed to enhance text: \(error.localizedDescription)")
        }
    }
} 