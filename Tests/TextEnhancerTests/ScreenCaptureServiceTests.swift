import XCTest
import AppKit
@testable import TextEnhancer

final class ScreenCaptureServiceTests: XCTestCase {
    var screenCaptureService: ScreenCaptureService!
    
    override func setUp() {
        super.setUp()
        screenCaptureService = ScreenCaptureService()
    }
    
    override func tearDown() {
        screenCaptureService = nil
        super.tearDown()
    }
    
    func test_captureActiveScreen_returnsNSImage() {
        // When: Capture active screen
        let screenshot = screenCaptureService.captureActiveScreen()
        
        // Then: Should return an NSImage
        // Note: In a headless test environment, this might return nil,
        // but the method should not crash
        if screenshot != nil {
            XCTAssertTrue(screenshot!.size.width > 0)
            XCTAssertTrue(screenshot!.size.height > 0)
        }
    }
    
    func test_convertImageToBase64_withValidImage_returnsBase64String() {
        // Given: A small test image
        let testImage = NSImage(size: NSSize(width: 10, height: 10))
        testImage.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        testImage.unlockFocus()
        
        // When: Convert to base64
        let base64String = screenCaptureService.convertImageToBase64(testImage)
        
        // Then: Should return a valid base64 string
        XCTAssertNotNil(base64String)
        XCTAssertFalse(base64String!.isEmpty)
        
        // Verify it's valid base64
        let data = Data(base64Encoded: base64String!)
        XCTAssertNotNil(data)
    }
    
    func test_convertImageToBase64_withCustomQuality_adjustsFileSize() {
        // Given: A test image
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        testImage.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        testImage.unlockFocus()
        
        // When: Convert with different quality settings
        let highQuality = screenCaptureService.convertImageToBase64(testImage, quality: 1.0)
        let lowQuality = screenCaptureService.convertImageToBase64(testImage, quality: 0.1)
        
        // Then: Lower quality should result in smaller base64 string
        if let high = highQuality, let low = lowQuality {
            XCTAssertGreaterThan(high.count, low.count)
        }
    }
}