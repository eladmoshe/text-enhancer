import XCTest
@testable import TextEnhancer

final class ClaudeServiceTests: XCTestCase {
    var tempDir: TemporaryDirectory!
    var configManager: ConfigurationManager!
    var mockURLSession: URLSession!
    
    override func setUp() {
        super.setUp()
        tempDir = try! TemporaryDirectory()
        
        // Initialize configManager with test API key
        configManager = createConfigManager(with: "test-claude-api-key")
        
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
                claude: APIProviderConfig(apiKey: apiKey, model: "claude-4-sonnet", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-4o", enabled: false)
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
        // Given: Valid API key and successful response
        configManager = createConfigManager(with: "test-api-key")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        MockURLProtocol.requestHandler = { request in
            // Verify request properties
            XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            
            // Note: Request body validation is skipped here due to URLSession processing
            // The createRequest tests verify the body is created correctly
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            
            return (response, MockURLProtocol.mockClaudeSuccess(text: "Enhanced text"))
        }
        
        // When: Enhance text
        let result = try await claudeService.enhanceText("Hello world", with: "Test prompt", using: "claude-4-sonnet")
        
        // Then: Should return enhanced text
        XCTAssertEqual(result, "Enhanced text")
    }
    
    func test_enhanceText_missingApiKey() async {
        // Given: Empty API key
        configManager = createConfigManager(with: "")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Try to enhance text
        do {
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt", using: "claude-4-sonnet")
            XCTFail("Should have thrown missingApiKey error")
        } catch ClaudeError.missingApiKey {
            // Then: Should throw missing API key error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_enhanceText_apiError() async {
        // Given: Valid API key but API returns error
        configManager = createConfigManager(with: "test-api-key")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            
            let errorData = "API Error".data(using: .utf8)!
            return (response, errorData)
        }
        
        // When: Try to enhance text
        do {
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt", using: "claude-4-sonnet")
            XCTFail("Should have thrown apiError")
        } catch ClaudeError.apiError(let statusCode, _) {
            // Then: Should throw API error
            XCTAssertEqual(statusCode, 400)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_enhanceText_invalidResponse() async {
        // Given: Valid API key but invalid response format
        configManager = createConfigManager(with: "test-api-key")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            
            let invalidData = "Invalid JSON".data(using: .utf8)!
            return (response, invalidData)
        }
        
        // When: Try to enhance text
        do {
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt", using: "claude-4-sonnet")
            XCTFail("Should have thrown invalidResponse error")
        } catch {
            // Then: Should throw some error (JSON decoding will fail)
            XCTAssertTrue(true)
        }
    }
    
    func test_enhanceText_noContent() async {
        // Given: Valid API key but response has no content
        configManager = createConfigManager(with: "test-api-key")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            
            let emptyResponse = """
            {
                "content": [],
                "model": "claude-3-haiku-20240307",
                "role": "assistant",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 10, "output_tokens": 0}
            }
            """
            
            return (response, emptyResponse.data(using: .utf8)!)
        }
        
        // When: Try to enhance text
        do {
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt", using: "claude-4-sonnet")
            XCTFail("Should have thrown noContent error")
        } catch ClaudeError.noContent {
            // Then: Should throw no content error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_createRequest_setsCorrectHeaders() throws {
        // Given: Configuration and service
        configManager = createConfigManager(with: "test-api-key")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Create request
        let request = try claudeService.createRequest(text: "Hello world", prompt: "Improve this", apiKey: "test-key", model: "claude-4-sonnet")
        
        // Then: Should have correct headers
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.timeoutInterval, 30.0)
    }
    
    func test_createRequest_setsCorrectBody() throws {
        // Given: Configuration and service
        configManager = createConfigManager(with: "test-api-key")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Create request
        let request = try claudeService.createRequest(text: "Hello world", prompt: "Improve this", apiKey: "test-key", model: "claude-4-sonnet")
        
        // Then: Should have correct body
        XCTAssertNotNil(request.httpBody)
        
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "claude-4-sonnet")
        XCTAssertEqual(body["max_tokens"] as? Int, 1000)
        
        let messages = body["messages"] as! [[String: Any]]
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        
        let content = messages[0]["content"] as! String
        XCTAssertTrue(content.contains("Improve this"))
        XCTAssertTrue(content.contains("Hello world"))
        XCTAssertTrue(content.contains("Text to enhance:"))
    }
    
