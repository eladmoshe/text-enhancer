import XCTest
@testable import TextEnhancer

final class ModelCacheManagerTests: XCTestCase {
    private var cacheManager: ModelCacheManager!

    override func setUp() {
        super.setUp()
        cacheManager = ModelCacheManager()
        // Ensure a clean slate before each test
        cacheManager.clearCache()
    }

    override func tearDown() {
        // Clean up after each test to avoid polluting user environment
        cacheManager.clearCache()
        cacheManager = nil
        super.tearDown()
    }

    func testClaudeModelCaching() {
        // Given
        let formatter = ISO8601DateFormatter()
        let models = [
            ClaudeModel(
                id: "claude-model-test",
                display_name: "Claude Test",
                type: "test",
                created_at: formatter.string(from: Date())
            )
        ]
        // When
        cacheManager.cacheClaudeModels(models)
        let cached = cacheManager.getCachedClaudeModels()
        // Then
        XCTAssertNotNil(cached, "Expected cached Claude models to be non-nil after caching")
        XCTAssertEqual(cached?.count, 1)
        XCTAssertEqual(cached?.first?.id, models.first?.id)
    }

    func testOpenAIModelCaching() {
        // Given
        let models = [
            OpenAIModel(
                id: "gpt-4-test",
                object: "model",
                created: Int(Date().timeIntervalSince1970),
                owned_by: "openai"
            )
        ]
        // When
        cacheManager.cacheOpenAIModels(models)
        let cached = cacheManager.getCachedOpenAIModels()
        // Then
        XCTAssertNotNil(cached, "Expected cached OpenAI models to be non-nil after caching")
        XCTAssertEqual(cached?.count, 1)
        XCTAssertEqual(cached?.first?.id, models.first?.id)
    }

    func testClearCache() {
        // Populate cache first
        let claudeModels = [
            ClaudeModel(
                id: "claude-model-test",
                display_name: "Claude Test",
                type: "test",
                created_at: "2024-07-18T00:00:00Z"
            )
        ]
        let openaiModels = [
            OpenAIModel(
                id: "gpt-4-test",
                object: "model",
                created: Int(Date().timeIntervalSince1970),
                owned_by: "openai"
            )
        ]
        cacheManager.cacheClaudeModels(claudeModels)
        cacheManager.cacheOpenAIModels(openaiModels)
        // Ensure caches exist
        XCTAssertNotNil(cacheManager.getCachedClaudeModels())
        XCTAssertNotNil(cacheManager.getCachedOpenAIModels())
        // When
        cacheManager.clearCache()
        // Then
        XCTAssertNil(cacheManager.getCachedClaudeModels(), "Claude cache should be nil after clearing")
        XCTAssertNil(cacheManager.getCachedOpenAIModels(), "OpenAI cache should be nil after clearing")
    }

    func testGetCacheInfo() {
        // Fresh environment should report nil ages
        cacheManager.clearCache()
        var info = cacheManager.getCacheInfo()
        XCTAssertNil(info.claudeAge)
        XCTAssertNil(info.openaiAge)

        // After caching, ages should not be nil
        let models = [
            OpenAIModel(
                id: "gpt-4-test",
                object: "model",
                created: Int(Date().timeIntervalSince1970),
                owned_by: "openai"
            )
        ]
        cacheManager.cacheOpenAIModels(models)
        info = cacheManager.getCacheInfo()
        XCTAssertNotNil(info.openaiAge, "OpenAI cache age should be available after caching")
    }
} 