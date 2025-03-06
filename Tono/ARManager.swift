// ARManager.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import Foundation
import ARKit
import SwiftUI
import RealityKit
import Combine
import UIKit

// This class will manage our AR session and object recognition
class ARManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var capturedImage: UIImage?
    @Published var showObjectPopup = false
    @Published var detectedObjects: [DetectedObject] = []
    @Published var selectedObject: DetectedObject?
    
    // Object recognition manager
    let objectRecognitionManager = ObjectRecognitionManager()
    
    // AR Session for handling AR functionality
    let session = ARSession()
    
    // Configuration for AR session
    let configuration = ARWorldTrackingConfiguration()
    
    // Timer for periodic object detection
    private var detectionTimer: Timer?
    
    // Dictionary to store node references for labels
    private var labelNodes: [UUID: SCNNode] = [:]
    
    // Initialize the AR Manager
    override init() {
        super.init()
        
        // Set up the AR session
        session.delegate = self
        
        // Configure AR features
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        // Check if device supports these features
        guard ARWorldTrackingConfiguration.isSupported else {
            print("AR World Tracking is not supported on this device")
            return
        }
    }
    
    // Start the AR session
    func startSession() {
        print("Starting AR session...")
        
        // Configure the session for better tracking
        configuration.isLightEstimationEnabled = true
        configuration.worldAlignment = .gravity
        
        // Run the session
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        
        // Start periodic object detection
        startObjectDetection()
    }
    
    // Pause the AR session
    func pauseSession() {
        session.pause()
        isSessionRunning = false
        
        // Stop object detection
        stopObjectDetection()
    }
    
    // Reset the AR session
    func resetSession() {
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Clear all labels
        clearAllLabels()
        
        // Restart object detection
        if isSessionRunning {
            stopObjectDetection()
            startObjectDetection()
        }
    }
    
    // Start periodic object detection
    private func startObjectDetection() {
        print("Starting object detection...")
        
        // We'll primarily use the ARSessionDelegate for frame processing
        // But we'll also keep a backup timer with a longer interval
        
        // Process the first frame immediately
        DispatchQueue.main.async {
            self.captureAndProcessFrame()
        }
        
        // Set up a backup timer with a longer interval
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            print("Backup timer triggered object detection")
            self?.captureAndProcessFrame()
        }
        
        print("Object detection started - using ARSessionDelegate with backup timer")
    }
    
    // Stop periodic object detection
    private func stopObjectDetection() {
        detectionTimer?.invalidate()
        detectionTimer = nil
    }
    
    // Capture and process the current AR frame
    private func captureAndProcessFrame() {
        guard let currentFrame = session.currentFrame else {
            print("No current frame available")
            return
        }
        
        print("Processing AR frame for object detection")
        
        // Get the pixel buffer directly from the AR frame
        let pixelBuffer = currentFrame.capturedImage
        
        // Check if the pixel buffer is valid
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        if width == 0 || height == 0 {
            print("Invalid pixel buffer dimensions: \(width)x\(height)")
            return
        }
        
        // Process the pixel buffer directly for object recognition
        objectRecognitionManager.processPixelBuffer(pixelBuffer)
        
        // Update detected objects and display labels
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Small delay to ensure detection is complete
            if let detection = self.objectRecognitionManager.currentDetection {
                print("Detected: \(detection.englishName) (\(detection.chineseName)) with \(detection.formattedConfidence) confidence")
                
                // Check if this object is already detected
                if !self.detectedObjects.contains(where: { $0.englishName == detection.englishName }) {
                    self.detectedObjects.append(detection)
                    
                    // Place a 3D label for the object in the scene
                    if let sceneView = self.getSceneView() {
                        self.placeLabel(for: detection, in: sceneView)
                    } else {
                        print("Could not get ARSCNView to place label")
                    }
                } else {
                    print("Object already detected, not adding a new label")
                }
            } else {
                print("No objects detected in this frame")
            }
        }
    }
    
    // Convert AR frame to UIImage
    private func convertFrameToUIImage(_ frame: ARFrame) -> UIImage {
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // Manually trigger object detection
    func detectObject() {
        captureAndProcessFrame()
    }
    
    // Handle tap gesture
    func handleTap(at point: CGPoint, in sceneView: ARSCNView) {
        // Perform hit test to find objects at the tapped location
        let hitTestResults = sceneView.hitTest(point, options: [.boundingBoxOnly: true])
        
        // Check if any label node was tapped
        for result in hitTestResults {
            let node = result.node
            
            // Find the detected object associated with this node
            if let objectId = labelNodes.first(where: { $0.value == node })?.key,
               let tappedObject = detectedObjects.first(where: { $0.id == objectId }) {
                
                // Set the selected object and show popup
                selectedObject = tappedObject
                showObjectPopup = true
                return
            }
        }
        
        // If no label was tapped, try to detect a new object
        detectObject()
    }
    
    // Place a 3D label in the AR scene for a detected object
    func placeLabel(for detectedObject: DetectedObject, in arView: ARSCNView) {
        print("Placing label for \(detectedObject.englishName) with bounding box: \(detectedObject.boundingBox)")
        
        // Get the current AR frame
        guard let currentFrame = arView.session.currentFrame else {
            print("No current frame available")
            return
        }
        
        // Get the camera transform
        let cameraTransform = currentFrame.camera.transform
        
        // Calculate the position for the label based on the bounding box
        // The bounding box is in normalized coordinates (0,0) to (1,1)
        // We need to convert this to 3D world coordinates
        
        // Get the center of the bounding box in normalized coordinates
        let centerX = detectedObject.boundingBox.midX
        let centerY = detectedObject.boundingBox.midY
        
        print("Bounding box center: (\(centerX), \(centerY))")
        
        // Convert to points in the screen space
        let screenWidth = arView.bounds.width
        let screenHeight = arView.bounds.height
        let screenPoint = CGPoint(
            x: centerX * screenWidth,
            y: centerY * screenHeight
        )
        
        print("Screen point: (\(screenPoint.x), \(screenPoint.y)) from screen size: \(screenWidth)x\(screenHeight)")
        
        // Create the label content
        let labelText = "\(detectedObject.chineseName)\n\(detectedObject.pinyin)"
        print("Label text: '\(labelText)'")
        
        // Create the text node
        let textNode = createTextNode(text: labelText, fontSize: 24)
        
        // Try to position the label using hit testing first
        var hitTestResults = arView.hitTest(screenPoint, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
        
        if hitTestResults.isEmpty {
            print("No planes found, trying feature points")
            hitTestResults = arView.hitTest(screenPoint, types: [.featurePoint])
        }
        
        if let hitResult = hitTestResults.first {
            // Use the hit test result position with a vertical offset to place above the object
            let position = SCNVector3(
                hitResult.worldTransform.columns.3.x,
                hitResult.worldTransform.columns.3.y + 0.1, // Add a small offset to position above the object
                hitResult.worldTransform.columns.3.z
            )
            
            // Position the node
            textNode.position = position
            
            // Add the node to the scene
            arView.scene.rootNode.addChildNode(textNode)
            
            print("Label placed at position: \(position) using hit test")
            
            // Store the node for later reference
            labelNodes[detectedObject.id] = textNode
        } else {
            // Fallback: Place the label in front of the camera
            print("No hit test results, placing label in front of camera")
            
            // Create a position 1 meter in front of the camera
            let distance: Float = 1.0  // 1 meter in front of the camera
            let position = SCNVector3(
                cameraTransform.columns.3.x - cameraTransform.columns.2.x * distance,
                cameraTransform.columns.3.y - cameraTransform.columns.2.y * distance,
                cameraTransform.columns.3.z - cameraTransform.columns.2.z * distance
            )
            
            // Position the node
            textNode.position = position
            
            // Add the node to the scene
            arView.scene.rootNode.addChildNode(textNode)
            
            print("Label placed at position: \(position) in front of camera")
            
            // Store the node for later reference
            labelNodes[detectedObject.id] = textNode
        }
        
        // Limit the number of labels to avoid cluttering the scene
        if labelNodes.count > 10 {
            // Remove the oldest node (first key in the dictionary)
            if let oldestKey = labelNodes.keys.first {
                labelNodes[oldestKey]?.removeFromParentNode()
                labelNodes.removeValue(forKey: oldestKey)
            }
        }
    }
    
    // Create a 3D text node
    private func createTextNode(text: String, fontSize: CGFloat) -> SCNNode {
        // Create a 3D text node similar to CoreML-in-ARKit
        
        // Create a parent node
        let parentNode = SCNNode()
        
        // Create 3D text geometry
        let textGeometry = SCNText(string: text, extrusionDepth: 0.1)
        
        // Configure the text appearance
        textGeometry.font = UIFont.boldSystemFont(ofSize: 1.0) // Size will be scaled by the node
        textGeometry.flatness = 0.1 // Lower values = smoother text
        textGeometry.chamferRadius = 0.0 // No chamfer
        
        // Set the text color to orange
        let orangeColor = UIColor.orange
        textGeometry.firstMaterial?.diffuse.contents = orangeColor
        textGeometry.firstMaterial?.specular.contents = UIColor.white
        textGeometry.firstMaterial?.isDoubleSided = true
        textGeometry.firstMaterial?.lightingModel = .constant // Ensure consistent lighting
        
        // Create a node with the text geometry
        let textNode = SCNNode(geometry: textGeometry)
        
        // Center the text
        let (min, max) = textGeometry.boundingBox
        let width = max.x - min.x
        let height = max.y - min.y
        textNode.pivot = SCNMatrix4MakeTranslation(width/2, height/2, 0)
        
        // Scale the text to a reasonable size
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        
        // Add the text node to the parent
        parentNode.addChildNode(textNode)
        
        // Add a billboard constraint to make the text always face the camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y, .Z]
        parentNode.constraints = [billboardConstraint]
        
        // Add a simple animation to make the node more noticeable
        let scaleAction = SCNAction.sequence([
            SCNAction.scale(to: 1.2, duration: 0.2),
            SCNAction.scale(to: 1.0, duration: 0.2)
        ])
        parentNode.runAction(scaleAction)
        
        // Add a subtle floating animation to make the label hover
        let floatUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 1.0)
        let floatDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 1.0)
        let floatSequence = SCNAction.sequence([floatUp, floatDown])
        let floatForever = SCNAction.repeatForever(floatSequence)
        parentNode.runAction(floatForever)
        
        print("Created 3D text node with text: '\(text)'")
        
        return parentNode
    }
    
    // Clear all labels from the scene
    private func clearAllLabels() {
        guard let sceneView = getSceneView() else { return }
        
        for (_, node) in labelNodes {
            node.removeFromParentNode()
        }
        
        labelNodes.removeAll()
        detectedObjects.removeAll()
    }
    
    // Helper to get the ARSCNView
    private func getSceneView() -> ARSCNView? {
        print("Attempting to find ARSCNView in view hierarchy")
        
        // This is a workaround since we're using ARView from RealityKit
        // In a real implementation, you would have direct access to the ARSCNView
        
        // Find the ARSCNView in the view hierarchy
        for window in UIApplication.shared.windows {
            print("Searching window: \(window)")
            if let arView = findARSCNView(in: window) {
                print("Found ARSCNView in window")
                return arView
            }
        }
        
        print("ARSCNView not found in view hierarchy")
        return nil
    }
    
    // Recursively search for ARSCNView in view hierarchy
    private func findARSCNView(in view: UIView) -> ARSCNView? {
        if let arView = view as? ARSCNView {
            return arView
        }
        
        for subview in view.subviews {
            if let arView = findARSCNView(in: subview) {
                return arView
            }
        }
        
        return nil
    }
}

