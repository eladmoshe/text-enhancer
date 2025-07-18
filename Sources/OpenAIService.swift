import Foundation

class OpenAIService: ObservableObject {
    private let configManager: ConfigurationManager
    private let urlSession: URLSession
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    private let modelsURL = "https://api.openai.com/v1/models"
    private let maxTokens = 1000
    private let timeout: TimeInterval = 30.0
    
    init(configManager: ConfigurationManager, urlSession: URLSession = .shared) {
        self.configManager = configManager
        self.urlSession = urlSession
    }
    
    func enhanceText(_ text: String, with prompt: String, using model: String) async throws -> String {
        return try await enhanceText(text, with: prompt, using: model, screenContext: nil)
    }
    
    func enhanceText(_ text: String, with prompt: String, using model: String, screenContext: String?) async throws -> String {
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
        
        // Filter models to only include chat models from the last year
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let filteredModels = modelsResponse.data.filter { model in
            // Only include models that are suitable for chat completions
            let isChatModel = model.id.contains("gpt") || model.id.contains("o1")
            
            // Check if model is from the last year
            let createdDate = Date(timeIntervalSince1970: TimeInterval(model.created))
            let isRecent = createdDate >= oneYearAgo
            
            return isChatModel && isRecent
        }
        
        print("✅ OpenAIService: Fetched \(modelsResponse.data.count) models, filtered to \(filteredModels.count) recent chat models")
        return filteredModels
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