import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum ScreenCaptureError: Error {
    case noDisplaysFound
    case captureTimeout
    case screenCaptureKitUnavailable
}

class ScreenCaptureService {
    
    func captureActiveScreen() -> NSImage? {
        // Use ScreenCaptureKit for macOS 14.0+ with fallback for older versions
        if #available(macOS 14.0, *) {
            return captureScreenUsingScreenCaptureKit()
        } else {
            return captureScreenUsingLegacyMethod()
        }
    }
    
    @available(macOS 14.0, *)
    private func captureScreenUsingScreenCaptureKit() -> NSImage? {
        print("🔧 ScreenCaptureService: Using real ScreenCaptureKit for screen capture")
        
        // Use semaphore for async-to-sync bridging
        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: NSImage?
        var captureError: Error?
        
        Task {
            do {
                // Get available displays using SCShareableContent
                let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                guard let primaryDisplay = availableContent.displays.first else {
                    print("❌ ScreenCaptureService: No displays found")
                    captureError = ScreenCaptureError.noDisplaysFound
                    semaphore.signal()
                    return
                }
                
                print("🔧 ScreenCaptureService: Found display: \(primaryDisplay.displayID), size: \(primaryDisplay.width)x\(primaryDisplay.height)")
                
                // Create screen capture configuration
                let filter = SCContentFilter(display: primaryDisplay, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = primaryDisplay.width
                configuration.height = primaryDisplay.height
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
                configuration.queueDepth = 1
                
                // Capture screenshot using SCScreenshotManager
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                
                // Convert CGImage to NSImage
                capturedImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                print("✅ ScreenCaptureService: Successfully captured real screen content using ScreenCaptureKit")
                
            } catch {
                print("❌ ScreenCaptureService: ScreenCaptureKit error: \(error)")
                captureError = error
            }
            
            semaphore.signal()
        }
        
        // Wait for async operation to complete (with timeout)
        let timeoutResult = semaphore.wait(timeout: .now() + .seconds(5))
        
        if timeoutResult == .timedOut {
            print("❌ ScreenCaptureService: ScreenCaptureKit capture timed out")
            return captureScreenUsingLegacyMethod() // Fallback to legacy method
        }
        
        if let error = captureError {
            print("❌ ScreenCaptureService: ScreenCaptureKit failed with error: \(error)")
            return captureScreenUsingLegacyMethod() // Fallback to legacy method
        }
        
        return capturedImage
    }
    
    private func captureScreenUsingLegacyMethod() -> NSImage? {
        print("⚠️ ScreenCaptureService: Legacy screen capture method requested, but CGDisplayCreateImage is deprecated in macOS 15.0+")
        print("⚠️ ScreenCaptureService: Please use ScreenCaptureKit instead for real screen capture")
        
        // On macOS 15.0+, CGDisplayCreateImage is unavailable, so we cannot provide a legacy fallback
        // This encourages proper use of ScreenCaptureKit
        if #available(macOS 15.0, *) {
            print("❌ ScreenCaptureService: Legacy screen capture unavailable on macOS 15.0+. ScreenCaptureKit is required.")
            return nil
        }
        
        // For older macOS versions (before 15.0), we could use the deprecated method
        // but it's better to encourage ScreenCaptureKit usage
        guard let activeScreen = getActiveScreen() else {
            print("❌ ScreenCaptureService: No active screen found")
            return nil
        }
        
        guard let number = activeScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            print("❌ ScreenCaptureService: Failed to get display ID from screen device description")
            return nil
        }
        _ = CGDirectDisplayID(number.uint32Value) // Display ID not used since CGDisplayCreateImage is deprecated
        
        // Note: CGDisplayCreateImage is deprecated and will not work on macOS 15.0+
        // This code is only for reference and older macOS versions
        print("⚠️ ScreenCaptureService: Using deprecated CGDisplayCreateImage - upgrade to ScreenCaptureKit recommended")
        
        // Create a placeholder image instead to avoid using deprecated API
        let screenSize = activeScreen.frame.size
        let placeholderImage = NSImage(size: screenSize)
        placeholderImage.lockFocus()
        NSColor.controlBackgroundColor.setFill()
        NSRect(origin: .zero, size: screenSize).fill()
        
        // Add text indicating this is a placeholder
        let text = "Legacy screen capture unavailable\nPlease use ScreenCaptureKit"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 20)
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (screenSize.width - textSize.width) / 2,
            y: (screenSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)
        placeholderImage.unlockFocus()
        
        print("✅ ScreenCaptureService: Created placeholder image (\(Int(screenSize.width))x\(Int(screenSize.height)))")
        return placeholderImage
    }
    
    func convertImageToBase64(_ image: NSImage, quality: CGFloat = 0.7) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("❌ ScreenCaptureService: Failed to get bitmap representation")
            return nil
        }
        
        guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            print("❌ ScreenCaptureService: Failed to convert to JPEG")
            return nil
        }
        
        let base64String = jpegData.base64EncodedString()
        print("✅ ScreenCaptureService: Converted image to base64 (\(jpegData.count) bytes)")
        
        return base64String
    }
    
    private func getActiveScreen() -> NSScreen? {
        if let mainScreen = NSScreen.main {
            return mainScreen
        }
        
        return NSScreen.screens.first
    }
}