// Extension to handle AR session delegate methods
extension ARManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process frames at a reasonable interval (approximately every 0.5 seconds)
        // Using truncatingRemainder to handle floating point timestamps
        if frame.timestamp.truncatingRemainder(dividingBy: 0.5) < 0.1 {
            // Get the pixel buffer directly from the AR frame
            let pixelBuffer = frame.capturedImage
            
            // Check if the pixel buffer is valid
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            if width == 0 || height == 0 {
                print("Invalid pixel buffer dimensions in didUpdate: \(width)x\(height)")
                return
            }
            
            // Process the pixel buffer directly for object recognition
            objectRecognitionManager.processPixelBuffer(pixelBuffer)
            
            // Update detected objects and display labels in the main thread
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Small delay to ensure detection is complete
                if let detection = self.objectRecognitionManager.currentDetection {
                    print("Detected via delegate: \(detection.englishName) (\(detection.chineseName)) with \(detection.formattedConfidence) confidence")
                    
                    // Check if this object is already detected
                    if !self.detectedObjects.contains(where: { $0.englishName == detection.englishName }) {
                        self.detectedObjects.append(detection)
                        
                        // Place a 3D label for the object in the scene
                        self.placeLabel(for: detection, in: self.getSceneView()!)
                    } else {
                        print("Object already detected (via delegate), not adding a new label")
                    }
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Handle session failures
        print("AR Session failed: \(error.localizedDescription)")
        isSessionRunning = false
        stopObjectDetection()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Handle session interruptions
        print("AR Session was interrupted")
        isSessionRunning = false
        stopObjectDetection()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Handle end of interruption
        print("AR Session interruption ended")
        resetSession()
    }
}

