import XCTest
@testable import TextEnhancer

final class CompressionConfigurationTests: XCTestCase {
    
    // MARK: - CompressionPreset Tests
    
    func test_compressionPresetDefaultValues() {
        // Given: Default compression presets
        let ultraHigh = CompressionPreset.ultraHigh
        let high = CompressionPreset.high
        let balanced = CompressionPreset.balanced
        let efficient = CompressionPreset.efficient
        
        // Then: Each preset should have expected quality and max dimensions
        XCTAssertEqual(ultraHigh.quality, 0.95)
        XCTAssertEqual(ultraHigh.maxWidth, 2048)
        XCTAssertEqual(ultraHigh.maxHeight, 2048)
        XCTAssertEqual(ultraHigh.displayName, "Ultra High Quality")
        XCTAssertEqual(ultraHigh.description, "Minimal compression, best quality (95% quality, max 2048x2048)")
        
        XCTAssertEqual(high.quality, 0.85)
        XCTAssertEqual(high.maxWidth, 1920)
        XCTAssertEqual(high.maxHeight, 1920)
        XCTAssertEqual(high.displayName, "High Quality")
        XCTAssertEqual(high.description, "Good balance of quality and size (85% quality, max 1920x1920)")
        
        XCTAssertEqual(balanced.quality, 0.75)
        XCTAssertEqual(balanced.maxWidth, 1600)
        XCTAssertEqual(balanced.maxHeight, 1600)
        XCTAssertEqual(balanced.displayName, "Balanced")
        XCTAssertEqual(balanced.description, "Good compromise for most use cases (75% quality, max 1600x1600)")
        
        XCTAssertEqual(efficient.quality, 0.60)
        XCTAssertEqual(efficient.maxWidth, 1200)
        XCTAssertEqual(efficient.maxHeight, 1200)
        XCTAssertEqual(efficient.displayName, "Efficient")
        XCTAssertEqual(efficient.description, "Optimized for API cost reduction (60% quality, max 1200x1200)")
    }
    
    func test_compressionPresetAllCases() {
        // Given: All compression preset cases
        let allCases = CompressionPreset.allCases
        
        // Then: Should contain all 4 presets in correct order
        XCTAssertEqual(allCases.count, 4)
        XCTAssertEqual(allCases[0], .ultraHigh)
        XCTAssertEqual(allCases[1], .high)
        XCTAssertEqual(allCases[2], .balanced)
        XCTAssertEqual(allCases[3], .efficient)
    }
    
    func test_compressionPresetCodable() {
        // Given: A compression preset
        let preset = CompressionPreset.balanced
        
        // When: Encoding and decoding
        let encoded = try! JSONEncoder().encode(preset)
        let decoded = try! JSONDecoder().decode(CompressionPreset.self, from: encoded)
        
        // Then: Should preserve the preset
        XCTAssertEqual(decoded, preset)
    }
    
    // MARK: - CompressionConfiguration Tests
    
    func test_compressionConfigurationDefaultValues() {
        // Given: Default compression configuration
        let config = CompressionConfiguration.default
        
        // Then: Should have balanced preset and compression enabled
        XCTAssertEqual(config.preset, .balanced)
        XCTAssertTrue(config.enabled)
    }
    
    func test_compressionConfigurationCodable() {
        // Given: A compression configuration
        let config = CompressionConfiguration(preset: .high, enabled: false)
        
        // When: Encoding and decoding
        let encoded = try! JSONEncoder().encode(config)
        let decoded = try! JSONDecoder().decode(CompressionConfiguration.self, from: encoded)
        
        // Then: Should preserve all values
        XCTAssertEqual(decoded.preset, .high)
        XCTAssertFalse(decoded.enabled)
    }
    
    func test_compressionConfigurationGetQuality() {
        // Given: Compression configurations with different presets
        let ultraHighConfig = CompressionConfiguration(preset: .ultraHigh, enabled: true)
        let efficientConfig = CompressionConfiguration(preset: .efficient, enabled: true)
        let disabledConfig = CompressionConfiguration(preset: .high, enabled: false)
        
        // Then: Should return correct quality values
        XCTAssertEqual(ultraHighConfig.quality, 0.95)
        XCTAssertEqual(efficientConfig.quality, 0.60)
        XCTAssertEqual(disabledConfig.quality, 0.85) // Returns preset quality even when disabled
    }
    
    func test_compressionConfigurationGetMaxDimensions() {
        // Given: Compression configurations with different presets
        let ultraHighConfig = CompressionConfiguration(preset: .ultraHigh, enabled: true)
        let efficientConfig = CompressionConfiguration(preset: .efficient, enabled: true)
        
        // Then: Should return correct max dimensions
        XCTAssertEqual(ultraHighConfig.maxWidth, 2048)
        XCTAssertEqual(ultraHighConfig.maxHeight, 2048)
        XCTAssertEqual(efficientConfig.maxWidth, 1200)
        XCTAssertEqual(efficientConfig.maxHeight, 1200)
    }
}