import Foundation

class ClaudeService: ObservableObject {
    private let configManager: ConfigurationManager
    private let urlSession: URLSessionProtocol
    private let cacheManager: ModelCacheManager
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let modelsURL = "https://api.anthropic.com/v1/models"
    private let maxTokens = 1000
    private let timeout: TimeInterval = 30.0
    
    init(configManager: ConfigurationManager, urlSession: URLSessionProtocol? = nil, cacheManager: ModelCacheManager = ModelCacheManager()) {
        self.configManager = configManager
        self.cacheManager = cacheManager
        
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            // Create a custom URL session with timeout configuration
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30.0
            configuration.timeoutIntervalForResource = 60.0
            configuration.waitsForConnectivity = false
            
            self.urlSession = URLSession(configuration: configuration)
        }
    }
    
    func enhanceText(_ text: String, with prompt: String, using model: String) async throws -> String {
        return try await enhanceTextWithRetry(text, with: prompt, using: model, screenContext: nil)
    }
    
    func enhanceText(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String {
        return try await enhanceTextWithRetry(text, with: prompt, using: model, screenContext: screenContext)
    }
    
    // MARK: - Retry Logic
    
    private func enhanceTextWithRetry(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String {
        let retryController = RetryController()
        var lastError: Error?
        
        while retryController.hasAttemptsRemaining {
            let attempt = retryController.incrementAttempt()
            
            do {
                return try await performEnhanceText(text, with: prompt, using: model, screenContext: screenContext)
            } catch {
                lastError = error
                
                // Check if this error should be retried
                if !retryController.shouldRetry(error: error) {
                    print("❌ ClaudeService: Non-retryable error on attempt \(attempt): \(error)")
                    throw error
                }
                
                // Check if we have more attempts
                if !retryController.hasAttemptsRemaining {
                    print("❌ ClaudeService: Final attempt (\(attempt)) failed: \(error)")
                    break
                }
                
                // Post retry notification
                let retryInfo = RetryNotificationInfo(
                    attempt: attempt + 1, // Next attempt number
                    maxAttempts: retryController.maxAttempts,
                    provider: "Claude"
                )
                NotificationCenter.default.post(
                    name: .retryingOperation,
                    object: nil,
                    userInfo: ["retryInfo": retryInfo]
                )
                
                print("⚠️ ClaudeService: Attempt \(attempt) failed, retrying in \(retryController.delay(forAttempt: attempt))s: \(error)")
                
                // Wait before retrying
                let delay = retryController.delay(forAttempt: attempt)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // If we get here, all attempts failed
        throw lastError ?? ClaudeError.invalidResponse
    }
    
    private func performEnhanceText(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String {
        print("🔧 ClaudeService: Enhancing text (\(text.count) characters)")
        if screenContext != nil {
            print("🔧 ClaudeService: Including screen context")
        }
        
        guard let apiKey = configManager.claudeApiKey, !apiKey.isEmpty else {
            print("❌ ClaudeService: API key missing or empty")
            throw ClaudeError.missingApiKey
        }
        
        let request = try createRequest(text: text, prompt: prompt, apiKey: apiKey, model: model, screenContext: screenContext)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ClaudeService: Invalid response type")
            throw ClaudeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ ClaudeService: API error (status: \(httpResponse.statusCode))")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ ClaudeService: Error details: \(errorString)")
            }
            throw ClaudeError.apiError(httpResponse.statusCode, data)
        }
        
        let responseData = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        guard let content = responseData.content.first?.text else {
            print("❌ ClaudeService: No content in response")
            throw ClaudeError.noContent
        }
        
        // Request Context Classification System
        let requestContext = classifyRequestContext(text: text, screenContext: screenContext)
        debugLog("Request classified as: \(requestContext)")
        
        switch requestContext {
        case .screenshotOnly, .mixedMode:
            // For screenshot analysis or multimodal requests, return the content directly as plain text
            debugLog("Returning plain text response for \(requestContext) request")
            print("✅ ClaudeService: Screenshot/multimodal analysis completed successfully")
            return content
            
        case .textOnly:
            // For text enhancement only, extract JSON from the response content
            debugLog("Extracting JSON response for text-only request")
            do {
                let enhancementResponse = try JSONExtractor.extractJSONPayload(from: content)
                print("✅ ClaudeService: Enhancement completed successfully")
                return enhancementResponse.enhancedText
            } catch {
                debugLog("JSON extraction failed: \(error)")
                print("❌ ClaudeService: JSON extraction failed: \(error)")
                
                // Context-aware error messages for better user experience
                let contextAwareError = createContextAwareError(
                    originalError: error, 
                    text: text, 
                    prompt: prompt, 
                    screenContext: screenContext,
                    content: content
                )
                throw contextAwareError
            }
        }
    }
    
    // MARK: - Context-Aware Error Handling
    
    private func createContextAwareError(originalError: Error, text: String, prompt: String, screenContext: String?, content: String) -> ClaudeError {
        // Analyze the request context to provide helpful error messages
        let hasScreenContext = screenContext != nil && !screenContext!.isEmpty
        
        // Check if this looks like a screenshot-related request but has no screen context
        let isScreenshotRelatedText = isScreenshotRelated(text: text) || isScreenshotRelated(text: prompt)
        
        if isScreenshotRelatedText && !hasScreenContext {
            let message = """
            🖼️ Screenshot analysis requested but no screenshot provided
            
            It looks like you're trying to analyze a screenshot, but the system couldn't find one.
            """
            
            let suggestion = """
            Try this:
            • Use Ctrl+Option+6 for screenshot analysis (captures screen automatically)
            • Use Ctrl+Option+7 for text-only expansion
            
            Current shortcut behavior:
            • Ctrl+Option+6: Screenshot analysis with screen capture
            • Ctrl+Option+7: Text expansion without screenshots
            """
            
            return ClaudeError.invalidJSONResponseWithContext(message, suggestion)
        }
        
        // Check if this might be a text request that should use the screenshot shortcut
        if !hasScreenContext && containsJSONHints(in: content) {
            let message = """
            ⚠️ Invalid response format from Claude
            
            Expected structured JSON response but received plain text.
            """
            
            let suggestion = """
            This might help:
            • For screenshot analysis: Use Ctrl+Option+6 (automatically captures screen)
            • For text expansion: Use Ctrl+Option+7 (works with selected text)
            • For AI analysis of images: Use Ctrl+Option+6 with visual content
            
            The response format suggests this might need screenshot context.
            """
            
            return ClaudeError.invalidJSONResponseWithContext(message, suggestion)
        }
        
        // Default enhanced error with context
        let message = """
        ⚠️ Invalid response format from Claude
        
        The AI response couldn't be processed as expected.
        """
        
        let suggestion = """
        Quick fixes:
        • Ctrl+Option+6: Screenshot analysis (with automatic screen capture)
        • Ctrl+Option+7: Text expansion (selected text only)
        
        If this keeps happening, try the other shortcut or check your API key in Settings.
        """
        
        return ClaudeError.invalidJSONResponseWithContext(message, suggestion)
    }
    
    private func isScreenshotRelated(text: String) -> Bool {
        let screenshotKeywords = ["screenshot", "screen", "image", "picture", "visual", "see", "display", "window", "interface", "UI", "analyze what you see"]
        let lowercaseText = text.lowercased()
        return screenshotKeywords.contains { lowercaseText.contains($0) }
    }
    
    private func containsJSONHints(in content: String) -> Bool {
        // Check if the response looks like it might contain JSON-like structures but failed parsing
        let jsonHints = ["{", "}", "\"key\":", "\"value\":", "enhancedText", "analysis"]
        return jsonHints.contains { content.contains($0) }
    }

    // MARK: - Request Context Classification
    
    private enum RequestContext {
        case screenshotOnly    // Only screenshot, no meaningful text input
        case textOnly         // Only text, no screenshot 
        case mixedMode        // Both text and screenshot
    }
    
    private func classifyRequestContext(text: String, screenContext: String?) -> RequestContext {
        // Enhanced context detection with proper empty string handling
        let hasValidScreenContext = screenContext != nil && !screenContext!.isEmpty
        let isScreenshotOnlyRequest = text == "[Screenshot analysis requested]"
        let hasValidTextInput = !text.isEmpty && !isScreenshotOnlyRequest
        
        debugLog("Context classification - text: '\(text.prefix(50))...', screenContext: \(screenContext != nil ? "present" : "nil"), isEmpty: \(screenContext?.isEmpty ?? true)")
        debugLog("hasValidScreenContext: \(hasValidScreenContext), isScreenshotOnlyRequest: \(isScreenshotOnlyRequest), hasValidTextInput: \(hasValidTextInput)")
        
        if hasValidScreenContext && hasValidTextInput {
            // Both valid text and screenshot context
            debugLog("Classified as mixedMode")
            return .mixedMode
        } else if hasValidScreenContext || isScreenshotOnlyRequest {
            // Screenshot only (either explicit marker or just screenshot without meaningful text)
            debugLog("Classified as screenshotOnly")
            return .screenshotOnly
        } else {
            // Text only (no screenshot context)
            debugLog("Classified as textOnly")
            return .textOnly
        }
    }
    
    // MARK: - Structured Debug Logging
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("🔧 ClaudeService: \(message)")
        #endif
    }
    
    internal func createRequest(text: String, prompt: String, apiKey: String, model: String, screenContext: String? = nil) throws -> URLRequest {
        guard let url = URL(string: apiURL) else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let basePrompt: String
        let isScreenshotOnly = text == "[Screenshot analysis requested]"
        
        if isScreenshotOnly {
            // Screenshot-only mode - use prompt as-is
            basePrompt = prompt
        } else {
            // Normal text enhancement mode
            basePrompt = """
            \(prompt)
            
            Text to enhance:
            \(text)
            """
        }
        
        let textPrompt: String
        if isScreenshotOnly {
            // For screenshot analysis, don't require JSON format
            textPrompt = basePrompt
        } else {
            // For text enhancement, require JSON format
            let jsonInstructions = """
            
            CRITICAL: You must respond with ONLY a valid JSON object. No explanations, no markdown, no code blocks, no additional text.
            
            Required JSON format:
            {"enhancedText": "your enhanced text here"}
            
            Do not include any text before or after the JSON object.
            """
            textPrompt = basePrompt + jsonInstructions
        }
        
        if let screenContext = screenContext {
            // Create multimodal message with screen context
            let messageContent = [
                ClaudeMessageContent(type: "image", source: ClaudeImageSource(type: "base64", media_type: "image/jpeg", data: screenContext)),
                ClaudeMessageContent(type: "text", text: textPrompt)
            ]
            
            let requestBody = ClaudeRequestMultimodal(
                model: model,
                max_tokens: maxTokens,
                messages: [
                    ClaudeMessageMultimodal(role: "user", content: messageContent)
                ]
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        } else {
            // Use the simple text-only format for backward compatibility
            let requestBody = ClaudeRequest(
                model: model,
                max_tokens: maxTokens,
                messages: [
                    ClaudeMessage(role: "user", content: textPrompt)
                ]
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        }
        
        return request
    }
    
    func fetchAvailableModels() async throws -> [ClaudeModel] {
        print("🔧 ClaudeService: Fetching available models...")
        
        // Check cache first
        if let cachedModels = cacheManager.getCachedClaudeModels() {
            print("✅ ClaudeService: Using cached models (\(cachedModels.count) models)")
            return cachedModels
        }
        
        print("🔧 ClaudeService: Cache miss or expired, fetching from API...")
        
        guard let apiKey = configManager.claudeApiKey, !apiKey.isEmpty else {
            print("❌ ClaudeService: API key missing for model fetching")
            throw ClaudeError.missingApiKey
        }
        
        guard let url = URL(string: modelsURL) else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ClaudeService: Invalid response type for models")
            throw ClaudeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ ClaudeService: Models API error (status: \(httpResponse.statusCode))")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ ClaudeService: Error details: \(errorString)")
            }
            throw ClaudeError.apiError(httpResponse.statusCode, data)
        }
        
        let modelsResponse = try JSONDecoder().decode(ClaudeModelsResponse.self, from: data)
        
        // Filter models to only include those from the last year
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let filteredModels = modelsResponse.data.filter { model in
            let formatter = ISO8601DateFormatter()
            if let createdDate = formatter.date(from: model.created_at) {
                return createdDate >= oneYearAgo
            }
            return true // Include models with unparseable dates to be safe
        }
        
        print("✅ ClaudeService: Fetched \(modelsResponse.data.count) models, filtered to \(filteredModels.count) recent models")
        
        // Cache the filtered models
        cacheManager.cacheClaudeModels(filteredModels)
        
        return filteredModels
    }
}