// SwiftUI wrapper for ARView
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARManager
    
    func makeUIView(context: Context) -> ARSCNView {
        print("Creating ARSCNView")
        
        // Create the AR view
        let arView = ARSCNView(frame: .zero)
        
        // Configure the view
        arView.session = arManager.session
        arView.automaticallyUpdatesLighting = true
        arView.autoenablesDefaultLighting = true
        
        // Set debug options for development
        #if DEBUG
        // Uncomment to see feature points
        // arView.debugOptions = [.showFeaturePoints]
        #endif
        
        // Create a default scene
        let scene = SCNScene()
        arView.scene = scene
        
        // Set the delegate to receive rendering callbacks
        arView.delegate = context.coordinator
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        print("ARSCNView created and configured")
        
        // Start the session when the view is created
        arManager.startSession()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update the view if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARSCNView else { 
                print("Tap gesture view is not ARSCNView")
                return 
            }
            
            let location = gesture.location(in: arView)
            print("Tap detected at \(location)")
            
            // Pass the tap to the AR manager
            parent.arManager.handleTap(at: location, in: arView)
        }
        
        // ARSCNViewDelegate methods
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // This method is called once per frame
            // You can use it for custom rendering logic
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            // This method is called when a new anchor is added to the scene
            print("Added anchor to scene: \(anchor)")
        }
    }
}

// Helper extension for matrix transformations
extension simd_float4x4 {
    func transformVector(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let x = columns.0.x * vector.x + columns.1.x * vector.y + columns.2.x * vector.z
        let y = columns.0.y * vector.x + columns.1.y * vector.y + columns.2.y * vector.z
        let z = columns.0.z * vector.x + columns.1.z * vector.y + columns.2.z * vector.z
        return SIMD3<Float>(x, y, z)
    }
}

// Helper function to create a SIMD3<Float>
func simd_make_float3(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> {
    return SIMD3<Float>(x, y, z)
} 