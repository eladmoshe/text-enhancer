import Foundation

class OpenAIService: ObservableObject {
    private let configManager: ConfigurationManager
    private let urlSession: URLSessionProtocol
    private let cacheManager: ModelCacheManager
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    private let modelsURL = "https://api.openai.com/v1/models"
    private let maxTokens = 1000
    private let timeout: TimeInterval = 30.0
    
    init(configManager: ConfigurationManager, urlSession: URLSessionProtocol? = nil, cacheManager: ModelCacheManager = ModelCacheManager()) {
        self.configManager = configManager
        self.urlSession = urlSession ?? URLSession.shared
        self.cacheManager = cacheManager
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
                    print("❌ OpenAIService: Non-retryable error on attempt \(attempt): \(error)")
                    throw error
                }
                
                // Check if we have more attempts
                if !retryController.hasAttemptsRemaining {
                    print("❌ OpenAIService: Final attempt (\(attempt)) failed: \(error)")
                    break
                }
                
                // Post retry notification
                let retryInfo = RetryNotificationInfo(
                    attempt: attempt + 1, // Next attempt number
                    maxAttempts: retryController.maxAttempts,
                    provider: "OpenAI"
                )
                NotificationCenter.default.post(
                    name: .retryingOperation,
                    object: nil,
                    userInfo: ["retryInfo": retryInfo]
                )
                
                print("⚠️ OpenAIService: Attempt \(attempt) failed, retrying in \(retryController.delay(forAttempt: attempt))s: \(error)")
                
