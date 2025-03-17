//
//  UIImage+Extensions.swift
//  Tono
//
//  Created for the AR Gamified Chinese Learning App
//

import UIKit

extension UIImage {
    func fixOrientation() -> UIImage {
        // Check if the image orientation is already up
        if self.imageOrientation == .up {
            return self
        }

        // Create a context for rotation
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        
        // Draw the original image, which will apply the orientation
        self.draw(at: CGPoint.zero)
        
        // Get the rotated image and end the context
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage ?? self
    }
    
    func rotateImage() -> UIImage {
        // Create a context for rotation
        UIGraphicsBeginImageContextWithOptions(CGSize(width: self.size.height, height: self.size.width), false, self.scale)
        if let context = UIGraphicsGetCurrentContext() {
            // Rotate 90 degrees counterclockwise
            context.translateBy(x: 0, y: self.size.width)
            context.rotate(by: -CGFloat.pi / 2)
            self.draw(at: CGPoint.zero)
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return rotatedImage ?? self
        }
        return self
    }
}