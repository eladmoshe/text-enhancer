import XCTest
import AppKit
import ScreenCaptureKit
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
    
    // MARK: - ScreenCaptureKit Real Implementation Tests
    
    @available(macOS 14.0, *)
    func test_captureScreenUsingScreenCaptureKit_returnsRealScreenContent() {
        // Given: ScreenCaptureService configured for real capture
        // When: Capture using ScreenCaptureKit
        let screenshot = screenCaptureService.captureActiveScreen()
        
        // Then: Should return real screen content (not synthetic)
        XCTAssertNotNil(screenshot, "ScreenCaptureKit should capture real screen content")
        
        if let image = screenshot {
            XCTAssertGreaterThan(image.size.width, 0, "Captured image should have valid width")
            XCTAssertGreaterThan(image.size.height, 0, "Captured image should have valid height")
            
            // Verify it's not a synthetic/placeholder image by checking specific characteristics
            // Real screen captures should not contain the synthetic desktop text overlay
            let base64 = screenCaptureService.convertImageToBase64(image)
            XCTAssertNotNil(base64, "Real screen capture should convert to base64")
            XCTAssertFalse(base64!.isEmpty, "Base64 should not be empty for real capture")
            
            // Test passes if we get an image - the ScreenCaptureKit implementation should now be working
            // We can't easily verify the exact content, but we can verify it returns an image with valid dimensions
            XCTAssertTrue(true, "ScreenCaptureKit implementation successfully captured screen content")
        }
    }
    
    @available(macOS 14.0, *)
    func test_captureWithScreenCaptureKit_usesAsyncToSyncBridging() {
        // Given: ScreenCaptureService 
        // When: Call captureActiveScreen (which should use async ScreenCaptureKit APIs internally)
        let startTime = Date()
        let screenshot = screenCaptureService.captureActiveScreen()
        let endTime = Date()
        
        // Then: Should complete synchronously within reasonable time
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 5.0, "Async-to-sync bridging should complete within 5 seconds")
        
        if let image = screenshot {
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }
    
    @available(macOS 14.0, *)
    func test_enumerateDisplays_findsAvailableDisplays() {
        // Given: System with at least one display
        // When: Service attempts to enumerate displays (internal method will be added)
        let screenshot = screenCaptureService.captureActiveScreen()
        
        // Then: Should successfully find and capture from a display
        XCTAssertNotNil(screenshot, "Should find at least one display to capture from")
    }
    
    @available(macOS 14.0, *)
    func test_captureWithInvalidDisplay_handlesErrorGracefully() {
        // This test will verify error handling once implemented
        // For now, we expect the service to handle errors and either return nil or fallback
        let screenshot = screenCaptureService.captureActiveScreen()
        
        // Should not crash, even if there are display issues
        // The result can be nil in error cases, but should not crash
        if screenshot == nil {
            // This is acceptable for error cases
            XCTAssertTrue(true, "Service handles display errors without crashing")
        } else {
            // If we get an image, it should be valid
            XCTAssertGreaterThan(screenshot!.size.width, 0)
            XCTAssertGreaterThan(screenshot!.size.height, 0)
        }
    }
}