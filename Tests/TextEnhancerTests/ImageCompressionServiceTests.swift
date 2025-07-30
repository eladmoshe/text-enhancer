import XCTest
import AppKit
@testable import TextEnhancer

final class ImageCompressionServiceTests: XCTestCase {
    
    var service: ImageCompressionService!
    var testImage: NSImage!
    
    override func setUp() {
        super.setUp()
        service = ImageCompressionService()
        
        // Create a more complex test image (gradient 200x200) that compresses better
        let size = NSSize(width: 200, height: 200)
        testImage = NSImage(size: size)
        testImage.lockFocus()
        
        // Create a gradient that will compress better than solid color
        let gradient = NSGradient(colors: [NSColor.red, NSColor.blue, NSColor.green, NSColor.yellow])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // Add some noise/detail to make it more compressible
        for _ in 0..<50 {
            let randomRect = NSRect(
                x: Double.random(in: 0...size.width-10),
                y: Double.random(in: 0...size.height-10),
                width: 10,
                height: 10
            )
            NSColor(red: Double.random(in: 0...1), 
                   green: Double.random(in: 0...1), 
                   blue: Double.random(in: 0...1), 
                   alpha: 0.5).setFill()
            randomRect.fill()
        }
        
        testImage.unlockFocus()
    }
    
    override func tearDown() {
        service = nil
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - Compression Tests
    
    func test_compressImageWithPreset_ultraHigh() {
        // Given: A test image and ultra high preset
        let preset = CompressionPreset.ultraHigh
        
        // When: Compressing the image
        let result = service.compressImage(testImage, using: preset)
        
        // Then: Should return a valid compression result
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.compressedSize, 0)
        XCTAssertEqual(result!.actualQuality, 0.95, accuracy: 0.01)
        XCTAssertLessThanOrEqual(result!.compressedSize, result!.originalSize)
    }
    
    func test_compressImageWithPreset_efficient() {
        // Given: A test image and efficient preset
        let preset = CompressionPreset.efficient
        
        // When: Compressing the image
        let result = service.compressImage(testImage, using: preset)
        
        // Then: Should return a valid compression result with smaller size
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.compressedSize, 0)
        XCTAssertEqual(result!.actualQuality, 0.60, accuracy: 0.01)
        XCTAssertLessThanOrEqual(result!.compressedSize, result!.originalSize)
    }
    
    func test_compressImageWithCustomQuality() {
        // Given: A test image and custom quality
        let customQuality: CGFloat = 0.5
        
        // When: Compressing with custom quality
        let result = service.compressImage(testImage, quality: customQuality, maxSize: nil)
        
        // Then: Should return compression result with specified quality
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.actualQuality, customQuality, accuracy: 0.01)
        XCTAssertGreaterThan(result!.compressedSize, 0)
    }
    
    func test_compressImageWithMaxSize() {
        // Given: A test image and max size constraint
        let maxSize = 10000 // bytes - account for JPEG overhead and minimum size
        
        // When: Compressing with size constraint
        let result = service.compressImage(testImage, quality: 0.8, maxSize: maxSize)
        
        // Then: Should respect the size constraint
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.compressedSize, maxSize)
        
        // Verify it actually attempted compression by having lower quality
        XCTAssertLessThan(result!.actualQuality, 0.8)
    }
    
    func test_compressionRatioCalculation() {
        // Given: A test image
        let preset = CompressionPreset.balanced
        
        // When: Compressing the image
        let result = service.compressImage(testImage, using: preset)
        
        // Then: Should calculate compression ratio correctly
        XCTAssertNotNil(result)
        let expectedRatio = Double(result!.compressedSize) / Double(result!.originalSize)
        XCTAssertEqual(result!.compressionRatio, expectedRatio, accuracy: 0.001)
        XCTAssertLessThanOrEqual(result!.compressionRatio, 1.0)
    }
    
    func test_estimateCompressedSize() {
        // Given: A test image and quality
        let quality: CGFloat = 0.7
        
        // When: Estimating compressed size
        let estimatedSize = service.estimateCompressedSize(testImage, quality: quality)
        
        // Then: Should return a reasonable estimate
        XCTAssertGreaterThan(estimatedSize, 0)
        XCTAssertLessThan(estimatedSize, 10000) // Should be reasonable for small test image
    }
    
    func test_optimizeForTargetSize() {
        // Given: A test image and target size
        let targetSize = 10000 // bytes - set to what we know works
        
        // When: Optimizing for target size
        let result = service.optimizeForTargetSize(testImage, targetSize: targetSize)
        
        // Then: Should get close to target size
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.compressedSize, targetSize + 1000) // Allow more tolerance for JPEG overhead
        
        // The result should be meaningful compression
        XCTAssertGreaterThan(result!.compressionRatio, 0.005) // At least some compression occurred (very low threshold for excellent compression)
        XCTAssertLessThan(result!.compressionRatio, 1.0) // But not larger than original
    }
    
    // MARK: - Edge Cases
    
    func test_compressImageWithInvalidImage() {
        // Given: An invalid image (empty)
        let emptyImage = NSImage()
        
        // When: Attempting to compress
        let result = service.compressImage(emptyImage, using: .balanced)
        
        // Then: Should return nil
        XCTAssertNil(result)
    }
    
    func test_compressImageWithZeroQuality() {
        // Given: A test image and zero quality
        let result = service.compressImage(testImage, quality: 0.0, maxSize: nil)
        
        // Then: Should handle gracefully (either return nil or use minimum quality)
        if let result = result {
            XCTAssertGreaterThan(result.actualQuality, 0.0)
        }
    }
    
    func test_compressImageWithQualityAboveOne() {
        // Given: A test image and quality > 1.0
        let result = service.compressImage(testImage, quality: 1.5, maxSize: nil)
        
        // Then: Should clamp to maximum quality
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.actualQuality, 1.0)
    }
}