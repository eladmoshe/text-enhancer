import Foundation
import Carbon

class ConfigurationManager: ObservableObject {
    @Published var configuration: AppConfiguration = .default
    
    private let localConfigFile: URL
    private let fallbackConfigFile: URL
    
    var claudeApiKey: String? {
        guard configuration.apiProviders.claude.enabled,
              !configuration.apiProviders.claude.apiKey.isEmpty else {
            return nil
        }
        return configuration.apiProviders.claude.apiKey
    }
    
    var openaiApiKey: String? {
        guard configuration.apiProviders.openai.enabled,
              !configuration.apiProviders.openai.apiKey.isEmpty else {
            return nil
        }
        return configuration.apiProviders.openai.apiKey
    }
    
    func apiKey(for provider: APIProvider) -> String? {
        switch provider {
        case .claude:
            return claudeApiKey
        case .openai:
            return openaiApiKey
        }
    }
    
    func model(for provider: APIProvider) -> String {
        switch provider {
        case .claude:
            return configuration.apiProviders.claude.model
        case .openai:
            return configuration.apiProviders.openai.model
        }
    }
    
    func isEnabled(provider: APIProvider) -> Bool {
        switch provider {
        case .claude:
            return configuration.apiProviders.claude.enabled
        case .openai:
            return configuration.apiProviders.openai.enabled
        }
    }
    
    init(localConfig: URL = URL(fileURLWithPath: "config.json"), appSupportDir: URL? = nil) {
        self.localConfigFile = localConfig
        
        let configDirectory: URL
        if let appSupportDir = appSupportDir {
            configDirectory = appSupportDir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            configDirectory = appSupport.appendingPathComponent("TextEnhancer")
        }
        
        self.fallbackConfigFile = configDirectory.appendingPathComponent("config.json")
        
        loadConfiguration()
    }
    
    // MARK: - Configuration Operations
    
    // MARK: - Configuration File Operations
    
    func saveConfiguration(_ config: AppConfiguration) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: localConfigFile)
            print("✅ Configuration saved to config.json")
            
            // Update the published configuration
            DispatchQueue.main.async {
                self.configuration = config
            }
            
            // Post notification for configuration change
            NotificationCenter.default.post(name: .configurationChanged, object: nil)
        } catch {
            print("❌ Failed to save configuration: \(error)")
        }
    }
    
    func loadConfiguration() {
        print("🔧 ConfigurationManager: Loading configuration...")
        print("🔧 ConfigurationManager: Looking for local config at: \(localConfigFile.path)")
        print("🔧 ConfigurationManager: Looking for fallback config at: \(fallbackConfigFile.path)")
        
        // First try to load from local config.json
        if FileManager.default.fileExists(atPath: localConfigFile.path) {
            do {
                let data = try Data(contentsOf: localConfigFile)
                self.configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
                print("✅ Configuration loaded from config.json")
                print("🔧 ConfigurationManager: Loaded \(configuration.shortcuts.count) shortcuts")
                return
            } catch {
                print("❌ Failed to load local configuration: \(error)")
            }
        } else {
            print("🔧 ConfigurationManager: Local config file does not exist")
        }
        
        // Fallback to app support directory
        if FileManager.default.fileExists(atPath: fallbackConfigFile.path) {
            do {
                let data = try Data(contentsOf: fallbackConfigFile)
                self.configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
                print("✅ Configuration loaded from app support directory")
                print("🔧 ConfigurationManager: Loaded \(configuration.shortcuts.count) shortcuts from fallback")
                return
            } catch {
                print("❌ Failed to load fallback configuration: \(error)")
            }
        }
        
        // Use default configuration
        configuration = AppConfiguration.default
        print("ℹ️  Using default configuration with \(configuration.shortcuts.count) shortcuts")
    }
}

// MARK: - Configuration Models

struct AppConfiguration: Codable {
    let shortcuts: [ShortcutConfiguration]
    let maxTokens: Int
    let timeout: TimeInterval
    let showStatusIcon: Bool
    let enableNotifications: Bool
    let autoSave: Bool
    let logLevel: String
    let apiProviders: APIProviders
    
    static let `default` = AppConfiguration(
        shortcuts: [
            ShortcutConfiguration(
                id: "improve-text",
                name: "Improve Text",
                keyCode: 18, // Key "1"
                modifiers: [.control, .option],
                prompt: "Improve the writing quality and clarity of this text while maintaining its original meaning and tone.",
                provider: .claude,
                model: "claude-4-sonnet",
                includeScreenshot: nil
            )
        ],
        maxTokens: 1000,
        timeout: 30.0,
        showStatusIcon: true,
        enableNotifications: true,
        autoSave: true,
        logLevel: "info",
        apiProviders: APIProviders.default
    )
}

struct ShortcutConfiguration: Codable, Identifiable {
    let id: String
    let name: String
    let keyCode: Int
    let modifiers: [ModifierKey]
    let prompt: String
    let provider: APIProvider
    let model: String
    let includeScreenshot: Bool?
    
    var effectiveProvider: APIProvider {
        return provider
    }
    
    var effectiveModel: String {
        return model
    }
    
    var effectiveIncludeScreenshot: Bool {
        return includeScreenshot ?? false
    }
}

// MARK: - API Provider Configuration

struct APIProviders: Codable {
    let claude: APIProviderConfig
    let openai: APIProviderConfig
    
    static let `default` = APIProviders(
        claude: APIProviderConfig(
            apiKey: "",
            model: "claude-4-sonnet",
            enabled: true
        ),
        openai: APIProviderConfig(
            apiKey: "",
            model: "gpt-4o",
            enabled: false
        )
    )
}

struct APIProviderConfig: Codable {
    let apiKey: String
    let model: String
    let enabled: Bool
}

enum APIProvider: String, Codable, CaseIterable {
    case claude = "claude"
    case openai = "openai"
    
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        }
    }
}

enum ModifierKey: String, Codable, CaseIterable {
    case command = "cmd"
    case control = "ctrl"
    case option = "opt"
    case shift = "shift"
    
    var carbonValue: UInt32 {
        switch self {
        case .command:
            return UInt32(cmdKey)
        case .control:
            return UInt32(controlKey)
        case .option:
            return UInt32(optionKey)
        case .shift:
            return UInt32(shiftKey)
        }
    }
    
    var displayName: String {
        switch self {
        case .command:
            return "⌘"
        case .control:
            return "⌃"
        case .option:
            return "⌥"
        case .shift:
            return "⇧"
        }
    }
}

// Notification names
extension Notification.Name {
    static let configurationChanged = Notification.Name("configurationChanged")
} 