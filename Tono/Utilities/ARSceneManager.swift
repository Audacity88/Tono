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
        
        // Make the scene view completely transparent so only AR content is visible
        sceneView.backgroundColor = UIColor.clear
        sceneView.isOpaque = false
        
        // Remove the default lighting to avoid interference with camera view
        sceneView.automaticallyUpdatesLighting = false
        
        // Enable Default Lighting - makes the 3D text a bit poppier
        sceneView.autoenablesDefaultLighting = true
        
        // Disable debug options to remove any visual artifacts
        sceneView.debugOptions = []
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognize:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Set up audio session for playback
        setupAudioSession()
    }
    
    // Set up the AR session
    func setupARSession() {
        print("Setting up AR session from scratch")
        
        // Clean up any existing resources before setup
        cleanupARScene()
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection for better AR placement
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Disable unnecessary features to improve performance and reduce visual artifacts
        if #available(iOS 13.0, *) {
            // Explicitly disable person segmentation to avoid visual artifacts
            configuration.frameSemantics = []
        }
        
        // Run the session with the new configuration
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("AR session started with fresh configuration")
        
        // Configure view properties
        sceneView.preferredFramesPerSecond = 30
        sceneView.antialiasingMode = .none
        sceneView.debugOptions = []
        sceneView.backgroundColor = UIColor.clear
        sceneView.isOpaque = false
        
        // Disable any rendering of the point cloud or planes
        sceneView.rendersCameraGrain = false
        if #available(iOS 13.0, *) {
            sceneView.rendersMotionBlur = false
        }
        
        // Configure for text-only display
        configureARViewForTextOnly()
        
        // Add test labels
        addTestLabel()
        addFixedTextNode()
        
        // Print success message
        print("AR session setup complete with \(placedNodes.count) nodes")
    }
    
    // Clean up the AR scene to remove any visual artifacts
    func cleanupARScene() {
        // Remove all nodes except placed text nodes
        let rootNode = sceneView.scene.rootNode
        for child in rootNode.childNodes {
            // Skip our placed text nodes
            if !placedNodes.contains(child) {
                child.removeFromParentNode()
            }
        }
        
        // Remove any existing anchors
        let anchors = sceneView.session.currentFrame?.anchors ?? []
        for anchor in anchors {
            if !(anchor is ARPlaneAnchor) {
                sceneView.session.remove(anchor: anchor)
            }
        }
        
        // Create a clean scene if needed
        if sceneView.scene.rootNode.childNodes.isEmpty {
            let scene = SCNScene()
            sceneView.scene = scene
        }
    }
    
    // Pause the AR session
    func pauseARSession() {
        sceneView.session.pause()
    }
    
    // Resume the AR session
    func resumeARSession() {
        print("Resuming AR session")
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection for better AR placement
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Disable unnecessary features to improve performance and reduce visual artifacts
        if #available(iOS 13.0, *) {
            // Explicitly disable person segmentation to avoid visual artifacts
            configuration.frameSemantics = []
        }
        
        // Run the session with the new configuration
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("AR session resumed with fresh configuration")
        
        // Configure view properties
        sceneView.preferredFramesPerSecond = 30
        sceneView.antialiasingMode = .none
        sceneView.debugOptions = []
        sceneView.backgroundColor = UIColor.clear
        sceneView.isOpaque = false
        
        // Disable any rendering of the point cloud or planes
        sceneView.rendersCameraGrain = false
        if #available(iOS 13.0, *) {
            sceneView.rendersMotionBlur = false
        }
        
        // Configure for text-only display
        configureARViewForTextOnly()
        
        // Add test labels
        addTestLabel()
        addFixedTextNode()
        
        // Print success message
        print("AR session resume complete with \(placedNodes.count) nodes")
    }
    
    // Configure AR view for text-only display
    func configureARViewForTextOnly() {
        print("Configuring AR view for maximum text visibility")
        
        // Disable all debug options completely
        sceneView.debugOptions = []
        
        // Make sure the scene view background is completely transparent
        sceneView.backgroundColor = UIColor.clear
        sceneView.isOpaque = false
        
        // Set scene background to clear
        sceneView.scene.background.contents = UIColor.clear
        
        // Disable camera grain and motion blur for cleaner visuals
        sceneView.rendersCameraGrain = false
        if #available(iOS 13.0, *) {
            sceneView.rendersMotionBlur = false
        }
        
        // Set up bright lighting environment for better text visibility
        let lightingEnvironment = sceneView.scene.lightingEnvironment
        lightingEnvironment.intensity = 2.0 // Brighter lighting
        lightingEnvironment.contents = UIColor.white // White environment lighting
        
        // Add a directional light to ensure text is well-lit
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000 // Very bright light
        directionalLight.color = UIColor.white
        directionalLight.castsShadow = false
        
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(0, 10, 0)
        lightNode.eulerAngles = SCNVector3(-Float.pi/2, 0, 0) // Point down
        sceneView.scene.rootNode.addChildNode(lightNode)
        
        // Add ambient light for overall brightness
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 1000 // Very bright ambient light
        ambientLight.color = UIColor.white
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        sceneView.scene.rootNode.addChildNode(ambientNode)
        
        // Ensure all existing nodes are fully visible
        for node in placedNodes {
            // Force full opacity
            node.opacity = 1.0
            node.renderingOrder = 2000 // Very high rendering priority
            
            // Apply to all children
            for childNode in node.childNodes {
                childNode.opacity = 1.0
                childNode.renderingOrder = 2000
                
                // Make materials extra bright
                if let geometry = childNode.geometry {
                    for material in geometry.materials {
                        material.transparency = 0.0 // Fully opaque
                        material.lightingModel = .constant // No lighting effects
                        
                        // Increase emission intensity for better visibility
                        if let _ = material.emission.contents {
                            material.emission.intensity = 3.0 // Very bright emission
                        }
                    }
                }
            }
            
            // Add a billboard constraint if not already present
            if node.constraints == nil || node.constraints?.isEmpty ?? true {
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .all
                node.constraints = [billboardConstraint]
            }
        }
        
        // Log configuration completion
        print("AR view configured for maximum text visibility with \(placedNodes.count) visible nodes")
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
        print("📝 Creating AR text node: \(english) - \(chinese) (\(pinyin))")
        
        // Create a parent node to hold all text elements
        let bubbleNode = SCNNode()
        
        // Set a unique name for this node to identify it later
        bubbleNode.name = "\(english)|\(chinese)|\(pinyin)"
        
        // Create a background plane for better text visibility - MAKE IT LARGER
        let backgroundPlane = SCNPlane(width: 0.25, height: 0.2)
        let backgroundNode = SCNNode(geometry: backgroundPlane)
        backgroundNode.position = SCNVector3(0, 0, -0.01) // Slightly behind text
        
        // Set background material with HIGHER opacity for better contrast
        let backgroundMaterial = SCNMaterial()
        backgroundMaterial.diffuse.contents = UIColor.black
        backgroundMaterial.transparency = 0.0 // Fully opaque (was 0.1)
        backgroundMaterial.lightingModel = .constant // No lighting effects
        backgroundPlane.materials = [backgroundMaterial]
        
        // Add background to parent node
        bubbleNode.addChildNode(backgroundNode)
        
        // Create Chinese text node with LARGER text
        let chineseText = SCNText(string: chinese, extrusionDepth: 0.01)
        chineseText.font = UIFont.systemFont(ofSize: 0.6, weight: .bold) // Increased size (was 0.5)
        chineseText.firstMaterial?.diffuse.contents = UIColor.white
        
        // Add BRIGHTER emission to Chinese text for better visibility
        chineseText.firstMaterial?.emission.contents = UIColor.white
        chineseText.firstMaterial?.emission.intensity = 5.0 // Much brighter (was 2.0)
        chineseText.firstMaterial?.lightingModel = .constant // No lighting effects
        chineseText.firstMaterial?.transparency = 0.0 // Fully opaque
        
        // Calculate text size and position
        let chineseNode = SCNNode(geometry: chineseText)
        chineseNode.scale = SCNVector3(0.035, 0.035, 0.035) // Larger scale (was 0.03)
        let (chineseMin, chineseMax) = chineseText.boundingBox
        let chineseWidth = Float(chineseMax.x - chineseMin.x)
        chineseNode.position = SCNVector3(-Float(chineseWidth) * 0.035 / 2, 0.04, 0.01) // Slightly in front
        chineseNode.renderingOrder = 3000 // Very high rendering priority (was 2000)
        chineseNode.opacity = 1.0 // Ensure full opacity
        
        // Create Pinyin text node
        let pinyinText = SCNText(string: pinyin, extrusionDepth: 0.01)
        pinyinText.font = UIFont.systemFont(ofSize: 0.5) // Larger (was 0.4)
        pinyinText.firstMaterial?.diffuse.contents = UIColor.yellow
        
        // Add BRIGHTER emission to Pinyin text for better visibility
        pinyinText.firstMaterial?.emission.contents = UIColor.yellow
        pinyinText.firstMaterial?.emission.intensity = 5.0 // Much brighter (was 2.0)
        pinyinText.firstMaterial?.lightingModel = .constant // No lighting effects
        pinyinText.firstMaterial?.transparency = 0.0 // Fully opaque
        
        // Calculate text size and position
        let pinyinNode = SCNNode(geometry: pinyinText)
        pinyinNode.scale = SCNVector3(0.03, 0.03, 0.03) // Larger scale (was 0.025)
        let (pinyinMin, pinyinMax) = pinyinText.boundingBox
        let pinyinWidth = Float(pinyinMax.x - pinyinMin.x)
        pinyinNode.position = SCNVector3(-Float(pinyinWidth) * 0.03 / 2, 0.0, 0.01) // Slightly in front
        pinyinNode.renderingOrder = 3000 // Higher rendering priority (was 2000)
        pinyinNode.opacity = 1.0 // Ensure full opacity
        
        // Create English text node
        let englishText = SCNText(string: english, extrusionDepth: 0.01)
        englishText.font = UIFont.systemFont(ofSize: 0.5) // Larger (was 0.4)
        englishText.firstMaterial?.diffuse.contents = UIColor.cyan
        
        // Add BRIGHTER emission to English text for better visibility
        englishText.firstMaterial?.emission.contents = UIColor.cyan
        englishText.firstMaterial?.emission.intensity = 5.0 // Much brighter (was 2.0)
        englishText.firstMaterial?.lightingModel = .constant // No lighting effects
        englishText.firstMaterial?.transparency = 0.0 // Fully opaque
        
        // Calculate text size and position
        let englishNode = SCNNode(geometry: englishText)
        englishNode.scale = SCNVector3(0.025, 0.025, 0.025) // Larger scale (was 0.02)
        let (englishMin, englishMax) = englishText.boundingBox
        let englishWidth = Float(englishMax.x - englishMin.x)
        englishNode.position = SCNVector3(-Float(englishWidth) * 0.025 / 2, -0.04, 0.01) // Slightly in front
        englishNode.renderingOrder = 3000 // Higher rendering priority (was 2000)
        englishNode.opacity = 1.0 // Ensure full opacity
        
        // Add all text nodes to parent
        bubbleNode.addChildNode(chineseNode)
        bubbleNode.addChildNode(pinyinNode)
        bubbleNode.addChildNode(englishNode)
        
        // Add a billboard constraint to make the text always face the camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .all
        bubbleNode.constraints = [billboardConstraint]
        
        // Set HIGHEST rendering priority for the entire node
        bubbleNode.renderingOrder = 3000 // Higher (was 2000)
        bubbleNode.opacity = 1.0
        
        // Skip animation and just set the final scale immediately
        bubbleNode.scale = SCNVector3(1.5, 1.5, 1.5) // Larger scale (was 1.0)
        bubbleNode.opacity = 1.0
        
        // Add a continuous animation to make it more noticeable
        let pulseAction = SCNAction.sequence([
            SCNAction.scale(to: 1.7, duration: 0.5),
            SCNAction.scale(to: 1.5, duration: 0.5)
        ])
        let repeatPulse = SCNAction.repeatForever(pulseAction)
        bubbleNode.runAction(repeatPulse)
        
        print("✅ AR text node created successfully")
        
        return bubbleNode
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
    
    // Add a test label that's always visible in the AR view
    func addTestLabel() {
        print("Adding test label to AR view")
        
        // Create a test label that will always be visible
        let testNode = createNewBubbleParentNode(
            english: "TEST LABEL",
            chinese: "测试标签",
            pinyin: "cèshì biāoqiān"
        )
        
        // Position the test label in front of the camera
        guard let frame = sceneView.session.currentFrame else {
            print("No current frame available, positioning test label at origin")
            testNode.position = SCNVector3(0, 0, -0.5)
            sceneView.scene.rootNode.addChildNode(testNode)
            placedNodes.append(testNode)
            return
        }
        
        // Get the camera position and orientation
        let cameraTransform = frame.camera.transform
        let positionColumn = cameraTransform.columns.3
        let cameraPosition = SCNVector3(positionColumn.x, positionColumn.y, positionColumn.z)
        let cameraDirection = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
        
        // Position the test label 0.5 meters in front of the camera
        let position = SCNVector3(
            cameraPosition.x + cameraDirection.x * 0.5,
            cameraPosition.y + cameraDirection.y * 0.5,
            cameraPosition.z + cameraDirection.z * 0.5
        )
        
        testNode.position = position
        
        // Make sure the test node is fully opaque and has high rendering priority
        testNode.opacity = 1.0
        testNode.renderingOrder = 2000 // Even higher than regular labels
        
        // Add a special name to identify this as a test label
        testNode.name = "TEST_LABEL|测试标签|cèshì biāoqiān"
        
        // Add the test node to the scene
        sceneView.scene.rootNode.addChildNode(testNode)
        placedNodes.append(testNode)
        
        // Log that we've added the test label
        print("Test label added at position: \(position)")
        
        // Add a continuous animation to make it more noticeable
        let pulseAction = SCNAction.sequence([
            SCNAction.scale(to: 1.2, duration: 0.5),
            SCNAction.scale(to: 1.0, duration: 0.5)
        ])
        let repeatPulse = SCNAction.repeatForever(pulseAction)
        testNode.runAction(repeatPulse)
        
        // Also add a test label to the resumeARSession method
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Play pronunciation to confirm audio is working
            self.playPronunciation(for: "测试标签", pinyin: "cèshì biāoqiān")
        }
    }
    
    // Add a fixed 3D text node that doesn't rely on AR features
    func addFixedTextNode() {
        print("Adding fixed 3D text node to scene")
        
        // Create a new node with test text
        let testNode = createNewBubbleParentNode(
            english: "FIXED 3D TEXT",
            chinese: "固定3D文本",
            pinyin: "gùdìng 3D wénběn"
        )
        
        // Position the node at a fixed position in front of the camera
        // This doesn't rely on AR hit testing or feature points
        testNode.position = SCNVector3(0, 0, -0.5)
        
        // Make sure the node is fully opaque and has high rendering priority
        testNode.opacity = 1.0
        testNode.renderingOrder = 3000 // Very high rendering priority
        
        // Add a special name to identify this as a fixed test node
        testNode.name = "FIXED_TEST_NODE|固定3D文本|gùdìng 3D wénběn"
        
        // Add the node directly to the root node of the scene
        sceneView.scene.rootNode.addChildNode(testNode)
        placedNodes.append(testNode)
        
        // Log that we've added the fixed test node
        print("Fixed 3D text node added at position: \(testNode.position)")
        
        // Add a continuous animation to make it more noticeable
        let pulseAction = SCNAction.sequence([
            SCNAction.scale(to: 1.2, duration: 0.5),
            SCNAction.scale(to: 1.0, duration: 0.5)
        ])
        let repeatPulse = SCNAction.repeatForever(pulseAction)
        testNode.runAction(repeatPulse)
        
        // Play pronunciation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.playPronunciation(for: "固定3D文本", pinyin: "gùdìng 3D wénběn")
        }
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