// MARK: - Request/Response Models

struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Multimodal Request Models

struct ClaudeRequestMultimodal: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessageMultimodal]
}

struct ClaudeMessageMultimodal: Codable {
    let role: String
    let content: [ClaudeMessageContent]
}

struct ClaudeMessageContent: Codable {
    let type: String
    let text: String?
    let source: ClaudeImageSource?
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.source = nil
    }
    
    init(type: String, source: ClaudeImageSource) {
        self.type = type
        self.text = nil
        self.source = source
    }
}

struct ClaudeImageSource: Codable {
    let type: String
    let media_type: String
    let data: String
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
    let model: String
    let role: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: ClaudeUsage
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

struct ClaudeUsage: Codable {
    let input_tokens: Int
    let output_tokens: Int
}

// MARK: - Models API Response

struct ClaudeModelsResponse: Codable {
    let data: [ClaudeModel]
}

struct ClaudeModel: Codable, Identifiable {
    let id: String
    let display_name: String
    let type: String
    let created_at: String
    
    var displayName: String {
        return display_name
    }
}

// MARK: - Error Types

enum ClaudeError: LocalizedError {
    case missingApiKey
    case invalidURL
    case invalidResponse
    case apiError(Int, Data)
    case noContent
    case invalidJSONResponse(Error)
    case contextMismatch(String)
    case invalidJSONResponseWithContext(String, String)
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return """
            🔑 Claude API key missing or invalid
            
            Fix: Open Settings → Enter your Claude API key
            Get a key at: console.anthropic.com
            """
        case .invalidURL:
            return "⚠️ Invalid API URL configuration"
        case .invalidResponse:
            return "⚠️ Invalid response from Claude API"
        case .apiError(let statusCode, let data):
            if statusCode == 401 {
                return """
                🔑 Claude API key invalid
                
                Your API key appears to be incorrect or expired.
                
                Fix: Check your API key at console.anthropic.com
                Then update it in Settings below
                """
            } else if statusCode == 429 {
                return """
                ⏱️ Rate limit exceeded
                
                Too many requests to Claude API.
                Wait a moment and try again.
                """
            } else if statusCode >= 500 {
                return """
                🌐 Claude API temporarily unavailable
                
                Server error (HTTP \(statusCode)).
                This usually resolves quickly.
                """
            } else {
                if let errorString = String(data: data, encoding: .utf8) {
                    return "⚠️ Claude API error (\(statusCode)): \(errorString)"
                }
                return "⚠️ Claude API error (\(statusCode))"
            }
        case .noContent:
            return "⚠️ No response content received from Claude API"
        case .invalidJSONResponse(let error):
            return "⚠️ Invalid response format from Claude: \(error.localizedDescription)"
        case .contextMismatch(let message):
            return message
        case .invalidJSONResponseWithContext(let message, let suggestion):
            return "\(message)\n\n💡 \(suggestion)"
        }
    }
    
    // Helper to determine what actions should be available
    var needsSettingsAction: Bool {
        switch self {
        case .missingApiKey, .apiError(401, _):
            return true
        default:
            return false
        }
    }
    
    var isNetworkRetryable: Bool {
        switch self {
        case .apiError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429
        case .invalidResponse:
            return true
        default:
            return false
        }
    }
    
    var technicalDetails: String {
        switch self {
        case .missingApiKey:
            return "ClaudeError.missingApiKey"
        case .invalidURL:
            return "ClaudeError.invalidURL"
        case .invalidResponse:
            return "ClaudeError.invalidResponse"
        case .apiError(let statusCode, let data):
            let dataString = String(data: data, encoding: .utf8) ?? "No data"
            return "ClaudeError.apiError(\(statusCode), \(dataString))"
        case .noContent:
            return "ClaudeError.noContent"
        case .invalidJSONResponse(let error):
            return "ClaudeError.invalidJSONResponse(\(error))"
        case .contextMismatch(let message):
            return "ClaudeError.contextMismatch(\(message))"
        case .invalidJSONResponseWithContext(let message, let suggestion):
            return "ClaudeError.invalidJSONResponseWithContext(\(message), \(suggestion))"
        }
    }
} 