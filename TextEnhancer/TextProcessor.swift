import AppKit
import ApplicationServices

// MARK: - URLSession Protocol for Testing

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - Retry Controller

class RetryController {
    let maxAttempts: Int = 3
    private(set) var currentAttempt: Int = 0
    
    init() {
        self.currentAttempt = 0
    }
    
    func reset() {
        currentAttempt = 0
    }
    
    func incrementAttempt() -> Int {
        currentAttempt += 1
        return currentAttempt
    }
    
    var hasAttemptsRemaining: Bool {
        return currentAttempt < maxAttempts
    }
    
    func delay(forAttempt attempt: Int) -> TimeInterval {
        switch attempt {
        case 1: return 0.0  // First retry immediately
        case 2: return 2.0  // Second retry after 2 seconds
        default: return 0.0 // No more retries
        }
    }
    
    func shouldRetry(error: Error) -> Bool {
        // Check for Claude/OpenAI specific errors
        if let claudeError = error as? ClaudeError {
            return claudeError.isNetworkRetryable
        }
        
        if let openaiError = error as? OpenAIError {
            return openaiError.isNetworkRetryable
        }
        
        // Check for URLSession errors
        if let urlError = error as? URLError {
            return isRetryableURLError(urlError)
        }
        
        return false
    }
    
    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .notConnectedToInternet,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let retryingOperation = Notification.Name("retryingOperation")
}

struct RetryNotificationInfo {
    let attempt: Int
    let maxAttempts: Int
    let provider: String
}

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

// MARK: - Alert Action Types

struct AlertAction {
    let title: String
    let style: NSAlert.Style
    let handler: () -> Void
    
    init(title: String, style: NSAlert.Style = .informational, handler: @escaping () -> Void = {}) {
        self.title = title
        self.style = style
        self.handler = handler
    }
    
    // Convenience factory methods
    static func ok() -> AlertAction {
        return AlertAction(title: "OK")
    }
    
    static func openSettings(configManager: ConfigurationManager) -> AlertAction {
        return AlertAction(title: "Open Settings") {
            DispatchQueue.main.async {
                SettingsWindowManager.shared.showSettings(configManager: configManager)
            }
        }
    }
    
    static func openSystemSettings(panel: String = "") -> AlertAction {
        return AlertAction(title: "Open System Settings") {
            let url: String
            if panel.isEmpty {
                url = "x-apple.systempreferences:"
            } else {
                url = "x-apple.systempreferences:\(panel)"
            }
            
            if let settingsURL = URL(string: url) {
                NSWorkspace.shared.open(settingsURL)
            }
        }
    }
    
    static func copyError(_ errorDetails: String) -> AlertAction {
        return AlertAction(title: "Copy Error Details") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(errorDetails, forType: .string)
        }
    }
}

protocol AlertPresenter {
    func showError(title: String, message: String, actions: [AlertAction]) async
    func showError(_ message: String) async  // Legacy support
}

// MARK: - Default Implementations

class DefaultTextSelectionProvider: TextSelectionProvider {
    func getSelectedText() -> String? {
        // Create a system-wide accessibility object
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // Get the focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let focusedElement = focusedElement,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }
        let axElement = unsafeBitCast(focusedElement, to: AXUIElement.self)
        
        // Try to get selected text from the focused element
        var selectedText: CFTypeRef?
        let selectedTextResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedText)
        
