import XCTest
@testable import TextEnhancer

final class ClaudeServiceTests: XCTestCase {
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
                claude: APIProviderConfig(apiKey: apiKey, model: "claude-3-haiku-20240307", enabled: true),
                openai: APIProviderConfig(apiKey: "", model: "gpt-3.5-turbo", enabled: false)
            )
        )
        
        let configData = try! JSONEncoder().encode(config)
        try! configData.write(to: tempDir.configFile())
        
        return ConfigurationManager(
            localConfig: tempDir.configFile(),
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
        let result = try await claudeService.enhanceText("Hello world", with: "Test prompt")
        
        // Then: Should return enhanced text
        XCTAssertEqual(result, "Enhanced text")
    }
    
    func test_enhanceText_missingApiKey() async {
        // Given: Empty API key
        configManager = createConfigManager(with: "")
        let claudeService = ClaudeService(configManager: configManager, urlSession: mockURLSession)
        
        // When: Try to enhance text
        do {
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt")
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
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt")
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
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt")
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
            _ = try await claudeService.enhanceText("Hello world", with: "Test prompt")
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
        let request = try claudeService.createRequest(text: "Hello world", prompt: "Improve this", apiKey: "test-key")
        
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
        let request = try claudeService.createRequest(text: "Hello world", prompt: "Improve this", apiKey: "test-key")
        
        // Then: Should have correct body
        XCTAssertNotNil(request.httpBody)
        
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "claude-3-haiku-20240307")
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
        XCTAssertEqual(ClaudeError.missingApiKey.errorDescription, "Claude API key is missing. Please set it in Settings.")
        XCTAssertEqual(ClaudeError.invalidURL.errorDescription, "Invalid API URL")
        XCTAssertEqual(ClaudeError.invalidResponse.errorDescription, "Invalid response from Claude API")
        XCTAssertEqual(ClaudeError.noContent.errorDescription, "No content received from Claude API")
        
        let errorData = "Error message".data(using: .utf8)!
        let apiError = ClaudeError.apiError(400, errorData)
        XCTAssertEqual(apiError.errorDescription, "Claude API error (400): Error message")
    }
} 