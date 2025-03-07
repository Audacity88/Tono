import UIKit

// Extension to fix image orientation issues
extension UIImage {
    // Fixes the orientation of an image to be upright
    func fixOrientation() -> UIImage {
        // If the orientation is already correct, return the original image
        if self.imageOrientation == .up {
            return self
        }
        
        // Create a CGAffineTransform to correct the image orientation
        var transform = CGAffineTransform.identity
        
        // Apply transformations based on the current orientation
        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: self.size.height)
            transform = transform.rotated(by: .pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.rotated(by: .pi/2)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: self.size.height)
            transform = transform.rotated(by: -.pi/2)
            
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }
        
        // Handle mirrored orientations
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break
        }
        
        // Create a new CGContext with the correct orientation
        guard let cgImage = self.cgImage,
              let colorSpace = cgImage.colorSpace else {
            return self
        }
        
        let contextWidth: Int
        let contextHeight: Int
        
        // For left and right orientations, swap width and height
        if self.imageOrientation == .left || self.imageOrientation == .right ||
           self.imageOrientation == .leftMirrored || self.imageOrientation == .rightMirrored {
            contextWidth = cgImage.height
            contextHeight = cgImage.width
        } else {
            contextWidth = cgImage.width
            contextHeight = cgImage.height
        }
        
        guard let context = CGContext(
            data: nil,
            width: contextWidth,
            height: contextHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return self
        }
        
        // Apply the transform and draw the image
        context.concatenate(transform)
        
        // Draw the image based on its orientation
        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        }
        
        // Create a new CGImage from the context
        guard let newCGImage = context.makeImage() else {
            return self
        }
        
        // Create and return a new UIImage with the corrected orientation
        let newImage = UIImage(cgImage: newCGImage, scale: self.scale, orientation: .up)
        return newImage
    }
    
    // Simple method to rotate an image 90 degrees clockwise
    func rotate90DegreesClockwise() -> UIImage {
        let rotatedSize = CGSize(width: size.height, height: size.width)
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move to the center of the context
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        // Rotate 90 degrees clockwise (π/2 radians)
        context.rotate(by: .pi / 2)
        // Move back, accounting for the rotation
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
        
        // Draw the original image
        draw(at: .zero)
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
} 