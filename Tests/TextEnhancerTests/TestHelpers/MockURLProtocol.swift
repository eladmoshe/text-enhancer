import Foundation
@testable import TextEnhancer

// MARK: - MockURLSession for Retry Testing

class MockURLSession: URLSessionProtocol {
    var shouldFail = false
    var shouldFailUntilAttempt: Int?
    var error: Error?
    var responseStatusCode: Int = 200
    var responseData: Data = Data()
    var requestCount = 0
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        
        // Check if we should fail until a certain attempt
        if let failUntilAttempt = shouldFailUntilAttempt {
            if requestCount < failUntilAttempt {
                if let error = error {
                    throw error
                } else {
                    throw URLError(.networkConnectionLost)
                }
            }
        } else if shouldFail {
            if let error = error {
                throw error
            } else {
                throw URLError(.networkConnectionLost)
            }
        }
        
        // Create mock response
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        
        let response = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (responseData, response)
    }
    
    func reset() {
        requestCount = 0
        shouldFail = false
        shouldFailUntilAttempt = nil
        error = nil
        responseStatusCode = 200
        responseData = Data()
    }
}

// MARK: - MockURLProtocol

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    static var responses: [String: (statusCode: Int, data: Data)] = [:]
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol: No request handler set")
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        // Nothing to do
    }
    
    // Helper method to create mock responses
    static func mockResponse(for url: String, statusCode: Int = 200, data: Data = Data()) {
        responses[url] = (statusCode: statusCode, data: data)
    }
    
    // Helper method to create Claude API success response
    static func mockClaudeSuccess(text: String) -> Data {
        let enhancedTextJSON = "{\"enhancedText\": \"\(text)\"}"
        
        let response = """
        {
            "content": [{"type": "text", "text": "\(enhancedTextJSON.replacingOccurrences(of: "\"", with: "\\\""))"}],
            "model": "claude-3-haiku-20240307",
            "role": "assistant",
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """
        return response.data(using: .utf8)!
    }
    
    // Helper method to create Claude API success response with prefix
    static func mockClaudeSuccessWithPrefix(text: String) -> Data {
        let responseWithPrefix = "Sure, here's the improved text:\n\n{\"enhancedText\": \"\(text)\"}"
        
        let escapedResponse = responseWithPrefix
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        let response = """
        {
            "content": [{"type": "text", "text": "\(escapedResponse)"}],
            "model": "claude-3-haiku-20240307",
            "role": "assistant",
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """
        return response.data(using: .utf8)!
    }
    
    // Helper method to create Claude API error response
    static func mockClaudeError(message: String) -> Data {
        let response = """
        {
            "error": {
                "type": "invalid_request_error",
                "message": "\(message)"
            }
        }
        """
        return response.data(using: .utf8)!
    }
    
    // Reset mock state
    static func reset() {
        requestHandler = nil
        responses.removeAll()
    }
} 