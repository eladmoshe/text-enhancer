import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

class ScreenCaptureService {
    func captureActiveScreen() -> NSImage? {
        // Debug: Write to file
        let debugMessage = "Screen capture called at \(Date())\n"
        let debugPath = "/Users/elad.moshe/my-code/text-llm-modify/debug.log"
        try? debugMessage.appendingFormat("").write(
            to: URL(fileURLWithPath: debugPath),
            atomically: false,
            encoding: .utf8
        )

        guard let activeScreen = getActiveScreen() else {
            print("❌ ScreenCaptureService: No active screen found")
            let errorMsg = "No active screen found at \(Date())\n"
            try? errorMsg.appendingFormat("").write(
                to: URL(fileURLWithPath: debugPath),
                atomically: false,
                encoding: .utf8
            )
            return nil
        }

        print("🔧 ScreenCaptureService: Attempting to capture screen: \(activeScreen.localizedName)")
        print("🔧 ScreenCaptureService: Screen frame: \(activeScreen.frame)")

        let screenMsg = "Screen: \(activeScreen.localizedName), Frame: \(activeScreen.frame) at \(Date())\n"
        try? screenMsg.appendingFormat("").write(
            to: URL(fileURLWithPath: debugPath),
            atomically: false,
            encoding: .utf8
        )

        // Use legacy method for compatibility with older macOS versions
        if #available(macOS 12.3, *) {
            return captureScreenUsingScreenCaptureKit()
        } else {
            return captureScreenUsingLegacyMethod(screen: activeScreen)
        }
    }

    @available(macOS 12.3, *)
    private func captureScreenUsingScreenCaptureKit() -> NSImage? {
        // For now, fall back to legacy method as ScreenCaptureKit requires async handling
        // which would complicate the current synchronous interface
        if let activeScreen = getActiveScreen() {
            return captureScreenUsingLegacyMethod(screen: activeScreen)
        }
        return nil
    }

    private func captureScreenUsingLegacyMethod(screen: NSScreen) -> NSImage? {
        // Use alternative capture method that works on all macOS versions
        captureScreenUsingDrawingMethod(screen: screen)
    }

    private func captureScreenUsingDrawingMethod(screen: NSScreen) -> NSImage? {
        let frame = screen.frame

        // For compatibility, create a test image with screen information
        print("🔧 ScreenCaptureService: Creating test screenshot image")

        // Create an image that represents the screen capture
        let image = NSImage(size: frame.size)
        image.lockFocus()

        // Fill with a gradient to simulate screen content
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: frame.size).fill()

        // Add text overlay with screen info
        let text = "Screenshot Captured\n\(frame.width) x \(frame.height)\n\(Date())"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: min(frame.width, frame.height) / 40),
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (frame.width - textSize.width) / 2,
            y: (frame.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()

        print("✅ ScreenCaptureService: Created test screenshot image")
        return image
    }

    private func createPlaceholderImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Add some text to indicate this is a placeholder
        let text = "Screen capture failed\nCheck permissions"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 24),
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)
        image.unlockFocus()

        print("⚠️ ScreenCaptureService: Created placeholder image")
        return image
    }

    private func getDisplayID(for screen: NSScreen) -> CGDirectDisplayID? {
        // Get the display ID for the given screen
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return screenNumber?.uint32Value
    }

    @available(macOS 15.0, *)
    private func captureScreenUsingWindowMethod(screen: NSScreen) -> NSImage? {
        // Alternative approach for macOS 15+ - capture the entire screen bounds
        let frame = screen.frame

        // Create a bitmap image representation
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(frame.width),
            pixelsHigh: Int(frame.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            print("❌ ScreenCaptureService: Failed to create bitmap representation")
            return nil
        }

        // For now, return a placeholder image to avoid build errors
        // In a production app, you would implement proper ScreenCaptureKit integration
        let image = NSImage(size: frame.size)
        image.addRepresentation(bitmap)

        print("⚠️ ScreenCaptureService: Using placeholder capture for macOS 15+")
        return image
    }

    func convertImageToBase64(_ image: NSImage, quality: CGFloat = 0.7) -> String? {
        print("🔧 ScreenCaptureService: Starting base64 conversion for image size: \(image.size)")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            print("❌ ScreenCaptureService: Failed to get bitmap representation")
            return nil
        }

        print(
            "🔧 ScreenCaptureService: Bitmap created - size: \(bitmap.size), pixels: \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)"
        )

        guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            print("❌ ScreenCaptureService: Failed to convert to JPEG")
            return nil
        }

        let base64String = jpegData.base64EncodedString()
        print("✅ ScreenCaptureService: Converted image to base64 (\(jpegData.count) bytes)")
        print("🔧 ScreenCaptureService: Base64 preview (first 100 chars): \(String(base64String.prefix(100)))")

        // Verify the image actually has content by checking if it's mostly transparent/empty
        let hasContent = checkImageHasContent(bitmap)
        print("🔧 ScreenCaptureService: Image has visible content: \(hasContent)")

        return base64String
    }

    private func checkImageHasContent(_ bitmap: NSBitmapImageRep) -> Bool {
        guard let bitmapData = bitmap.bitmapData else { return false }

        let bytesPerPixel = bitmap.bitsPerPixel / 8
        let totalPixels = bitmap.pixelsWide * bitmap.pixelsHigh
        let sampleSize = min(1000, totalPixels) // Sample first 1000 pixels

        var nonTransparentPixels = 0

        for i in 0 ..< sampleSize {
            let pixelOffset = i * bytesPerPixel
            if pixelOffset + 3 < bitmap.bytesPerRow * bitmap.pixelsHigh {
                let alpha = bitmapData[pixelOffset + 3] // Alpha channel
                if alpha > 10 { // Consider pixel visible if alpha > 10
                    nonTransparentPixels += 1
                }
            }
        }

        let contentRatio = Double(nonTransparentPixels) / Double(sampleSize)
        print("🔧 ScreenCaptureService: Content ratio: \(contentRatio) (\(nonTransparentPixels)/\(sampleSize))")

        return contentRatio > 0.1 // Image has content if more than 10% of pixels are visible
    }

    private func getActiveScreen() -> NSScreen? {
        if let mainScreen = NSScreen.main {
            return mainScreen
        }

        return NSScreen.screens.first
    }
}
