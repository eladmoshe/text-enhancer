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
        // For now, check if OpenAI API key is configured in the claudeApiKey field
        // TODO: Update configuration schema to support multiple API providers
        guard let apiKey = configManager.claudeApiKey, !apiKey.isEmpty else {
            throw OpenAIError.missingApiKey
        }
        
        let request = try createRequest(text: text, prompt: prompt, apiKey: apiKey)
        
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
        
        return content
    }
    
    internal func createRequest(text: String, prompt: String, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: apiURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        
        let fullPrompt = "\(prompt)\n\nText to enhance:\n\(text)"
        
        let requestBody = OpenAIRequest(
            model: defaultModel,
            messages: [
                OpenAIMessage(role: "user", content: fullPrompt)
            ],
            max_tokens: maxTokens,
            temperature: 0.7
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
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
        }
    }
} 