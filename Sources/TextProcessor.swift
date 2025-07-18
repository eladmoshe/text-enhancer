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
        let isTrusted = AXIsProcessTrusted()
        
        // Also test actual accessibility capability
        if isTrusted {
            let systemWideElement = AXUIElementCreateSystemWide()
            var focusedElement: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            
            if result != .success {
                print("🔐 AccessibilityChecker: AXIsProcessTrusted=true but can't access focused element (result: \(result.rawValue))")
                return false
            }
        }
        
        return isTrusted
    }
    
    func requestAccessibilityPermissions() async {
        await MainActor.run {
            print("🔐 AccessibilityChecker: Requesting accessibility permissions...")
            
            // Try the direct approach first
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let newStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("🔐 AccessibilityChecker: Direct request result: \(newStatus)")
            
            // Also try through app delegate as backup
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
    func enhanceText(_ text: String, with prompt: String, using model: String) async throws -> String
    func enhanceText(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String
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
    private let screenCaptureService: ScreenCaptureService
    
    init(
        configManager: ConfigurationManager,
        textSelectionProvider: TextSelectionProvider = DefaultTextSelectionProvider(),
        textReplacer: TextReplacer? = nil,
        accessibilityChecker: AccessibilityChecker = DefaultAccessibilityChecker(),
        alertPresenter: AlertPresenter = DefaultAlertPresenter(),
        screenCaptureService: ScreenCaptureService = ScreenCaptureService()
    ) {
        self.configManager = configManager
        self.textSelectionProvider = textSelectionProvider
        self.accessibilityChecker = accessibilityChecker
        self.alertPresenter = alertPresenter
        self.screenCaptureService = screenCaptureService
        
        // Initialize text replacer with default pasteboard manager if not provided
        if let textReplacer = textReplacer {
            self.textReplacer = textReplacer
        } else {
            self.textReplacer = DefaultTextReplacer(pasteboardManager: DefaultPasteboardManager())
        }
    }
    
    func processSelectedText(with prompt: String) async {
        print("🔧 TextProcessor: processSelectedText called with prompt: '\(prompt)'")
        // Find the appropriate shortcut configuration
        let shortcut = configManager.configuration.shortcuts.first { $0.prompt == prompt }
        print("🔧 TextProcessor: Found shortcut: \(shortcut?.id ?? "none") for prompt: '\(prompt)'")
        let provider = shortcut?.effectiveProvider ?? .claude
        let model = shortcut?.effectiveModel ?? "claude-3-5-sonnet-20241022"
        
        await processSelectedText(with: prompt, using: provider, model: model)
    }
    
    func processSelectedText(with prompt: String, shortcut: ShortcutConfiguration) async {
        print("🔧 TextProcessor: Starting text processing with shortcut: \(shortcut.name)")
        await processSelectedText(with: prompt, using: shortcut.provider, model: shortcut.model)
    }
    
    func processSelectedText(with prompt: String, using provider: APIProvider, model: String) async {
        print("🔧 TextProcessor: Starting text processing with provider: \(provider) and model: \(model)")
        
        // Notify that processing has started
        NotificationCenter.default.post(name: .textProcessingStarted, object: nil)
        
        // Ensure we always send the finished notification
        defer {
            print("🔧 TextProcessor: Sending textProcessingFinished notification")
            NotificationCenter.default.post(name: .textProcessingFinished, object: nil)
        }
        
        // Add timeout to prevent hanging
        let timeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: 45_000_000_000) // 45 seconds
                print("⚠️  TextProcessor: Processing timeout reached (45 seconds)")
            } catch {
                // Timeout task was cancelled, which is expected
            }
        }
        
        let processingTask = Task {
            // Enhanced accessibility permissions check
            let basicTrusted = AXIsProcessTrusted()
            let enhancedCheck = accessibilityChecker.isAccessibilityEnabled()
            
            print("🔐 TextProcessor: Permission status - Basic: \(basicTrusted), Enhanced: \(enhancedCheck)")
            print("🔐 TextProcessor: Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
            print("🔐 TextProcessor: Bundle Path: \(Bundle.main.bundlePath)")
            
            if !enhancedCheck {
                print("🔐 TextProcessor: Accessibility permissions not sufficient, requesting...")
                
                // Try to request permissions
                await accessibilityChecker.requestAccessibilityPermissions()
                
                // Wait a moment and check again
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let recheck = accessibilityChecker.isAccessibilityEnabled()
                print("🔐 TextProcessor: After permission request - Enhanced check: \(recheck)")
                
                if !recheck {
                    // Give detailed diagnostic information
                    let errorMessage = """
                    Accessibility permissions are required but not working properly.
                    
                    Debug Info:
                    • Basic trusted: \(basicTrusted)
                    • Enhanced check: \(enhancedCheck)
                    • Bundle ID: \(Bundle.main.bundleIdentifier ?? "none")
                    • App Path: \(Bundle.main.bundlePath)
                    
                    Please:
                    1. Open System Settings > Privacy & Security > Accessibility
                    2. Remove TextEnhancer from the list (if present)
                    3. Add TextEnhancer again by clicking the '+' button
                    4. Make sure it's checked/enabled
                    5. Try the shortcut again
                    
                    If this persists, try restarting the app.
                    """
                    
                    await alertPresenter.showError(errorMessage)
                    return
                }
            }
            
            // Create appropriate API service
            guard let apiService = APIProviderFactory.createService(for: provider, configManager: configManager) else {
                await alertPresenter.showError("API provider \(provider.displayName) is not configured or enabled.")
                return
            }
            
            do {
                // Check if this is a screenshot-only shortcut
                let shortcut = configManager.configuration.shortcuts.first(where: { $0.prompt == prompt })
                
                let debugMsg = """
🔧 TextProcessor: Checking shortcut for prompt: '\(prompt)'
🔧 TextProcessor: Available shortcuts:
\(configManager.configuration.shortcuts.map { "🔧   - ID: '\($0.id)', Name: '\($0.name)', Prompt: '\($0.prompt)'" }.joined(separator: "\n"))
🔧 TextProcessor: Found shortcut: \(shortcut?.id ?? "none"), name: \(shortcut?.name ?? "none"), includeScreenshot: \(shortcut?.effectiveIncludeScreenshot ?? false)
"""
                print(debugMsg)
                
                // Also write to debug file
                try? debugMsg.appendingFormat("\n").write(to: URL(fileURLWithPath: "/Users/elad.moshe/my-code/text-llm-modify/debug.log"), atomically: true, encoding: .utf8)
                
                let isScreenshotOnly = shortcut?.effectiveIncludeScreenshot ?? false
                
                print("🔧 TextProcessor: Is screenshot-only mode: \(isScreenshotOnly)")
                print("🔧 TextProcessor: All shortcuts in config: \(configManager.configuration.shortcuts.map { "\($0.id):\($0.name)" })")
                
                let selectedText: String
                if isScreenshotOnly {
                    // For screenshot-only shortcuts, use a placeholder text
                    selectedText = "[Screenshot analysis requested]"
                    print("🔧 TextProcessor: Screenshot-only mode - no text selection required")
                } else {
                    // Get selected text for normal shortcuts
                    let text = textSelectionProvider.getSelectedText()
                    if text == nil || text!.isEmpty {
                        print("🔧 TextProcessor: No text selected and not screenshot-only mode")
                        await alertPresenter.showError("No text selected")
                        return
                    }
                    selectedText = text!
                    print("🔧 TextProcessor: Processing \(selectedText.count) characters")
                }
                
                // Capture screenshot if enabled for this shortcut
                var screenContext: String? = nil
                if let shortcut = configManager.configuration.shortcuts.first(where: { $0.prompt == prompt }),
                   shortcut.effectiveIncludeScreenshot {
                    
                    print("🔧 TextProcessor: Capturing screenshot for context")
                    if let screenshot = screenCaptureService.captureActiveScreen(),
                       let base64Image = screenCaptureService.convertImageToBase64(screenshot) {
                        screenContext = base64Image
                        print("✅ TextProcessor: Screenshot captured and encoded")
                    } else {
                        print("⚠️ TextProcessor: Failed to capture screenshot")
                        if isScreenshotOnly {
                            await alertPresenter.showError("Failed to capture screenshot. Please ensure the app has screen recording permissions.")
                            return
                        }
                    }
                }
                
                // Process with the appropriate API service
                let enhancedText: String
                if let screenContext = screenContext,
                   let claudeService = apiService as? ClaudeService {
                    enhancedText = try await claudeService.enhanceText(selectedText, with: prompt, using: model, screenContext: screenContext)
                } else {
                    enhancedText = try await apiService.enhanceText(selectedText, with: prompt, using: model)
                }
                
                // Replace selected text (or insert at cursor for screenshot-only mode)
                if isScreenshotOnly {
                    // For screenshot-only mode, insert the description at cursor position
                    await textReplacer.replaceSelectedText(with: enhancedText)
                    print("✅ TextProcessor: Screen description inserted at cursor")
                } else {
                    // Normal text replacement
                    await textReplacer.replaceSelectedText(with: enhancedText)
                    print("✅ TextProcessor: Text replacement completed")
                }
                
            } catch {
                print("❌ TextProcessor: Error during processing: \(error)")
                await alertPresenter.showError("Failed to enhance text: \(error.localizedDescription)")
            }
        }
        
        // Wait for either processing to complete or timeout
        _ = await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await processingTask.value
            }
            group.addTask {
                await timeoutTask.value
            }
            
            // Wait for the first task to complete
            await group.next()
            
            // Cancel the remaining tasks
            processingTask.cancel()
            timeoutTask.cancel()
        }
    }
} 