                // Wait before retrying
                let delay = retryController.delay(forAttempt: attempt)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // If we get here, all attempts failed
        throw lastError ?? OpenAIError.invalidResponse
    }
    
    private func performEnhanceText(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String {
        print("🔧 OpenAIService: Enhancing text (\(text.count) characters)")
        if screenContext != nil {
            print("🔧 OpenAIService: Including screen context")
        }
        
        guard let apiKey = configManager.openaiApiKey, !apiKey.isEmpty else {
            print("❌ OpenAIService: API key missing or empty")
            throw OpenAIError.missingApiKey
        }
        
        let request = try createRequest(text: text, prompt: prompt, apiKey: apiKey, model: model, screenContext: screenContext)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OpenAIError.apiError(httpResponse.statusCode, data)
        }
        
        let responseData = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = responseData.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        
        // Check if this is a screenshot-only request
        let isScreenshotOnly = text == "[Screenshot analysis requested]"
        
        if isScreenshotOnly {
            // For screenshot analysis, return the content directly
            return content
        } else {
            // For text enhancement, extract JSON from the response content
            do {
                let enhancementResponse = try JSONExtractor.extractJSONPayload(from: content)
                return enhancementResponse.enhancedText
            } catch {
                throw OpenAIError.invalidJSONResponse(error)
            }
        }
    }
    
    internal func createRequest(text: String, prompt: String, apiKey: String, model: String, screenContext: String? = nil) throws -> URLRequest {
        guard let url = URL(string: apiURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
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
            // Create multimodal message with screen context for vision-capable models
            let visionModel = model.contains("gpt-4") ? "gpt-4-vision-preview" : "gpt-4-vision-preview" // Use vision model for screenshots
            let messageContent = [
                OpenAIMessageContent(type: "image_url", image_url: OpenAIImageURL(url: "data:image/jpeg;base64,\(screenContext)")),
                OpenAIMessageContent(type: "text", text: textPrompt)
            ]
            
            let requestBody = OpenAIRequestMultimodal(
                model: visionModel,
                messages: [
                    OpenAIMessageMultimodal(role: "user", content: messageContent)
                ],
                max_tokens: maxTokens,
                temperature: 0.7
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        } else {
            // Use the simple text-only format for backward compatibility
            let requestBody = OpenAIRequest(
                model: model,
                messages: [
                    OpenAIMessage(role: "user", content: textPrompt)
                ],
                max_tokens: maxTokens,
                temperature: 0.7
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        }
        
        return request
    }
    
    func fetchAvailableModels() async throws -> [OpenAIModel] {
        print("🔧 OpenAIService: Fetching available models...")
        
        // Check cache first
        if let cachedModels = cacheManager.getCachedOpenAIModels() {
            print("✅ OpenAIService: Using cached models (\(cachedModels.count) models)")
            return cachedModels
        }
        
        print("🔧 OpenAIService: Cache miss or expired, fetching from API...")
        
        guard let apiKey = configManager.openaiApiKey, !apiKey.isEmpty else {
            print("❌ OpenAIService: API key missing for model fetching")
            throw OpenAIError.missingApiKey
        }
        
        guard let url = URL(string: modelsURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ OpenAIService: Invalid response type for models")
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ OpenAIService: Models API error (status: \(httpResponse.statusCode))")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ OpenAIService: Error details: \(errorString)")
            }
            throw OpenAIError.apiError(httpResponse.statusCode, data)
        }
        
        let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        
        // Filter models to include all relevant modern chat models for text and image processing
        let filteredModels = modelsResponse.data.filter { model in
            let lowerModelId = model.id.lowercased()
            
            // Exclude models that are clearly not for chat/completions
            let excludePatterns = [
                "whisper",          // Audio transcription
                "tts",              // Text-to-speech
                "dall-e",           // Image generation
                "text-embedding",   // Embeddings
                "text-moderation",  // Moderation
                "babbage",          // Legacy models
                "ada",              // Legacy models
                "curie",            // Legacy models
                "davinci",          // Legacy models (unless it's a newer instruct variant)
                "code-search",      // Code search
                "code-edit",        // Code editing
                "similarity",       // Similarity models
                "gpt-3.5",          // Outdated GPT-3.5 models
                "gpt-3-",           // Outdated GPT-3 models
                "gpt-2",            // Very old models
                "gpt-1"             // Very old models
            ]
            
            // Check if model should be excluded
            let shouldExclude = excludePatterns.contains { pattern in
                lowerModelId.contains(pattern.lowercased())
            }
            
            if shouldExclude {
                return false
            }
            
            // Include modern GPT models (GPT-4+, GPT-4o, GPT-5+, etc.)
            let isModernGPTModel = lowerModelId.hasPrefix("gpt-4") || 
                                  lowerModelId.hasPrefix("gpt-5") ||
                                  lowerModelId.hasPrefix("gpt-6") ||
                                  lowerModelId.hasPrefix("gpt-7") ||
                                  lowerModelId.hasPrefix("gpt-8") ||
                                  lowerModelId.hasPrefix("gpt-9") ||
                                  lowerModelId.hasPrefix("chatgpt")
            
            // Include all o1 models (reasoning models)
            let isO1Model = lowerModelId.hasPrefix("o1")
            
            // Include vision models (but exclude if they're old)
            let isVisionModel = lowerModelId.contains("vision") && !shouldExclude
            
            // Include any modern chat completion models
            let isChatModel = (lowerModelId.contains("chat") || 
                             lowerModelId.contains("instruct") ||
                             lowerModelId.contains("completion")) && !shouldExclude
            
            return isModernGPTModel || isO1Model || isVisionModel || isChatModel
        }
        
        // Sort models by relevance and capability (most capable first)
        let sortedModels = filteredModels.sorted { model1, model2 in
            let priority1 = getModelPriority(model1.id)
            let priority2 = getModelPriority(model2.id)
            return priority1 < priority2 // Lower priority number = higher priority
        }
        
        print("✅ OpenAIService: Fetched \(modelsResponse.data.count) models, filtered to \(sortedModels.count) relevant models")
        
        // Cache the filtered models
        cacheManager.cacheOpenAIModels(sortedModels)
        
        return sortedModels
    }
    
    private func getModelPriority(_ modelId: String) -> Int {
        // Pattern-based priority system (lower number = higher priority)
        
        // Extract version numbers for better sorting
        let lowerModelId = modelId.lowercased()
        
        // Future GPT models (GPT-5, GPT-6, etc.) - highest priority
        if lowerModelId.hasPrefix("gpt-5") { return 1 }
        if lowerModelId.hasPrefix("gpt-6") { return 1 }
        if lowerModelId.hasPrefix("gpt-7") { return 1 }
        if lowerModelId.hasPrefix("gpt-8") { return 1 }
        if lowerModelId.hasPrefix("gpt-9") { return 1 }
        
        // Current latest models
        if lowerModelId.hasPrefix("gpt-4o") { return 10 }
        if lowerModelId.hasPrefix("o1") { return 15 }
        
        // GPT-4 family
        if lowerModelId.hasPrefix("gpt-4") {
            if lowerModelId.contains("turbo") { return 20 }
            if lowerModelId.contains("vision") { return 22 }
            return 25 // Standard GPT-4
        }
        
        // Other GPT models that might slip through
        if lowerModelId.hasPrefix("gpt-") { return 60 }
        
        // Chat models
        if lowerModelId.contains("chat") { return 70 }
        if lowerModelId.contains("instruct") { return 75 }
        
        // Vision models
        if lowerModelId.contains("vision") { return 80 }
        
        // Everything else
        return 99
    }
}

