import Foundation

class OpenAIService: ObservableObject {
    private let configManager: ConfigurationManager
    private let urlSession: URLSession
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    private let defaultModel = "gpt-3.5-turbo"
    private let maxTokens = 1000
    private let timeout: TimeInterval = 30.0
    
    init(configManager: ConfigurationManager, urlSession: URLSession = .shared) {
        self.configManager = configManager
        self.urlSession = urlSession
    }
    
    func enhanceText(_ text: String, with prompt: String) async throws -> String {
        return try await enhanceText(text, with: prompt, screenContext: nil)
    }
    
    func enhanceText(_ text: String, with prompt: String, screenContext: String?) async throws -> String {
        print("🔧 OpenAIService: Enhancing text (\(text.count) characters)")
        if screenContext != nil {
            print("🔧 OpenAIService: Including screen context")
        }
        
        guard let apiKey = configManager.openaiApiKey, !apiKey.isEmpty else {
            print("❌ OpenAIService: API key missing or empty")
            throw OpenAIError.missingApiKey
        }
        
        let request = try createRequest(text: text, prompt: prompt, apiKey: apiKey, screenContext: screenContext)
        
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
    
    internal func createRequest(text: String, prompt: String, apiKey: String, screenContext: String? = nil) throws -> URLRequest {
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
            let model = "gpt-4-vision-preview" // Use vision model for screenshots
            let messageContent = [
                OpenAIMessageContent(type: "image_url", image_url: OpenAIImageURL(url: "data:image/jpeg;base64,\(screenContext)")),
                OpenAIMessageContent(type: "text", text: textPrompt)
            ]
            
            let requestBody = OpenAIRequestMultimodal(
                model: model,
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
                model: defaultModel,
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
            return "OpenAI API key is missing or empty"
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode, let data):
            if let errorMessage = String(data: data, encoding: .utf8) {
                return "OpenAI API error (\(statusCode)): \(errorMessage)"
            }
            return "OpenAI API error with status code: \(statusCode)"
        case .noContent:
            return "No content received from OpenAI API"
        case .invalidJSONResponse(let error):
            return "Invalid JSON response from OpenAI: \(error.localizedDescription)"
        }
    }
} 