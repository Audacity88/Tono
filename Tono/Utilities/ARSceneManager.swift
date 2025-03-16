//
//  ARSceneManager.swift
//  YOLO
//
//  Created as part of the Tono integration
//

import UIKit
import SceneKit
import ARKit
import AVFoundation

class ARSceneManager: NSObject, ARSCNViewDelegate {
    // AR Scene View
    var sceneView: ARSCNView!
    
    // Parent view controller
    weak var viewController: UIViewController?
    
    // Text depth for 3D text
    let bubbleDepth: Float = 0.01
    
    // Store placed nodes to prevent duplicates
    var placedNodes: [SCNNode] = []
    
    // Text-to-speech synthesizer
    let speechSynthesizer = AVSpeechSynthesizer()
    
    // Translation manager
    let translationManager = TranslationManager.shared
    
    // Initialize with a view controller
    init(viewController: UIViewController) {
        super.init()
        self.viewController = viewController
        
        // Create the AR SceneView
        sceneView = ARSCNView(frame: viewController.view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Make the scene view transparent so only AR content is visible
        sceneView.backgroundColor = UIColor.clear
        
        // Remove the default lighting to avoid interference with camera view
        sceneView.automaticallyUpdatesLighting = false
        
        // Enable Default Lighting - makes the 3D text a bit poppier
        sceneView.autoenablesDefaultLighting = true
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognize:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Set up audio session for playback
        setupAudioSession()
    }
    
    // Set up the AR session
    func setupARSession() {
        // Create the configuration on a background thread to avoid freezing the UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create a session configuration
            let configuration = ARWorldTrackingConfiguration()
            
            // Enable plane detection for better AR placement
            configuration.planeDetection = [.horizontal, .vertical]
            
            // Optimize AR configuration for performance
            if #available(iOS 13.0, *) {
                // Only use person segmentation if needed
                // configuration.frameSemantics.insert(.personSegmentationWithDepth)
            }
            
            // Run the session on the main thread
            DispatchQueue.main.async {
                // Set lower frame rate to reduce CPU usage
                self.sceneView.preferredFramesPerSecond = 30
                
                // Disable unnecessary features to improve performance
                self.sceneView.antialiasingMode = .none
                
                // Set the session debug options to show feature points
                self.sceneView.debugOptions = []
                
                // Run the view's session with automatic configuration
                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                print("AR session started with optimized configuration")
                
                // Make sure the AR view is transparent to allow bounding boxes to be visible
                self.sceneView.backgroundColor = UIColor.clear
                self.sceneView.isOpaque = false
            }
        }
    }
    
    // Pause the AR session
    func pauseARSession() {
        sceneView.session.pause()
    }
    
    // Resume the AR session
    func resumeARSession() {
        // Create the configuration on a background thread to avoid freezing the UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            
            // Optimize AR configuration for performance
            if #available(iOS 13.0, *) {
                // Only use person segmentation if needed
                // configuration.frameSemantics.insert(.personSegmentationWithDepth)
            }
            
            // Run the session on the main thread
            DispatchQueue.main.async {
                // Set lower frame rate to reduce CPU usage
                self.sceneView.preferredFramesPerSecond = 30
                
                // Run the session with the new configuration
                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                print("AR session resumed with optimized configuration")
                
                // Make sure the AR view is transparent to allow bounding boxes to be visible
                self.sceneView.backgroundColor = UIColor.clear
                self.sceneView.isOpaque = false
            }
        }
    }
    
    // Set up audio session for playback
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // Update the current detection for AR placement
    func updateCurrentDetection(english: String, chinese: String, pinyin: String) {
        // Store the detection for use when the user taps to place a label
        if let viewController = viewController as? ViewController {
            viewController.currentDetection = (english: english, chinese: chinese, pinyin: pinyin)
            
            // Optionally, we could automatically place AR labels for high-confidence detections
            // This is commented out to avoid cluttering the AR space
            /*
            // Get the camera position
            guard let frame = sceneView.session.currentFrame else { return }
            let cameraTransform = frame.camera.transform
            
            // Create a position 0.5 meters in front of the camera
            let positionColumn = cameraTransform.columns.3
            let cameraPosition = SCNVector3(positionColumn.x, positionColumn.y, positionColumn.z)
            let cameraDirection = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
            let position = SCNVector3(
                cameraPosition.x + cameraDirection.x * 0.5,
                cameraPosition.y + cameraDirection.y * 0.5,
                cameraPosition.z + cameraDirection.z * 0.5
            )
            
            // Check if there's already a node for this object nearby
            if !isPositionNearExistingNode(position) && !isNodeForObject(english) {
                // Create and place the AR label
                let node = createNewBubbleParentNode(english: english, chinese: chinese, pinyin: pinyin)
                sceneView.scene.rootNode.addChildNode(node)
                node.position = position
                placedNodes.append(node)
            }
            */
        }
    }
    
    // Check if there's already a node for this object
    func isNodeForObject(_ objectName: String) -> Bool {
        for node in placedNodes {
            if let nodeName = node.name, nodeName.contains(objectName) {
                return true
            }
        }
        return false
    }
    
    // Handle tap on the AR scene
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        print("ARSceneManager: handleTap called")
        
        // Get tap location in the AR scene view
        let location = gestureRecognize.location(in: sceneView)
        print("Tap location in AR view: \(location)")
        
        // Perform hit test against existing nodes with a larger search area
        let hitTestOptions = [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
                              SCNHitTestOption.boundingBoxOnly: true] as [SCNHitTestOption: Any]
        let hitTestResults = sceneView.hitTest(location, options: hitTestOptions)
        
        // Check if we hit an existing node
        if let hitNode = hitTestResults.first?.node {
            print("Hit test found node: \(hitNode.name ?? "unnamed"), geometry: \(String(describing: hitNode.geometry))")
            
            // Find the parent node that contains our label data
            var currentNode: SCNNode? = hitNode
            while currentNode != nil {
                print("Checking node: \(currentNode?.name ?? "unnamed"), geometry: \(String(describing: currentNode?.geometry))")
                if let nodeName = currentNode?.name, nodeName.contains("|") {
                    let components = nodeName.components(separatedBy: "|")
                    if components.count >= 3 {
                        let english = components[0]
                        let chinese = components[1]
                        let pinyin = components[2]
                        print("Playing pronunciation for: \(chinese) (\(pinyin))")
                        
                        // Provide visual feedback
                        highlightNode(currentNode!)
                        
                        // Play pronunciation with a slight delay to ensure UI feedback happens first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.playPronunciation(for: chinese, pinyin: pinyin)
                        }
                        
                        // Provide haptic feedback if available
                        if let viewController = viewController as? ViewController {
                            viewController.selection.selectionChanged()
                        }
                        return
                    }
                }
                currentNode = currentNode?.parent
            }
        }
        
        // If we didn't hit an existing node, perform a hit test against AR features
        let arHitTestResults = sceneView.hitTest(location, types: [.featurePoint])
        print("AR hit test results count: \(arHitTestResults.count)")
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform = closestResult.worldTransform
            let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            print("Hit test world coordinates: \(worldCoord)")
            
            // Check if there's already a node close to this position
            if isPositionNearExistingNode(worldCoord) {
                print("Position is near existing node, not creating new node")
                // If there's a node nearby, don't create a new one
                // Find the closest node and play its pronunciation
                if let closestNode = findClosestNode(to: worldCoord) {
                    // Extract the word data from the node name
                    if let nodeName = closestNode.name, nodeName.contains("|") {
                        let components = nodeName.components(separatedBy: "|")
                        if components.count >= 3 {
                            let english = components[0]
                            let chinese = components[1]
                            let pinyin = components[2]
                            
                            // Provide visual feedback
                            highlightNode(closestNode)
                            
                            // Play pronunciation with a slight delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.playPronunciation(for: chinese, pinyin: pinyin)
                            }
                            
                            // Provide haptic feedback if available
                            if let viewController = viewController as? ViewController {
                                viewController.selection.selectionChanged()
                            }
                        }
                    }
                }
                return
            }
            
            // Get the current detection from the view controller
            if let viewController = viewController as? ViewController, 
               let detection = viewController.currentDetection {
                print("Creating 3D text for: \(detection.english) - \(detection.chinese) (\(detection.pinyin))")
                // Create 3D Text with Chinese translation and pinyin
                let node = createNewBubbleParentNode(
                    english: detection.english,
                    chinese: detection.chinese,
                    pinyin: detection.pinyin
                )
                sceneView.scene.rootNode.addChildNode(node)
                node.position = worldCoord
                
                // Store the node to prevent duplicates
                placedNodes.append(node)
                print("Added node to placedNodes array. Total nodes: \(placedNodes.count)")
                
                // Play pronunciation audio
                playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
                
                // Provide haptic feedback if available
                if let viewController = viewController as? ViewController {
                    viewController.selection.selectionChanged()
                }
            } else {
                print("No current detection available")
                if let viewController = viewController as? ViewController {
                    print("ViewController exists but currentDetection is nil")
                } else {
                    print("ViewController is nil")
                }
            }
        } else {
            print("No AR hit test results found")
        }
    }
    
    // Create a new 3D text node
    func createNewBubbleParentNode(english: String, chinese: String, pinyin: String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // Create a parent node for all text elements
        let bubbleNodeParent = SCNNode()
        
        // Add a background plane to make text more visible
        let backgroundPlane = SCNPlane(width: 0.2, height: 0.15)
        backgroundPlane.cornerRadius = 0.02
        let backgroundMaterial = SCNMaterial()
        backgroundMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.7)
        backgroundPlane.materials = [backgroundMaterial]
        
        let backgroundNode = SCNNode(geometry: backgroundPlane)
        backgroundNode.position = SCNVector3(0, -0.05, -0.01) // Slightly behind text
        bubbleNodeParent.addChildNode(backgroundNode)
        
        // CHINESE TEXT
        let chineseText = SCNText(string: chinese, extrusionDepth: CGFloat(bubbleDepth))
        var chineseFont = UIFont(name: "PingFangSC-Semibold", size: 0.15)
        chineseFont = chineseFont?.withTraits(traits: .traitBold)
        chineseText.font = chineseFont
        chineseText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        chineseText.firstMaterial?.diffuse.contents = UIColor.red
        chineseText.firstMaterial?.specular.contents = UIColor.white
        chineseText.firstMaterial?.isDoubleSided = true
        chineseText.chamferRadius = CGFloat(bubbleDepth)
        
        // Add a slight outline to make text more visible
        chineseText.firstMaterial?.emission.contents = UIColor.red.withAlphaComponent(0.5)
        
        // CHINESE NODE
        let (minBoundChinese, maxBoundChinese) = chineseText.boundingBox
        let chineseNode = SCNNode(geometry: chineseText)
        chineseNode.pivot = SCNMatrix4MakeTranslation((maxBoundChinese.x - minBoundChinese.x)/2, minBoundChinese.y, bubbleDepth/2)
        chineseNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // PINYIN TEXT
        let pinyinText = SCNText(string: pinyin, extrusionDepth: CGFloat(bubbleDepth))
        let pinyinFont = UIFont(name: "Avenir-Medium", size: 0.12)
        pinyinText.font = pinyinFont
        pinyinText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        pinyinText.firstMaterial?.diffuse.contents = UIColor.orange
        pinyinText.firstMaterial?.specular.contents = UIColor.white
        pinyinText.firstMaterial?.isDoubleSided = true
        pinyinText.chamferRadius = CGFloat(bubbleDepth)
        
        // Add a slight outline to make text more visible
        pinyinText.firstMaterial?.emission.contents = UIColor.orange.withAlphaComponent(0.5)
        
        // PINYIN NODE
        let (minBoundPinyin, maxBoundPinyin) = pinyinText.boundingBox
        let pinyinNode = SCNNode(geometry: pinyinText)
        pinyinNode.pivot = SCNMatrix4MakeTranslation((maxBoundPinyin.x - minBoundPinyin.x)/2, minBoundPinyin.y, bubbleDepth/2)
        pinyinNode.scale = SCNVector3Make(0.15, 0.15, 0.15)
        pinyinNode.position = SCNVector3(0, -0.05, 0)
        
        // ENGLISH TEXT
        let englishText = SCNText(string: english, extrusionDepth: CGFloat(bubbleDepth))
        let englishFont = UIFont(name: "Avenir-Light", size: 0.1)
        englishText.font = englishFont
        englishText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        englishText.firstMaterial?.diffuse.contents = UIColor.white
        englishText.firstMaterial?.specular.contents = UIColor.white
        englishText.firstMaterial?.isDoubleSided = true
        englishText.chamferRadius = CGFloat(bubbleDepth)
        
        // Add a slight outline to make text more visible
        englishText.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.5)
        
        // ENGLISH NODE
        let (minBoundEnglish, maxBoundEnglish) = englishText.boundingBox
        let englishNode = SCNNode(geometry: englishText)
        englishNode.pivot = SCNMatrix4MakeTranslation((maxBoundEnglish.x - minBoundEnglish.x)/2, minBoundEnglish.y, bubbleDepth/2)
        englishNode.scale = SCNVector3Make(0.15, 0.15, 0.15)
        englishNode.position = SCNVector3(0, -0.1, 0)
        
        // CENTRE POINT NODE - Make it smaller and less visible
        let sphere = SCNSphere(radius: 0.002)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.5)
        let sphereNode = SCNNode(geometry: sphere)
        
        // Add all nodes to parent
        bubbleNodeParent.addChildNode(chineseNode)
        bubbleNodeParent.addChildNode(pinyinNode)
        bubbleNodeParent.addChildNode(englishNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        // Store the current word data with the node
        bubbleNodeParent.name = "\(english)|\(chinese)|\(pinyin)"
        
        // Add a subtle animation to make the node appear
        bubbleNodeParent.opacity = 0
        let fadeInAction = SCNAction.fadeIn(duration: 0.5)
        let scaleAction = SCNAction.scale(to: 1.0, duration: 0.5)
        let groupAction = SCNAction.group([fadeInAction, scaleAction])
        bubbleNodeParent.runAction(groupAction)
        
        return bubbleNodeParent
    }
    
    // Function to play pronunciation using text-to-speech
    func playPronunciation(for chineseText: String, pinyin: String) {
        print("Playing pronunciation for: \(chineseText) (\(pinyin))")
        
        // Create a speech utterance with the Chinese text
        let utterance = AVSpeechUtterance(string: chineseText)
        
        // Set the voice to Chinese (Mandarin)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        
        // Adjust speech rate (0.0 to 1.0, default is 0.5)
        utterance.rate = 0.0  // Slow rate for better clarity
        
        // Adjust pitch (0.5 to 2.0, default is 1.0)
        utterance.pitchMultiplier = 1.0
        
        // Adjust volume (0.0 to 1.0, default is 1.0)
        utterance.volume = 1.0
        
        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Speak the text
        speechSynthesizer.speak(utterance)
    }
    
    // Check if a node is in our placed nodes array
    func isNodeInPlacedNodes(_ node: SCNNode) -> Bool {
        // Check if the node or any of its parents are in our placed nodes array
        var currentNode: SCNNode? = node
        while currentNode != nil {
            if placedNodes.contains(currentNode!) {
                return true
            }
            currentNode = currentNode?.parent
        }
        return false
    }
    
    // Check if a position is near an existing node
    func isPositionNearExistingNode(_ position: SCNVector3) -> Bool {
        let threshold: Float = 0.2 // 20cm threshold
        
        for node in placedNodes {
            let distance = distance(position, node.position)
            if distance < threshold {
                return true
            }
        }
        
        return false
    }
    
    // Find the closest node to a position
    func findClosestNode(to position: SCNVector3) -> SCNNode? {
        var closestNode: SCNNode? = nil
        var closestDistance: Float = Float.greatestFiniteMagnitude
        
        for node in placedNodes {
            let dist = distance(position, node.position)
            if dist < closestDistance {
                closestDistance = dist
                closestNode = node
            }
        }
        
        return closestNode
    }
    
    // Calculate distance between two 3D points
    func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    // Highlight a node briefly to provide visual feedback
    func highlightNode(_ node: SCNNode) {
        // Save original scale
        let originalScale = node.scale
        
        // Scale up
        node.scale = SCNVector3(
            originalScale.x * 1.2,
            originalScale.y * 1.2,
            originalScale.z * 1.2
        )
        
        // Scale back down after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            node.scale = originalScale
        }
    }
    
    // Clear all labels
    func clearLabels() {
        // Remove all placed nodes
        for node in placedNodes {
            node.removeFromParentNode()
        }
        placedNodes.removeAll()
    }
}

// Extension to add traits to UIFont
extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

// Extension to rotate UIImage
extension UIImage {
    func rotate90DegreesClockwise() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.height, height: size.width))
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: 0, y: size.width)
            ctx.cgContext.rotate(by: -CGFloat.pi/2)
            draw(at: .zero)
        }
    }
} 