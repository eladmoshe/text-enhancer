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
            shortcuts: [],
            maxTokens: 1000,
            timeout: 30.0,
            showStatusIcon: true,
            enableNotifications: true,
            autoSave: true,
            logLevel: "info",
            apiProviders: APIProviders(
                claude: APIProviderConfig(apiKey: "", model: "claude-3-haiku-20240307", enabled: false),
                openai: APIProviderConfig(apiKey: apiKey, model: "gpt-3.5-turbo", enabled: true)
            )
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! tempDir.createAppSupportDirectory()
        try! configData.write(to: tempDir.appSupportDirectory().appendingPathComponent("config.json"))
        
        return ConfigurationManager(
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
        let result = try await service.enhanceText("Test text", with: "Test prompt", using: "gpt-4o")
        
        // Then: Should return enhanced text
        XCTAssertEqual(result, "Enhanced text content")
    }
    
    func test_enhanceText_missingApiKey() async {
        // Given: Configuration with no API key
        configManager = createConfigManager(with: "")
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Try to enhance text
        do {
            _ = try await service.enhanceText("Test text", with: "Test prompt", using: "gpt-4o")
            XCTFail("Should have thrown missingApiKey error")
        } catch OpenAIError.missingApiKey {
            // Then: Should throw missing API key error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_enhanceText_apiError() async {
        // Given: Valid API key but API returns error
        configManager = createConfigManager(with: "test-api-key")
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let errorData = "Unauthorized".data(using: .utf8)!
            return (response, errorData)
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Try to enhance text
        do {
            _ = try await service.enhanceText("Test text", with: "Test prompt", using: "gpt-4o")
            XCTFail("Should have thrown apiError")
        } catch OpenAIError.apiError(let statusCode, _) {
            // Then: Should throw API error with correct status code
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_enhanceText_invalidResponse() async {
        // Given: Valid API key but invalid response format
        configManager = createConfigManager(with: "test-api-key")
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let invalidData = "Invalid JSON".data(using: .utf8)!
            return (response, invalidData)
        }
        
        let service = OpenAIService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Try to enhance text
        do {
            _ = try await service.enhanceText("Test text", with: "Test prompt", using: "gpt-4o")
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should throw some error (JSON decoding will fail)
            XCTAssertTrue(true)
        }
    }
    
    func test_enhanceText_noContent() async {
        // Given: Valid API key but response has no content
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
        
        // When: Try to enhance text
        do {
            _ = try await service.enhanceText("Test text", with: "Test prompt", using: "gpt-4o")
            XCTFail("Should have thrown noContent error")
        } catch OpenAIError.noContent {
            // Then: Should throw no content error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_createRequest_setsCorrectHeaders() throws {
        // Given: OpenAI service with configuration
        configManager = createConfigManager(with: "test-api-key")
        let service = OpenAIService(configManager: configManager)
        
        // When: Create request
        let request = try service.createRequest(text: "Test text", prompt: "Test prompt", apiKey: "test-key", model: "gpt-4o")
        
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
        let request = try service.createRequest(text: "Test text", prompt: "Test prompt", apiKey: "test-key", model: "gpt-4o")
        
        // Then: Should set correct body
        XCTAssertNotNil(request.httpBody)
        
        let requestBody = try JSONDecoder().decode(OpenAIRequest.self, from: request.httpBody!)
        XCTAssertEqual(requestBody.model, "gpt-4o")
        XCTAssertEqual(requestBody.max_tokens, 1000)
        XCTAssertEqual(requestBody.temperature, 0.7)
        XCTAssertEqual(requestBody.messages.count, 1)
        XCTAssertEqual(requestBody.messages[0].role, "user")
        XCTAssertTrue(requestBody.messages[0].content.contains("Test prompt"))
        XCTAssertTrue(requestBody.messages[0].content.contains("Test text"))
    }
} 