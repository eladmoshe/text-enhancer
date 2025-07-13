import Foundation
import Carbon

class ConfigurationManager: ObservableObject {
    @Published var configuration: AppConfiguration = .default
    
    private let localConfigFile: URL
    private let fallbackConfigFile: URL
    
    var claudeApiKey: String? {
        return configuration.claudeApiKey.isEmpty ? nil : configuration.claudeApiKey
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
    let claudeApiKey: String
    let shortcuts: [ShortcutConfiguration]
    let maxTokens: Int
    let timeout: TimeInterval
    let showStatusIcon: Bool
    let enableNotifications: Bool
    let autoSave: Bool
    let logLevel: String
    
    static let `default` = AppConfiguration(
        claudeApiKey: "",
        shortcuts: [
            ShortcutConfiguration(
                id: "improve-text",
                name: "Improve Text",
                keyCode: 18, // Key "1"
                modifiers: [.control, .option],
                prompt: "Improve the writing quality and clarity of this text while maintaining its original meaning and tone."
            )
        ],
        maxTokens: 1000,
        timeout: 30.0,
        showStatusIcon: true,
        enableNotifications: true,
        autoSave: true,
        logLevel: "info"
    )
}

struct ShortcutConfiguration: Codable {
    let id: String
    let name: String
    let keyCode: Int
    let modifiers: [ModifierKey]
    let prompt: String
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