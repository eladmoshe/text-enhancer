import Foundation

// MARK: - Compression Preset

enum CompressionPreset: String, Codable, CaseIterable {
    case ultraHigh = "ultra_high"
    case high = "high"
    case balanced = "balanced"
    case efficient = "efficient"
    
    var quality: Double {
        switch self {
        case .ultraHigh:
            return 0.95
        case .high:
            return 0.85
        case .balanced:
            return 0.75
        case .efficient:
            return 0.60
        }
    }
    
    var maxWidth: Int {
        switch self {
        case .ultraHigh:
            return 2048
        case .high:
            return 1920
        case .balanced:
            return 1600
        case .efficient:
            return 1200
        }
    }
    
    var maxHeight: Int {
        switch self {
        case .ultraHigh:
            return 2048
        case .high:
            return 1920
        case .balanced:
            return 1600
        case .efficient:
            return 1200
        }
    }
    
    var displayName: String {
        switch self {
        case .ultraHigh:
            return "Ultra High Quality"
        case .high:
            return "High Quality"
        case .balanced:
            return "Balanced"
        case .efficient:
            return "Efficient"
        }
    }
    
    var description: String {
        switch self {
        case .ultraHigh:
            return "Minimal compression, best quality (95% quality, max 2048x2048)"
        case .high:
            return "Good balance of quality and size (85% quality, max 1920x1920)"
        case .balanced:
            return "Good compromise for most use cases (75% quality, max 1600x1600)"
        case .efficient:
            return "Optimized for API cost reduction (60% quality, max 1200x1200)"
        }
    }
}

// MARK: - Compression Configuration

struct CompressionConfiguration: Codable {
    let preset: CompressionPreset
    let enabled: Bool
    let customQuality: Double?
    let maxSizeBytes: Int?
    
    init(preset: CompressionPreset, enabled: Bool = true, customQuality: Double? = nil, maxSizeBytes: Int? = nil) {
        self.preset = preset
        self.enabled = enabled
        self.customQuality = customQuality
        self.maxSizeBytes = maxSizeBytes
    }
    
    static let `default` = CompressionConfiguration(
        preset: .balanced,
        enabled: true
    )
    
    var quality: Double {
        return customQuality ?? preset.quality
    }
    
    var maxWidth: Int {
        return preset.maxWidth
    }
    
    var maxHeight: Int {
        return preset.maxHeight
    }
}