import XCTest
@testable import TextEnhancer

final class OpenAIServiceTests: XCTestCase {
    var tempDir: TemporaryDirectory!
    var configManager: ConfigurationManager!
    var mockURLSession: URLSession!
    
    override func setUp() {
        super.setUp()
        tempDir = try! TemporaryDirectory()
        
        // Create a mock URL session configuration
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockURLSession = URLSession(configuration: config)
        
        // Reset mock protocol
        MockURLProtocol.reset()
    }
    
    override func tearDown() {
        tempDir.cleanup()
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    func createConfigManager(with apiKey: String) -> ConfigurationManager {
        let config = AppConfiguration(
            claudeApiKey: apiKey,
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: nil
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! configData.write(to: tempDir.configFile())
        
        return ConfigurationManager(
            localConfig: tempDir.configFile(),
            appSupportDir: tempDir.appSupportDirectory()
        )
    }
    
    func test_enhanceText_success() async throws {
        // Given: Valid configuration and successful API response
        configManager = createConfigManager(with: "test-api-key")
        
        let mockResponse = """
        {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": "{\\"enhancedText\\": \\"Enhanced text content\\"}"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 5,
                "total_tokens": 15
            }
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
            
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, mockResponse.data(using: .utf8)!)
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Enhance text
        let result = try await service.enhanceText("Test text", with: "Test prompt")
        
        // Then: Should return enhanced text
        XCTAssertEqual(result, "Enhanced text content")
    }
    
    func test_enhanceText_missingApiKeyThrows() async throws {
        // Given: Empty API key
        configManager = createConfigManager(with: "")
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When/Then: Should throw missing API key error
        do {
            let _ = try await service.enhanceText("Test text", with: "Test prompt")
            XCTFail("Expected OpenAIError.missingApiKey to be thrown")
        } catch OpenAIError.missingApiKey {
            // Expected
        } catch {
            XCTFail("Expected OpenAIError.missingApiKey, got \(error)")
        }
    }
    
    func test_enhanceText_apiError401Throws() async throws {
        // Given: Valid configuration but 401 response
        configManager = createConfigManager(with: "invalid-key")
        
        let mockErrorResponse = """
        {
            "error": {
                "message": "Invalid API key",
                "type": "invalid_request_error"
            }
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, mockErrorResponse.data(using: .utf8)!)
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When/Then: Should throw API error
        do {
            let _ = try await service.enhanceText("Test text", with: "Test prompt")
            XCTFail("Expected OpenAIError.apiError to be thrown")
        } catch OpenAIError.apiError(let statusCode, _) {
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Expected OpenAIError.apiError, got \(error)")
        }
    }
    
    func test_enhanceText_apiError500Throws() async throws {
        // Given: Valid configuration but 500 response
        configManager = createConfigManager(with: "test-api-key")
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Internal server error".data(using: .utf8)!)
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When/Then: Should throw API error
        do {
            let _ = try await service.enhanceText("Test text", with: "Test prompt")
            XCTFail("Expected OpenAIError.apiError to be thrown")
        } catch OpenAIError.apiError(let statusCode, _) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected OpenAIError.apiError, got \(error)")
        }
    }
    
    func test_enhanceText_invalidResponseThrows() async throws {
        // Given: Valid configuration but invalid response
        configManager = createConfigManager(with: "test-api-key")
        
        MockURLProtocol.requestHandler = { request in
            // Return non-HTTP response (shouldn't happen in practice)
            // We need to throw an error since URLResponse can't be cast to HTTPURLResponse
            throw OpenAIError.invalidResponse
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When/Then: Should throw an error (the exact error depends on URLSession behavior)
        do {
            let _ = try await service.enhanceText("Test text", with: "Test prompt")
            XCTFail("Should have thrown an error")
        } catch {
            // Expected - any error is fine since we're simulating invalid response
            XCTAssertTrue(true, "Expected error was thrown: \(error)")
        }
    }
    
    func test_enhanceText_noContentThrows() async throws {
        // Given: Valid configuration but response without content
        configManager = createConfigManager(with: "test-api-key")
        
        let mockResponse = """
        {
            "choices": [],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 0,
                "total_tokens": 10
            }
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, mockResponse.data(using: .utf8)!)
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When/Then: Should throw no content error
        do {
            let _ = try await service.enhanceText("Test text", with: "Test prompt")
            XCTFail("Expected OpenAIError.noContent to be thrown")
        } catch OpenAIError.noContent {
            // Expected
        } catch {
            XCTFail("Expected OpenAIError.noContent, got \(error)")
        }
    }
    
    func test_createRequest_setsCorrectHeaders() throws {
        // Given: OpenAI service with configuration
        configManager = createConfigManager(with: "test-api-key")
        let service = OpenAIService(configManager: configManager)
        
        // When: Create request
        let request = try service.createRequest(text: "Test text", prompt: "Test prompt", apiKey: "test-key")
        
        // Then: Should set correct headers
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.timeoutInterval, 30.0)
    }
    
    func test_createRequest_setsCorrectBody() throws {
        // Given: OpenAI service with configuration
        configManager = createConfigManager(with: "test-api-key")
        let service = OpenAIService(configManager: configManager)
        
        // When: Create request
        let request = try service.createRequest(text: "Test text", prompt: "Test prompt", apiKey: "test-key")
        
        // Then: Should set correct body
        XCTAssertNotNil(request.httpBody)
        
        let requestBody = try JSONDecoder().decode(OpenAIRequest.self, from: request.httpBody!)
        XCTAssertEqual(requestBody.model, "gpt-3.5-turbo")
        XCTAssertEqual(requestBody.max_tokens, 1000)
        XCTAssertEqual(requestBody.temperature, 0.7)
        XCTAssertEqual(requestBody.messages.count, 1)
        XCTAssertEqual(requestBody.messages[0].role, "user")
        XCTAssertTrue(requestBody.messages[0].content.contains("Test prompt"))
        XCTAssertTrue(requestBody.messages[0].content.contains("Test text"))
    }
    
    func test_errorDescriptions() {
        // Test error descriptions
        XCTAssertEqual(OpenAIError.missingApiKey.localizedDescription, "OpenAI API key is missing or empty")
        XCTAssertEqual(OpenAIError.invalidURL.localizedDescription, "Invalid OpenAI API URL")
        XCTAssertEqual(OpenAIError.invalidResponse.localizedDescription, "Invalid response from OpenAI API")
        XCTAssertEqual(OpenAIError.noContent.localizedDescription, "No content received from OpenAI API")
        
        let apiError = OpenAIError.apiError(404, "Not found".data(using: .utf8)!)
        XCTAssertTrue(apiError.localizedDescription.contains("404"))
        XCTAssertTrue(apiError.localizedDescription.contains("Not found"))
    }
} 