    func test_errorDescriptions() {
        XCTAssertEqual(ClaudeError.missingApiKey.errorDescription, """
            🔑 Claude API key missing or invalid
            
            Fix: Open Settings → Enter your Claude API key
            Get a key at: console.anthropic.com
            """)
        XCTAssertEqual(ClaudeError.invalidURL.errorDescription, "⚠️ Invalid API URL configuration")
        XCTAssertEqual(ClaudeError.invalidResponse.errorDescription, "⚠️ Invalid response from Claude API")
        XCTAssertEqual(ClaudeError.noContent.errorDescription, "⚠️ No response content received from Claude API")
        
        let errorData = "Error message".data(using: .utf8)!
        let apiError = ClaudeError.apiError(400, errorData)
        XCTAssertEqual(apiError.errorDescription, "⚠️ Claude API error (400): Error message")
    }
    
    // MARK: - Retry Tests
    
    func test_retryMechanism_networkError_retriesThreeTimes() async {
        // Given: A service with a mock session that always fails with network error
        let mockSession = MockURLSession()
        mockSession.shouldFail = true
        mockSession.error = URLError(.timedOut)
        
        let service = ClaudeService(configManager: configManager, urlSession: mockSession)
        
        // When: Calling enhanceText
        do {
            _ = try await service.enhanceText("test", with: "test", using: "claude-3-5-sonnet-20241022")
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should have attempted exactly 3 times
            XCTAssertEqual(mockSession.requestCount, 3)
            XCTAssertTrue(error is URLError)
        }
    }
    
    func test_retryMechanism_apiKeyError_doesNotRetry() async {
        // Given: A service with empty API key (non-retryable error)
        // Modify the existing configuration to have empty Claude API key
        let currentConfig = configManager.configuration
        let emptyClaudeConfig = APIProviderConfig(apiKey: "", model: "claude-3-5-sonnet-20241022", enabled: true)
        let modifiedApiProviders = APIProviders(claude: emptyClaudeConfig, openai: currentConfig.apiProviders.openai)
        
        let emptyKeyConfig = AppConfiguration(
            shortcuts: currentConfig.shortcuts,
            maxTokens: currentConfig.maxTokens,
            timeout: currentConfig.timeout,
            showStatusIcon: currentConfig.showStatusIcon,
            enableNotifications: currentConfig.enableNotifications,
            autoSave: currentConfig.autoSave,
            logLevel: currentConfig.logLevel,
            apiProviders: modifiedApiProviders
        )
        configManager.configuration = emptyKeyConfig
        
        let mockSession = MockURLSession()
        let service = ClaudeService(configManager: configManager, urlSession: mockSession)
        
        // When: Calling enhanceText
        do {
            _ = try await service.enhanceText("test", with: "test", using: "claude-3-5-sonnet-20241022")
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should not have made any network requests (fails before network call)
            XCTAssertEqual(mockSession.requestCount, 0)
            XCTAssertTrue(error is ClaudeError)
        }
    }
    
    func test_retryMechanism_serverError_retriesThreeTimes() async {
        // Given: A service with a mock session that returns 500 error
        let mockSession = MockURLSession()
        mockSession.shouldFail = false
        mockSession.responseStatusCode = 500
        mockSession.responseData = "Server Error".data(using: .utf8)!
        
        let service = ClaudeService(configManager: configManager, urlSession: mockSession)
        
        // When: Calling enhanceText
        do {
            _ = try await service.enhanceText("test", with: "test", using: "claude-3-5-sonnet-20241022")
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should have attempted exactly 3 times
            XCTAssertEqual(mockSession.requestCount, 3)
            if case ClaudeError.apiError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected ClaudeError.apiError")
            }
        }
    }
    
    func test_retryMechanism_successOnSecondAttempt() async {
        // Given: A service that fails once then succeeds
        let mockSession = MockURLSession()
        mockSession.shouldFailUntilAttempt = 2  // Fail on first attempt, succeed on second
        mockSession.error = URLError(.networkConnectionLost)
        
        // Configure success response for when it succeeds
        let successResponse = """
        {
            "content": [
                {
                    "type": "text",
                    "text": "{\\"enhancedText\\": \\"Enhanced text\\"}"
                }
            ],
            "model": "claude-3-5-sonnet-20241022",
            "role": "assistant",
            "usage": {
                "input_tokens": 10,
                "output_tokens": 5
            }
        }
        """
        mockSession.responseData = successResponse.data(using: .utf8)!
        
        let service = ClaudeService(configManager: configManager, urlSession: mockSession)
        
        // When: Calling enhanceText
        do {
            let result = try await service.enhanceText("test", with: "test", using: "claude-3-5-sonnet-20241022")
            
            // Then: Should succeed and have made exactly 2 attempts
            XCTAssertEqual(result, "Enhanced text")
            XCTAssertEqual(mockSession.requestCount, 2)
        } catch {
            XCTFail("Should not have thrown an error: \(error)")
        }
    }
} 