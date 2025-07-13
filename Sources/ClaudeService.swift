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
        self.urlSession = urlSession
    }
    
    func enhanceText(_ text: String, with prompt: String) async throws -> String {
        guard let apiKey = configManager.claudeApiKey, !apiKey.isEmpty else {
            throw ClaudeError.missingApiKey
        }
        
        let request = try createRequest(text: text, prompt: prompt, apiKey: apiKey)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.apiError(httpResponse.statusCode, data)
        }
        
        let responseData = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        guard let content = responseData.content.first?.text else {
            throw ClaudeError.noContent
        }
        
        // Extract JSON from the response content
        do {
            let enhancementResponse = try JSONExtractor.extractJSONPayload(from: content)
            return enhancementResponse.enhancedText
        } catch {
            throw ClaudeError.invalidJSONResponse(error)
        }
    }
    
    internal func createRequest(text: String, prompt: String, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: apiURL) else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeout
        
        let fullPrompt = """
        \(prompt)
        
        Text to enhance:
        \(text)
        
        Respond ONLY with valid JSON exactly matching this schema:
        {
            "enhancedText": "<improved text>"
        }
        No additional keys, comments, markdown, or code fences.
        """
        
        let requestBody = ClaudeRequest(
            model: modelName,
            max_tokens: maxTokens,
            messages: [
                ClaudeMessage(role: "user", content: fullPrompt)
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
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