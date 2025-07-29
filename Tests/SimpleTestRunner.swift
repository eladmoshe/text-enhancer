#!/usr/bin/env swift

import Foundation

// Simple test framework that doesn't depend on XCTest
class SimpleTestRunner {
    private var testCount = 0
    private var passCount = 0
    private var failCount = 0
    
    func run() {
        print("🧪 Running TextEnhancer Tests")
        print("=" * 50)
        
        testConfigurationManager()
        testClaudeService()
        
        print("\n" + "=" * 50)
        print("📊 Test Results:")
        print("   Total: \(testCount)")
        print("   ✅ Passed: \(passCount)")
        print("   ❌ Failed: \(failCount)")
        
        if failCount == 0 {
            print("🎉 All tests passed!")
        } else {
            print("💥 Some tests failed!")
        }
    }
    
    private func assert(_ condition: Bool, _ message: String) {
        testCount += 1
        if condition {
            passCount += 1
            print("✅ \(message)")
        } else {
            failCount += 1
            print("❌ \(message)")
        }
    }
    
    private func testConfigurationManager() {
        print("\n📋 Testing ConfigurationManager...")
        
        // Test default configuration
        let tempDir = createTempDirectory()
        let configManager = ConfigurationManager(
            localConfig: tempDir.appendingPathComponent("config.json"),
            appSupportDir: tempDir
        )
        
        assert(configManager.configuration.claudeApiKey == "", "Default API key should be empty")
        assert(configManager.configuration.maxTokens == 1000, "Default max tokens should be 1000")
        assert(configManager.configuration.timeout == 30.0, "Default timeout should be 30.0")
        assert(configManager.configuration.showStatusIcon == true, "Default show status icon should be true")
        assert(configManager.configuration.shortcuts.count == 1, "Default shortcuts count should be 1")
        assert(configManager.claudeApiKey == nil, "claudeApiKey should return nil for empty string")
        
        // Test saving and loading
        let testConfig = AppConfiguration(
            claudeApiKey: "test-key",
            shortcuts: [],
            maxTokens: 2000,
            timeout: 60.0,
            showStatusIcon: false,
            autoSave: false,
            logLevel: "debug"
        )
        
        configManager.saveConfiguration(testConfig)
        
        let newConfigManager = ConfigurationManager(
            localConfig: tempDir.appendingPathComponent("config.json"),
            appSupportDir: tempDir
        )
        
        assert(newConfigManager.configuration.claudeApiKey == "test-key", "Saved API key should persist")
        assert(newConfigManager.configuration.maxTokens == 2000, "Saved max tokens should persist")
        assert(newConfigManager.claudeApiKey == "test-key", "claudeApiKey should return saved value")
        
        cleanup(tempDir)
    }
    
    private func testClaudeService() {
        print("\n🤖 Testing ClaudeService...")
        
        let tempDir = createTempDirectory()
        let configManager = ConfigurationManager(
            localConfig: tempDir.appendingPathComponent("config.json"),
            appSupportDir: tempDir
        )
        
        // Test with empty API key
        let claudeService = ClaudeService(configManager: configManager)
        
        // Test request creation (this should work without network)
        do {
            let request = try claudeService.createRequest(
                text: "Hello world",
                prompt: "Improve this",
                apiKey: "test-key"
            )
            
            assert(request.url?.absoluteString == "https://api.anthropic.com/v1/messages", "Request URL should be correct")
            assert(request.httpMethod == "POST", "Request method should be POST")
            assert(request.value(forHTTPHeaderField: "Content-Type") == "application/json", "Content-Type should be application/json")
            assert(request.value(forHTTPHeaderField: "x-api-key") == "test-key", "API key header should be set")
            assert(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01", "Anthropic version should be set")
            assert(request.timeoutInterval == 30.0, "Timeout should be 30.0")
            assert(request.httpBody != nil, "Request body should not be nil")
            
        } catch {
            assert(false, "Request creation should not throw error: \(error)")
        }
        
        cleanup(tempDir)
    }
    
    private func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextEnhancerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// Extension to repeat strings (for visual formatting)
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// Import the TextEnhancer module (this will work when we build)
// For now, we'll need to copy the relevant classes here or build differently

// Run the tests
let runner = SimpleTestRunner()
runner.run() 