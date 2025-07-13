import Foundation
import Carbon

class ConfigurationManager: ObservableObject {
    @Published var configuration: AppConfiguration = .default
    
    private let localConfigFile: URL
    private let fallbackConfigFile: URL
    
    var claudeApiKey: String? {
        // For backward compatibility, check the old field first
        if !configuration.claudeApiKey.isEmpty {
            return configuration.claudeApiKey
        }
        
        // Then check the new API providers structure
        if let apiProviders = configuration.apiProviders,
           apiProviders.claude.enabled,
           !apiProviders.claude.apiKey.isEmpty {
            return apiProviders.claude.apiKey
        }
        
        return nil
    }
    
    var openaiApiKey: String? {
        // Only available in the new API providers structure
        if let apiProviders = configuration.apiProviders,
           apiProviders.openai.enabled,
           !apiProviders.openai.apiKey.isEmpty {
            return apiProviders.openai.apiKey
        }
        
        return nil
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
        guard let apiProviders = configuration.apiProviders else {
            // Fallback to defaults for backward compatibility
            switch provider {
            case .claude: return "claude-3-haiku-20240307"
            case .openai: return "gpt-3.5-turbo"
            }
        }
        
        switch provider {
        case .claude:
            return apiProviders.claude.model
        case .openai:
            return apiProviders.openai.model
        }
    }
    
    func isEnabled(provider: APIProvider) -> Bool {
        guard let apiProviders = configuration.apiProviders else {
            // For backward compatibility, Claude is enabled if we have an API key
            return provider == .claude && claudeApiKey != nil
        }
        
        switch provider {
        case .claude:
            return apiProviders.claude.enabled
        case .openai:
            return apiProviders.openai.enabled
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
        } catch {
            print("❌ Failed to save configuration: \(error)")
        }
    }
    
    func loadConfiguration() {
        // First try to load from local config.json
        if FileManager.default.fileExists(atPath: localConfigFile.path) {
            do {
                let data = try Data(contentsOf: localConfigFile)
                configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
                print("✅ Configuration loaded from config.json")
                return
            } catch {
                print("❌ Failed to load local configuration: \(error)")
            }
        }
        
        // Fallback to app support directory
        if FileManager.default.fileExists(atPath: fallbackConfigFile.path) {
            do {
                let data = try Data(contentsOf: fallbackConfigFile)
                configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
                print("✅ Configuration loaded from app support directory")
                return
            } catch {
                print("❌ Failed to load fallback configuration: \(error)")
            }
        }
        
        // Use default configuration
        configuration = AppConfiguration.default
        print("ℹ️  Using default configuration")
    }
}

// MARK: - Configuration Models

struct AppConfiguration: Codable {
    let claudeApiKey: String // Kept for backward compatibility
    let shortcuts: [ShortcutConfiguration]
    let maxTokens: Int
    let timeout: TimeInterval
    let showStatusIcon: Bool
    let enableNotifications: Bool
    let autoSave: Bool
    let logLevel: String
    
    // Phase 2: API Providers support
    let apiProviders: APIProviders?
    
    static let `default` = AppConfiguration(
        claudeApiKey: "",
        shortcuts: [
            ShortcutConfiguration(
                id: "improve-text",
                name: "Improve Text",
                keyCode: 18, // Key "1"
                modifiers: [.control, .option],
                prompt: "Improve the writing quality and clarity of this text while maintaining its original meaning and tone.",
                provider: .claude
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

struct ShortcutConfiguration: Codable {
    let id: String
    let name: String
    let keyCode: Int
    let modifiers: [ModifierKey]
    let prompt: String
    let provider: APIProvider? // Optional for backward compatibility
    
    // Default provider for backward compatibility
    var effectiveProvider: APIProvider {
        return provider ?? .claude
    }
}

// MARK: - API Provider Configuration

struct APIProviders: Codable {
    let claude: APIProviderConfig
    let openai: APIProviderConfig
    
    static let `default` = APIProviders(
        claude: APIProviderConfig(
            apiKey: "",
            model: "claude-3-haiku-20240307",
            enabled: true
        ),
        openai: APIProviderConfig(
            apiKey: "",
            model: "gpt-3.5-turbo",
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