// MARK: - Request/Response Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
    let temperature: Double
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Multimodal Request Models

struct OpenAIRequestMultimodal: Codable {
    let model: String
    let messages: [OpenAIMessageMultimodal]
    let max_tokens: Int
    let temperature: Double
}

struct OpenAIMessageMultimodal: Codable {
    let role: String
    let content: [OpenAIMessageContent]
}

struct OpenAIMessageContent: Codable {
    let type: String
    let text: String?
    let image_url: OpenAIImageURL?
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.image_url = nil
    }
    
    init(type: String, image_url: OpenAIImageURL) {
        self.type = type
        self.text = nil
        self.image_url = image_url
    }
}

struct OpenAIImageURL: Codable {
    let url: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}

struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

// MARK: - Models API Response

struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModel]
}

struct OpenAIModel: Codable, Identifiable {
    let id: String
    let object: String
    let created: Int
    let owned_by: String
    
    var displayName: String {
        // Make display names more user-friendly
        switch id {
        case "gpt-4o": return "GPT-4o"
        case "gpt-4o-mini": return "GPT-4o Mini"
        case "gpt-4-turbo": return "GPT-4 Turbo"
        case "gpt-4": return "GPT-4"
        case "gpt-3.5-turbo": return "GPT-3.5 Turbo"
        case "o1-preview": return "o1 Preview"
        case "o1-mini": return "o1 Mini"
        default:
            // For other models, capitalize and clean up the name
            return id.replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
        }
    }
}

// MARK: - Error Types

enum OpenAIError: Error {
    case missingApiKey
    case invalidURL
    case invalidResponse
    case apiError(Int, Data)
    case noContent
    case invalidJSONResponse(Error)
}

extension OpenAIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return """
            🔑 OpenAI API key missing or invalid
            
            Fix: Open Settings → Enter your OpenAI API key
            Get a key at: platform.openai.com/account/api-keys
            """
        case .invalidURL:
            return "⚠️ Invalid OpenAI API URL configuration"
        case .invalidResponse:
            return "⚠️ Invalid response from OpenAI API"
        case .apiError(let statusCode, let data):
            if statusCode == 401 {
                return """
                🔑 OpenAI API key invalid
                
                Your API key appears to be incorrect or expired.
                
                Fix: Check your API key at platform.openai.com
                Then update it in Settings below
                """
            } else if statusCode == 429 {
                return """
                ⏱️ Rate limit exceeded
                
                Too many requests to OpenAI API.
                Wait a moment and try again.
                """
            } else if statusCode >= 500 {
                return """
                🌐 OpenAI API temporarily unavailable
                
                Server error (HTTP \(statusCode)).
                This usually resolves quickly.
                """
            } else {
                if let errorMessage = String(data: data, encoding: .utf8) {
                    return "⚠️ OpenAI API error (\(statusCode)): \(errorMessage)"
                }
                return "⚠️ OpenAI API error with status code: \(statusCode)"
            }
        case .noContent:
            return "⚠️ No response content received from OpenAI API"
        case .invalidJSONResponse(let error):
            return "⚠️ Invalid response format from OpenAI: \(error.localizedDescription)"
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
            return "OpenAIError.missingApiKey"
        case .invalidURL:
            return "OpenAIError.invalidURL"
        case .invalidResponse:
            return "OpenAIError.invalidResponse"
        case .apiError(let statusCode, let data):
            let dataString = String(data: data, encoding: .utf8) ?? "No data"
            return "OpenAIError.apiError(\(statusCode), \(dataString))"
        case .noContent:
            return "OpenAIError.noContent"
        case .invalidJSONResponse(let error):
            return "OpenAIError.invalidJSONResponse(\(error))"
        }
    }
} 