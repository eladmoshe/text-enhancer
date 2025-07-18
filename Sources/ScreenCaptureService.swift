import AppKit
import CoreGraphics
import Foundation

class ScreenCaptureService {
    
    func captureActiveScreen() -> NSImage? {
        guard let activeScreen = getActiveScreen() else {
            print("❌ ScreenCaptureService: No active screen found")
            return nil
        }
        
        guard let number = activeScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            print("❌ ScreenCaptureService: Failed to get display ID from screen device description")
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            print("❌ ScreenCaptureService: Failed to create CGImage from display")
            return nil
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        print("✅ ScreenCaptureService: Successfully captured screen (\(cgImage.width)x\(cgImage.height))")
        
        return nsImage
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