import Foundation

class ModelCacheManager {
    private let cacheDirectory: URL
    private let claudeCacheFile: URL
    private let openaiCacheFile: URL
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("TextEnhancer").appendingPathComponent("ModelCache")
        claudeCacheFile = cacheDirectory.appendingPathComponent("claude_models.json")
        openaiCacheFile = cacheDirectory.appendingPathComponent("openai_models.json")

        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Cache Data Models

    private struct CachedModels<T: Codable>: Codable {
        let models: [T]
        let cachedAt: Date

        var isExpired: Bool {
            Date().timeIntervalSince(cachedAt) > 24 * 60 * 60 // 24 hours
        }
    }

    // MARK: - Claude Model Caching

    func getCachedClaudeModels() -> [ClaudeModel]? {
        guard let cachedModels: CachedModels<ClaudeModel> = loadCachedModels(from: claudeCacheFile) else {
            print("🔧 ModelCacheManager: No cached Claude models found")
            return nil
        }

        if cachedModels.isExpired {
            print("🔧 ModelCacheManager: Cached Claude models are expired")
            return nil
        }

        print("✅ ModelCacheManager: Loaded \(cachedModels.models.count) cached Claude models")
        return cachedModels.models
    }

    func cacheClaudeModels(_ models: [ClaudeModel]) {
        let cachedModels = CachedModels(models: models, cachedAt: Date())
        saveCachedModels(cachedModels, to: claudeCacheFile)
        print("✅ ModelCacheManager: Cached \(models.count) Claude models")
    }

    // MARK: - OpenAI Model Caching

    func getCachedOpenAIModels() -> [OpenAIModel]? {
        guard let cachedModels: CachedModels<OpenAIModel> = loadCachedModels(from: openaiCacheFile) else {
            print("🔧 ModelCacheManager: No cached OpenAI models found")
            return nil
        }

        if cachedModels.isExpired {
            print("🔧 ModelCacheManager: Cached OpenAI models are expired")
            return nil
        }

        print("✅ ModelCacheManager: Loaded \(cachedModels.models.count) cached OpenAI models")
        return cachedModels.models
    }

    func cacheOpenAIModels(_ models: [OpenAIModel]) {
        let cachedModels = CachedModels(models: models, cachedAt: Date())
        saveCachedModels(cachedModels, to: openaiCacheFile)
        print("✅ ModelCacheManager: Cached \(models.count) OpenAI models")
    }

    // MARK: - Generic Cache Operations

    private func loadCachedModels<T: Codable>(from file: URL) -> CachedModels<T>? {
        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: file)
            let cachedModels = try JSONDecoder().decode(CachedModels<T>.self, from: data)
            return cachedModels
        } catch {
            print("❌ ModelCacheManager: Failed to load cached models from \(file.path): \(error)")
            return nil
        }
    }

    private func saveCachedModels(_ cachedModels: CachedModels<some Codable>, to file: URL) {
        do {
            // Ensure cache directory exists
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cachedModels)
            try data.write(to: file)
            print("✅ ModelCacheManager: Saved cached models to \(file.path)")
        } catch {
            print("❌ ModelCacheManager: Failed to save cached models to \(file.path): \(error)")
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        do {
            if FileManager.default.fileExists(atPath: claudeCacheFile.path) {
                try FileManager.default.removeItem(at: claudeCacheFile)
                print("✅ ModelCacheManager: Cleared Claude model cache")
            }

            if FileManager.default.fileExists(atPath: openaiCacheFile.path) {
                try FileManager.default.removeItem(at: openaiCacheFile)
                print("✅ ModelCacheManager: Cleared OpenAI model cache")
            }
        } catch {
            print("❌ ModelCacheManager: Failed to clear cache: \(error)")
        }
    }

    func getCacheInfo() -> (claudeAge: TimeInterval?, openaiAge: TimeInterval?) {
        let claudeAge = getCacheAge(for: claudeCacheFile)
        let openaiAge = getCacheAge(for: openaiCacheFile)
        return (claudeAge, openaiAge)
    }

    private func getCacheAge(for file: URL) -> TimeInterval? {
        guard FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                return Date().timeIntervalSince(modificationDate)
            }
        } catch {
            print("❌ ModelCacheManager: Failed to get cache age for \(file.path): \(error)")
        }

        return nil
    }
}