        if selectedTextResult == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }
        
        // If no selected text attribute, try to get the value and assume it's all selected
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value)
        
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
    private let configManager: ConfigurationManager
    
    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }
    
    @MainActor
    func showError(title: String, message: String, actions: [AlertAction]) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        
        // Add action buttons (in reverse order since NSAlert adds them right-to-left)
        for action in actions.reversed() {
            alert.addButton(withTitle: action.title)
        }
        
        let response = alert.runModal()
        
        // Handle button responses (NSApplication.ModalResponse.alertFirstButtonReturn = 1000)
        let buttonIndex = response.rawValue - 1000
        if buttonIndex >= 0 && buttonIndex < actions.count {
            actions[buttonIndex].handler()
        }
    }
    
    @MainActor
    func showError(_ message: String) async {
        // Legacy support - use simple OK dialog
        await showError(title: "TextEnhancer Error", message: message, actions: [.ok()])
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
        alertPresenter: AlertPresenter? = nil,
        screenCaptureService: ScreenCaptureService = ScreenCaptureService()
    ) {
        self.configManager = configManager
        self.textSelectionProvider = textSelectionProvider
        self.accessibilityChecker = accessibilityChecker
        self.alertPresenter = alertPresenter ?? DefaultAlertPresenter(configManager: configManager)
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
    
    // Helper method to create appropriate alert actions based on error type
    private func alertActions(for error: Error) -> [AlertAction] {
        var actions: [AlertAction] = []
        
        // Check if this is a Claude error that needs settings
        if let claudeError = error as? ClaudeError {
            if claudeError.needsSettingsAction {
                actions.append(.openSettings(configManager: configManager))
            }
            actions.append(.copyError(claudeError.technicalDetails))
        }
        // Check if this is an OpenAI error that needs settings
        else if let openaiError = error as? OpenAIError {
            if openaiError.needsSettingsAction {
                actions.append(.openSettings(configManager: configManager))
            }
            actions.append(.copyError(openaiError.technicalDetails))
        }
        // For other errors, just provide copy option
        else {
            actions.append(.copyError(error.localizedDescription))
        }
        
        // Always add OK button last
        actions.append(.ok())
        
        return actions
    }
    
    func processSelectedText(with prompt: String, using provider: APIProvider, model: String) async {
        print("🔧 TextProcessor: Starting text processing with provider: \(provider) and model: \(model)")
        print("🚀 TextProcessor: Version: \(AppVersion.fullVersion)")
        
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
                    await alertPresenter.showError(
                        title: "🔒 Accessibility Permission Required",
                        message: """
                        Accessibility permission is required for text selection and replacement.
                        
                        Debug Info:
                        • Basic trusted: \(basicTrusted)
                        • Enhanced check: \(enhancedCheck)
                        • Bundle ID: \(Bundle.main.bundleIdentifier ?? "none")
                        
                        Fix: System Settings → Privacy & Security → Accessibility
                        → Remove TextEnhancer (if present) → Add it again → Enable
                        
                        If this persists, try restarting the app.
                        """,
                        actions: [
                            .openSystemSettings(panel: "com.apple.preference.security"),
                            .ok()
                        ]
                    )
                    return
                }
            }
            
            // Create appropriate API service
            guard let apiService = APIProviderFactory.createService(for: provider, configManager: configManager) else {
                await alertPresenter.showError(
                    title: "🔑 API Key Required",
                    message: """
                    \(provider.displayName) API key is not configured.
                    
                    Fix: Open Settings → Enter your \(provider.displayName) API key
                    """,
                    actions: [
                        .openSettings(configManager: configManager),
                        .ok()
                    ]
                )
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
                    guard let text = textSelectionProvider.getSelectedText(), !text.isEmpty else {
                        print("🔧 TextProcessor: No text selected and not screenshot-only mode")
                        await alertPresenter.showError(
                            title: "📝 No Text Selected",
                            message: """
                            Please select some text before using this shortcut.
                            
                            Tip: Highlight the text you want to enhance, then use the shortcut.
                            """,
                            actions: [.ok()]
                        )
                        return
                    }
                    selectedText = text
                    print("🔧 TextProcessor: Processing \(selectedText.count) characters")
                }
                
                // Capture screenshot if enabled for this shortcut
                var screenContext: String? = nil
                let foundShortcut = configManager.configuration.shortcuts.first(where: { $0.prompt == prompt })
                print("🔧 TextProcessor: DEBUG - Looking for shortcut with prompt: '\(prompt)'")
                print("🔧 TextProcessor: DEBUG - Found shortcut: \(foundShortcut?.id ?? "nil")")
                print("🔧 TextProcessor: DEBUG - effectiveIncludeScreenshot: \(foundShortcut?.effectiveIncludeScreenshot ?? false)")
                
                if let shortcut = foundShortcut,
                   shortcut.effectiveIncludeScreenshot {
                    
                    print("🔧 TextProcessor: Capturing screenshot for context")
                    let debugMsg = "About to capture screenshot for shortcut: \(shortcut.id) at \(Date())\n"
                    try? debugMsg.appendingFormat("").write(to: URL(fileURLWithPath: "/Users/elad.moshe/my-code/text-llm-modify/debug.log"), atomically: false, encoding: .utf8)
                    if let screenshot = screenCaptureService.captureActiveScreen(),
                       let base64Image = screenCaptureService.convertImageToBase64(screenshot) {
                        screenContext = base64Image
                        print("✅ TextProcessor: Screenshot captured and encoded")
                    } else {
                        print("⚠️ TextProcessor: Failed to capture screenshot")
                        if isScreenshotOnly {
                            await alertPresenter.showError(
                                title: "📹 Screenshot Capture Failed",
                                message: """
                                Unable to capture screenshot for analysis.
                                
                                Fix: System Settings → Privacy & Security → Screen Recording
                                → Enable TextEnhancer
                                """,
                                actions: [
                                    .openSystemSettings(panel: "com.apple.preference.security"),
                                    .ok()
                                ]
                            )
                            return
                        }
                    }
                }
                
                // Process with the appropriate API service
                let enhancedText: String
                print("🔧 TextProcessor: DEBUG - About to call API service")
                print("🔧 TextProcessor: DEBUG - screenContext is \(screenContext == nil ? "NIL" : "NOT NIL")")
                if let screenContext = screenContext {
                    print("🔧 TextProcessor: DEBUG - screenContext length: \(screenContext.count)")
                    print("🔧 TextProcessor: DEBUG - Calling multimodal API")
                    // Pass the screen context to the API service for multimodal processing
                    enhancedText = try await apiService.enhanceText(selectedText, with: prompt, using: model, screenContext: screenContext)
                } else {
                    print("🔧 TextProcessor: DEBUG - screenContext is nil, calling text-only API")
                    // Fallback to text-only enhancement
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
                await alertPresenter.showError(
                    title: "❌ Enhancement Failed",
                    message: error.localizedDescription,
                    actions: alertActions(for: error)
                )
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