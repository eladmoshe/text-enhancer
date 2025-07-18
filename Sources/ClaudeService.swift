import Foundation

class ClaudeService: ObservableObject {
    private let configManager: ConfigurationManager
    private let urlSession: URLSession
    private let cacheManager: ModelCacheManager
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let modelsURL = "https://api.anthropic.com/v1/models"
    private let maxTokens = 1000
    private let timeout: TimeInterval = 30.0
    
    init(configManager: ConfigurationManager, urlSession: URLSession = .shared, cacheManager: ModelCacheManager = ModelCacheManager()) {
        self.configManager = configManager
        self.cacheManager = cacheManager
        
        // Create a custom URL session with timeout configuration
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = false
        
        self.urlSession = urlSession == .shared ? URLSession(configuration: configuration) : urlSession
    }
    
    func enhanceText(_ text: String, with prompt: String, using model: String) async throws -> String {
        return try await enhanceText(text, with: prompt, using: model, screenContext: nil)
    }
    
    func enhanceText(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String {
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
        
        // Check if this is a screenshot-only request
        let isScreenshotOnly = text == "[Screenshot analysis requested]"
        
        if isScreenshotOnly {
            // For screenshot analysis, return the content directly
            print("✅ ClaudeService: Screenshot analysis completed successfully")
            return content
        } else {
            // For text enhancement, extract JSON from the response content
            do {
                let enhancementResponse = try JSONExtractor.extractJSONPayload(from: content)
                print("✅ ClaudeService: Enhancement completed successfully")
                return enhancementResponse.enhancedText
            } catch {
                print("❌ ClaudeService: JSON extraction failed: \(error)")
                throw ClaudeError.invalidJSONResponse(error)
            }
        }
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
        }
    }
} 