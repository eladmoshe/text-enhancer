import Foundation
import AppKit
import UniformTypeIdentifiers

class ImageCompressionService {
    
    struct CompressionResult {
        let compressedData: Data
        let originalSize: Int
        let compressedSize: Int
        let compressionRatio: Double
        let actualQuality: CGFloat
    }
    
    func compressImage(_ image: NSImage, using preset: CompressionPreset) -> CompressionResult? {
        return compressImage(image, quality: CGFloat(preset.quality), maxSize: nil)
    }
    
    func compressImage(_ image: NSImage, quality: CGFloat, maxSize: Int?) -> CompressionResult? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Clamp quality to valid range
        let clampedQuality = max(0.01, min(1.0, quality))
        
        // Get original image data for size comparison
        guard let originalData = image.tiffRepresentation else {
            return nil
        }
        
        let originalSize = originalData.count
        
        // Create compressed image data
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: clampedQuality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        let compressedData = mutableData as Data
        let compressedSize = compressedData.count
        
        // If maxSize is specified and we exceed it, try to reduce quality
        if let maxSize = maxSize, compressedSize > maxSize {
            return optimizeForTargetSize(image, targetSize: maxSize)
        }
        
        return CompressionResult(
            compressedData: compressedData,
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressionRatio: Double(compressedSize) / Double(originalSize),
            actualQuality: clampedQuality
        )
    }
    
    func estimateCompressedSize(_ image: NSImage, quality: CGFloat) -> Int {
        // Simple estimation based on image dimensions and quality
        let pixelCount = Int(image.size.width * image.size.height)
        let baseSize = pixelCount / 4 // Rough JPEG compression base
        let qualityFactor = Double(quality)
        return Int(Double(baseSize) * qualityFactor)
    }
    
    func optimizeForTargetSize(_ image: NSImage, targetSize: Int) -> CompressionResult? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Get original image data for size comparison
        guard let originalData = image.tiffRepresentation else {
            return nil
        }
        
        let originalSize = originalData.count
        
        // Use binary search to find optimal quality
        var lowQuality: CGFloat = 0.01
        var highQuality: CGFloat = 1.0
        let tolerance = 0.01
        var bestResult: CompressionResult?
        
        // First try high quality to see if we're already under target
        if let result = compressImageAtQuality(cgImage, quality: highQuality, originalSize: originalSize),
           result.compressedSize <= targetSize {
            return result
        }
        
        // Binary search for optimal quality
        while highQuality - lowQuality > tolerance {
            let midQuality = (lowQuality + highQuality) / 2
            
            guard let result = compressImageAtQuality(cgImage, quality: midQuality, originalSize: originalSize) else {
                break
            }
            
            if result.compressedSize <= targetSize {
                bestResult = result
                lowQuality = midQuality
            } else {
                highQuality = midQuality
            }
        }
        
        // If we found a result within target, return it
        if let bestResult = bestResult {
            return bestResult
        }
        
        // If we can't meet the target size, return the most compressed version
        return compressImageAtQuality(cgImage, quality: 0.01, originalSize: originalSize)
    }
    
    private func compressImageAtQuality(_ cgImage: CGImage, quality: CGFloat, originalSize: Int) -> CompressionResult? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        let compressedData = mutableData as Data
        let compressedSize = compressedData.count
        
        return CompressionResult(
            compressedData: compressedData,
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressionRatio: Double(compressedSize) / Double(originalSize),
            actualQuality: quality
        )
    }
}

// Extension to get CGImage from NSImage
private extension NSImage {
    var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}