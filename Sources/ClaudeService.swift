import Foundation

class ClaudeService: ObservableObject {
    private let configManager: ConfigurationManager
    private let urlSession: URLSession
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let modelName = "claude-3-haiku-20240307"
    private let maxTokens = 1000
    private let timeout: TimeInterval = 30.0
    
    init(configManager: ConfigurationManager, urlSession: URLSession = .shared) {
        self.configManager = configManager
        
        // Create a custom URL session with timeout configuration
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = false
        
        self.urlSession = urlSession == .shared ? URLSession(configuration: configuration) : urlSession
    }
    
    func enhanceText(_ text: String, with prompt: String) async throws -> String {
        return try await enhanceText(text, with: prompt, screenContext: nil)
    }
    
    func enhanceText(_ text: String, with prompt: String, screenContext: String?) async throws -> String {
        print("🔧 ClaudeService: Enhancing text (\(text.count) characters)")
        if screenContext != nil {
            print("🔧 ClaudeService: Including screen context")
        }
        
        guard let apiKey = configManager.claudeApiKey, !apiKey.isEmpty else {
            print("❌ ClaudeService: API key missing or empty")
            throw ClaudeError.missingApiKey
        }
        
        let request = try createRequest(text: text, prompt: prompt, apiKey: apiKey, screenContext: screenContext)
        
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
    
    internal func createRequest(text: String, prompt: String, apiKey: String, screenContext: String? = nil) throws -> URLRequest {
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
                model: modelName,
                max_tokens: maxTokens,
                messages: [
                    ClaudeMessageMultimodal(role: "user", content: messageContent)
                ]
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        } else {
            // Use the simple text-only format for backward compatibility
            let requestBody = ClaudeRequest(
                model: modelName,
                max_tokens: maxTokens,
                messages: [
                    ClaudeMessage(role: "user", content: textPrompt)
                ]
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        }
        
        return request
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
            return "Claude API key is missing. Please set it in Settings."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let statusCode, let data):
            if let errorString = String(data: data, encoding: .utf8) {
                return "Claude API error (\(statusCode)): \(errorString)"
            }
            return "Claude API error (\(statusCode))"
        case .noContent:
            return "No content received from Claude API"
        case .invalidJSONResponse(let error):
            return "Invalid JSON response from Claude: \(error.localizedDescription)"
        }
    }
} 