import XCTest
@testable import TextEnhancer

class JSONExtractorTests: XCTestCase {
    
    // MARK: - Pure JSON Tests
    
    func testPureJSONResponse() throws {
        let jsonResponse = """
        {
            "enhancedText": "This is improved text"
        }
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: jsonResponse)
        XCTAssertEqual(result.enhancedText, "This is improved text")
        XCTAssertNil(result.model)
        XCTAssertNil(result.notes)
    }
    
    func testJSONWithAllFields() throws {
        let jsonResponse = """
        {
            "enhancedText": "Enhanced content",
            "model": "claude-3-haiku",
            "notes": "Minor grammatical improvements"
        }
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: jsonResponse)
        XCTAssertEqual(result.enhancedText, "Enhanced content")
        XCTAssertEqual(result.model, "claude-3-haiku")
        XCTAssertEqual(result.notes, "Minor grammatical improvements")
    }
    
    // MARK: - Markdown Code Block Tests
    
    func testJSONInMarkdownCodeBlock() throws {
        let response = """
        ```json
        {
            "enhancedText": "Cleaned up text"
        }
        ```
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Cleaned up text")
    }
    
    func testJSONInCodeBlockWithLanguage() throws {
        let response = """
        Here's the JSON response:
        
        ```json
        {
            "enhancedText": "Better text",
            "model": "gpt-3.5-turbo"
        }
        ```
        
        Hope this helps!
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Better text")
        XCTAssertEqual(result.model, "gpt-3.5-turbo")
    }
    
    func testJSONInPlainCodeBlock() throws {
        let response = """
        ```
        {
            "enhancedText": "Text from plain code block"
        }
        ```
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Text from plain code block")
    }
    
    // MARK: - Prefix Handling Tests
    
    func testClaudeStylePrefix() throws {
        let response = """
        Sure, here's the improved text:
        
        {
            "enhancedText": "This text has been enhanced"
        }
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "This text has been enhanced")
    }
    
    func testLongPrefix() throws {
        let response = """
        I'll help you improve this text. Here's my enhanced version following your requirements:
        
        {
            "enhancedText": "Much better text now",
            "notes": "Improved clarity and flow"
        }
        
        The changes focus on readability and engagement.
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Much better text now")
        XCTAssertEqual(result.notes, "Improved clarity and flow")
    }
    
    func testMultilinePrefix() throws {
        let response = """
        I understand you want me to enhance this text.
        Let me provide an improved version.
        Here's the result:
        
        {
            "enhancedText": "Significantly improved text"
        }
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Significantly improved text")
    }
    
    // MARK: - Whitespace and Formatting Tests
    
    func testExtraWhitespace() throws {
        let response = """
        
        
            {
                "enhancedText": "Text with extra whitespace"
            }
        
        
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Text with extra whitespace")
    }
    
    func testMinifiedJSON() throws {
        let response = "{\"enhancedText\":\"Minified JSON text\"}"
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Minified JSON text")
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyEnhancedText() throws {
        let response = """
        {
            "enhancedText": ""
        }
        """
        
        XCTAssertThrowsError(try JSONExtractor.extractJSONPayload(from: response)) { error in
            XCTAssertTrue(error is JSONParseError)
            if case JSONParseError.missingRequiredField(let field) = error {
                XCTAssertEqual(field, "enhancedText")
            }
        }
    }
    
    func testMissingEnhancedTextField() throws {
        let response = """
        {
            "model": "claude-3-haiku",
            "notes": "Missing main field"
        }
        """
        
        XCTAssertThrowsError(try JSONExtractor.extractJSONPayload(from: response)) { error in
            XCTAssertTrue(error is JSONParseError)
            if case JSONParseError.invalidJSON = error {
                // This is expected - JSONDecoder will fail on missing required field
            }
        }
    }
    
    func testInvalidJSON() throws {
        let response = """
        {
            "enhancedText": "Invalid JSON"
            "missing": "comma"
        }
        """
        
        XCTAssertThrowsError(try JSONExtractor.extractJSONPayload(from: response)) { error in
            XCTAssertTrue(error is JSONParseError)
            if case JSONParseError.invalidJSON = error {
                // This is expected
            }
        }
    }
    
    func testNoJSONContent() throws {
        let response = "This is just plain text with no JSON content"
        
        XCTAssertThrowsError(try JSONExtractor.extractJSONPayload(from: response)) { error in
            XCTAssertTrue(error is JSONParseError)
            if case JSONParseError.invalidJSON = error {
                // This is expected when no valid JSON is found
            }
        }
    }
    
    func testEmptyResponse() throws {
        let response = ""
        
        XCTAssertThrowsError(try JSONExtractor.extractJSONPayload(from: response)) { error in
            XCTAssertTrue(error is JSONParseError)
        }
    }
    
    // MARK: - Edge Cases
    
    func testJSONWithEscapedQuotes() throws {
        let response = """
        {
            "enhancedText": "Text with \\"escaped quotes\\" works fine"
        }
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Text with \"escaped quotes\" works fine")
    }
    
    func testJSONWithNewlines() throws {
        let response = """
        {
            "enhancedText": "Text with\\nembedded\\nnewlines"
        }
        """
        
        let result = try JSONExtractor.extractJSONPayload(from: response)
        XCTAssertEqual(result.enhancedText, "Text with\nembedded\nnewlines")
    }
    
    func testMultipleJSONObjects() throws {
        let response = """
        Here's some invalid JSON: {"wrong": "format"}
        
        But here's the correct one:
        {
            "enhancedText": "This is the correct response"
        }
        """
        
        // The extractor should find the first valid JSON object
        // In this case, it will find {"wrong": "format"} first
        // This should fail because it doesn't have the required "enhancedText" field
        XCTAssertThrowsError(try JSONExtractor.extractJSONPayload(from: response)) { error in
            XCTAssertTrue(error is JSONParseError)
            if case JSONParseError.invalidJSON = error {
                // This is expected - the first JSON object doesn't have the required field
            }
        }
    }
} 