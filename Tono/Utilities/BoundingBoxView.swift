//  Ultralytics YOLO 🚀 - AGPL-3.0 License
//
//  BoundingBoxView for Ultralytics YOLO App
//  This class is designed to visualize bounding boxes and labels for detected objects in the YOLOv8 models within the Ultralytics YOLO app.
//  It leverages Core Animation layers to draw the bounding boxes and text labels dynamically on the detection video feed.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  BoundingBoxView facilitates the clear representation of detection results, improving user interaction with the app by
//  providing immediate visual feedback on detected objects, including their classification and confidence level.

import Foundation
import UIKit

/// Manages the visualization of bounding boxes and associated labels for object detection results.
class BoundingBoxView: UIView {
  /// The layer that draws the bounding box around a detected object.
  let shapeLayer: CAShapeLayer

  /// The layer that displays the label and confidence score for the detected object.
  let textLayer: CATextLayer
  
  /// The detected object's class name
  var className: String = ""
  
  /// The detected object's confidence score
  var confidence: Float = 0.0
  
  /// The detected object's translation (if available)
  var translation: (chinese: String, pinyin: String)? = nil
  
  /// The center position of the bounding box for tracking
  var centerPosition: CGPoint = .zero
  
  /// Unique ID for this bounding box instance
  var boxId: UUID = UUID()

  /// Initializes a new BoundingBoxView with configured shape and text layers.
  override init(frame: CGRect) {
    shapeLayer = CAShapeLayer()
    shapeLayer.fillColor = UIColor.clear.cgColor  // No fill to only show the bounding outline
    shapeLayer.lineWidth = 4  // Set the stroke line width
    shapeLayer.isHidden = true  // Initially hidden; shown when a detection occurs

    textLayer = CATextLayer()
    textLayer.isHidden = true  // Initially hidden; shown with label when a detection occurs
    textLayer.contentsScale = UIScreen.main.scale  // Ensure the text is sharp on retina displays
    textLayer.fontSize = 14  // Set font size for the label text
    textLayer.font = UIFont(name: "Avenir", size: textLayer.fontSize)  // Use Avenir font for labels
    textLayer.alignmentMode = .center  // Center-align the text within the layer
    
    super.init(frame: frame)
    
    // Add layers to the view
    layer.addSublayer(shapeLayer)
    layer.addSublayer(textLayer)
    
    // Enable user interaction
    isUserInteractionEnabled = true
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Updates the bounding box and label to be visible with specified properties.
  /// - Parameters:
  ///   - frame: The CGRect frame defining the bounding box's size and position.
  ///   - label: The text label to display (e.g., object class and confidence).
  ///   - color: The color of the bounding box stroke and label background.
  ///   - alpha: The opacity level for the bounding box stroke and label background.
  func show(frame: CGRect, label: String, color: UIColor, alpha: CGFloat) {
    CATransaction.setDisableActions(true)  // Disable implicit animations

    // Validate the frame - don't proceed if it contains NaN values
    if frame.origin.x.isNaN || frame.origin.y.isNaN || 
       frame.size.width.isNaN || frame.size.height.isNaN {
        print("Warning: Invalid frame with NaN values detected. Skipping box update.")
        hide() // Hide the box instead of causing a crash
        return
    }
    
    // Ensure width and height are positive and not zero
    if frame.size.width <= 0 || frame.size.height <= 0 {
        print("Warning: Invalid frame size (zero or negative). Skipping box update.")
        hide()
        return
    }
    
    // Make the frame slightly larger to be easier to tap - expand by 10% but minimum 10px each side
    let expandAmount = max(10.0, min(frame.width * 0.1, frame.height * 0.1))
    let expandedFrame = frame.insetBy(dx: -expandAmount, dy: -expandAmount)
    
    // Update the view's frame with validated and expanded values
    self.frame = expandedFrame
    
    // Store the center position for tracking
    // Make sure center is within valid screen coordinates
    let validMidX = max(0, min(UIScreen.main.bounds.width, frame.midX))
    let validMidY = max(0, min(UIScreen.main.bounds.height, frame.midY))
    self.centerPosition = CGPoint(x: validMidX, y: validMidY)
    
    // Make sure the view is visible
    self.isHidden = false
    self.alpha = 1.0
    
    // Ensure the bounding box is above the AR content
    self.layer.zPosition = 100
    
    // Set the shape layer properties
    shapeLayer.lineWidth = 5  // Slightly thicker line for better visibility
    
    // Create path based on the original object size (not expanded hitbox)
    let originalRect = CGRect(
        x: expandAmount, 
        y: expandAmount, 
        width: frame.width, 
        height: frame.height
    )
    let path = UIBezierPath(roundedRect: originalRect, cornerRadius: 8.0)  // Rounded rectangle with more rounded corners
    shapeLayer.path = path.cgPath
    shapeLayer.strokeColor = color.withAlphaComponent(alpha + 0.2).cgColor  // Slightly more opaque for better visibility
    shapeLayer.isHidden = false  // Make the shape layer visible
    
    // Add a subtle pulsing animation to the box to make it more noticeable
    addPulseAnimation()

    textLayer.string = label  // Set the label text
    textLayer.backgroundColor = color.withAlphaComponent(alpha + 0.1).cgColor  // Slightly more opaque background
    textLayer.isHidden = false  // Make the text layer visible
    textLayer.foregroundColor = UIColor.white.cgColor  // Set text color with full opacity
    textLayer.fontSize = 16  // Slightly larger font
    
    // Add a subtle shadow to make text more visible against AR content
    textLayer.shadowOpacity = 0.8
    textLayer.shadowColor = UIColor.black.cgColor
    textLayer.shadowOffset = CGSize(width: 0, height: 1)
    textLayer.shadowRadius = 2

    // Calculate the text size and position based on the label content
    let attributes = [NSAttributedString.Key.font: textLayer.font as Any]
    let textRect = label.boundingRect(
      with: CGSize(width: 400, height: 100),
      options: .truncatesLastVisibleLine,
      attributes: attributes, context: nil)
    let textSize = CGSize(width: textRect.width + 12, height: textRect.height + 4)  // Add more padding
    let textOrigin = CGPoint(x: 0, y: -textSize.height - 2)  // Position above the bounding box
    textLayer.frame = CGRect(origin: textOrigin, size: textSize)  // Set the text layer frame
    textLayer.cornerRadius = 4  // Rounded corners for the text background
  }

  /// Hides the bounding box and text layers.
  func hide() {
    shapeLayer.isHidden = true
    textLayer.isHidden = true
  }
  
  // Add a subtle pulsing animation to make the box more noticeable
  private func addPulseAnimation() {
    // Remove any existing animations
    shapeLayer.removeAnimation(forKey: "pulseAnimation")
    
    // Create a subtle pulse animation
    let pulseAnimation = CABasicAnimation(keyPath: "lineWidth")
    pulseAnimation.fromValue = shapeLayer.lineWidth
    pulseAnimation.toValue = shapeLayer.lineWidth - 1.0
    pulseAnimation.duration = 1.0
    pulseAnimation.autoreverses = true
    pulseAnimation.repeatCount = Float.infinity
    pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    
    // Add the animation
    shapeLayer.add(pulseAnimation, forKey: "pulseAnimation")
  }
}
