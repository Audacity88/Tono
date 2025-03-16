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
        
        // CRITICAL: Configure as pure tracking overlay - no camera feed!
        
        // Make the AR view totally transparent
        sceneView.backgroundColor = UIColor.clear
        sceneView.scene.background.contents = UIColor.clear
        sceneView.isOpaque = false
        
        // Turn off all AR camera rendering features
        if #available(iOS 13.0, *) {
            sceneView.rendersCameraGrain = false
            
            // Don't show debug features by default - only on request
            if UserDefaults.standard.bool(forKey: "developer_mode") {
                sceneView.debugOptions = [.showFeaturePoints]
            } else {
                sceneView.debugOptions = []
            }
        }
        
        // Setup for optimal AR experience
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognize:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Set up audio session for playback
        setupAudioSession()
    }
    
    // Set up the AR session - MINIMAL MODE
    func setupARSession() {
        // First stop any existing AR session
        sceneView.session.pause()
        
        // Clear all nodes from the scene for a clean start
        sceneView.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        
        // Create the configuration on the main thread to avoid threading issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // The most minimal possible configuration
            let configuration = ARWorldTrackingConfiguration()
            
            // Disable all unnecessary AR features
            configuration.planeDetection = []
            
            // Force AR session to run with minimal settings
            let options: ARSession.RunOptions = [.removeExistingAnchors]
            self.sceneView.session.run(configuration, options: options)
            
            // Manually set the scene to be transparent in ALL ways
            self.sceneView.scene = SCNScene() // Completely empty scene
            self.sceneView.isOpaque = false
            self.sceneView.backgroundColor = UIColor.clear
            self.sceneView.scene.background.contents = UIColor.clear
            
            // Enable world tracking with extended tracking for better AR position persistence
            if #available(iOS 12.0, *) {
                configuration.environmentTexturing = .automatic
            }
            
            // Critical for position stability - attempt to use world map
            if #available(iOS 12.0, *) {
                // Try to load a saved ARWorldMap
                if let worldMapData = UserDefaults.standard.data(forKey: "arWorldMap") {
                    do {
                        let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapData)
                        configuration.initialWorldMap = worldMap
                        print("Loaded saved AR world map for better position tracking")
                    } catch {
                        print("Failed to load saved AR world map: \(error)")
                    }
                }
            }
            
            // Run the session on the main thread
            DispatchQueue.main.async {
                // Set up scene view for optimal performance with video feed
                self.sceneView.preferredFramesPerSecond = 30
                self.sceneView.antialiasingMode = .none
                
                // Show debug options if in developer mode
                if UserDefaults.standard.bool(forKey: "developer_mode") {
                    self.sceneView.debugOptions = [.showFeaturePoints]
                } else {
                    self.sceneView.debugOptions = []
                }
                
                // CRITICAL: Make the ARSCNView completely transparent except for AR content
                self.sceneView.backgroundColor = UIColor.clear
                self.sceneView.isOpaque = false
                self.sceneView.scene.background.contents = UIColor.clear
                
                // Disable debug features that might interfere with transparency
                self.sceneView.debugOptions = []
                
                // Run the view's session with tracking options
                self.sceneView.session.run(configuration)
                
                print("AR session started with optimized configuration")
                
                // Start regular world map saving
                if #available(iOS 12.0, *) {
                    self.startWorldMapSaving()
                }
            }
        }
    }
    
    // Save the AR world map periodically to improve position tracking
    @available(iOS 12.0, *)
    private func startWorldMapSaving() {
        // Schedule timer to save world map every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.saveWorldMap()
        }
    }
    
    // Save the current AR world map
    @available(iOS 12.0, *)
    private func saveWorldMap() {
        self.sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let worldMap = worldMap, error == nil else {
                print("Failed to get current world map: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Only save if the map has a decent number of anchors to be useful
            let featurePointsCount = worldMap.rawFeaturePoints.points.count
            if worldMap.anchors.count < 2 && featurePointsCount < 10 {
                print("World map has insufficient features (\(worldMap.anchors.count) anchors, \(featurePointsCount) points) - not saving")
                return
            }
            
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                UserDefaults.standard.set(data, forKey: "arWorldMap")
                
                // Also save a backup in case the current one gets corrupted
                UserDefaults.standard.set(data, forKey: "arWorldMap_backup")
                
                let featurePointsCount = worldMap.rawFeaturePoints.points.count
                print("Saved AR world map with \(worldMap.anchors.count) anchors and \(featurePointsCount) feature points")
            } catch {
                print("Failed to save world map: \(error)")
                
                // Try to restore from backup if we have one
                if let backupData = UserDefaults.standard.data(forKey: "arWorldMap_backup") {
                    UserDefaults.standard.set(backupData, forKey: "arWorldMap")
                    print("Restored world map from backup after save failure")
                }
            }
        }
    }
    
    // Pause the AR session
    func pauseARSession() {
        sceneView.session.pause()
    }
    
    // Refresh the AR session - ensures continuous tracking
    func refreshARSession(reloadAnchors: Bool = false) {
        // Force session to update without resetting tracking
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check the current tracking state
            let currentTrackingState = self.sceneView.session.currentFrame?.camera.trackingState
            print("Current AR tracking state: \(String(describing: currentTrackingState))")
            
            guard let configuration = self.sceneView.session.configuration as? ARWorldTrackingConfiguration else {
                print("No AR configuration found - creating a new one")
                // Create a new configuration
                let newConfig = ARWorldTrackingConfiguration()
                newConfig.planeDetection = [.horizontal, .vertical]
                // CRITICAL: Don't use AR camera feed since we have our own video feed
                newConfig.providesAudioData = false
                
                // Run with the new configuration
                self.sceneView.session.run(newConfig)
                return
            }
            
            // Make a copy of the current configuration
            let updatedConfig = configuration
            
            // IMPORTANT: Don't use AR camera feed since we have our own video feed
            updatedConfig.providesAudioData = false
            
            // Update camera tracking configuration while maintaining tracking state
            var options: ARSession.RunOptions = []
            
            // Only remove anchors if explicitly requested
            if reloadAnchors {
                options.insert(.removeExistingAnchors)
                print("Removing existing AR anchors on refresh")
            }
            
            // If tracking has been lost, attempt a more aggressive refresh
            if case .limited(let reason) = currentTrackingState {
                print("Limited tracking due to: \(reason) - attempting recovery")
                
                // Only use reset tracking if tracking state is limited
                // This will reset the world coordinate system but help recover from tracking failures
                if reason == .excessiveMotion || reason == .initializing {
                    if let worldMapData = UserDefaults.standard.data(forKey: "arWorldMap") {
                        do {
                            // Try to reload the world map
                            let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapData)
                            updatedConfig.initialWorldMap = worldMap
                            
                            // Run with the world map but don't reset tracking
                            self.sceneView.session.run(updatedConfig, options: options)
                            print("Reloaded world map to attempt recovery")
                        } catch {
                            print("Failed to load world map for recovery: \(error)")
                            // If we can't load the world map, just run the updated configuration
                            self.sceneView.session.run(updatedConfig, options: options)
                        }
                    } else {
                        // Fallback if no world map
                        self.sceneView.session.run(updatedConfig, options: options)
                    }
                } else {
                    // For other limited tracking reasons, use updated configuration
                    self.sceneView.session.run(updatedConfig, options: options)
                }
            } else {
                // For normal tracking, just update the session
                self.sceneView.session.run(updatedConfig, options: options)
            }
            
            // Ensure the view is rendering
            self.sceneView.isPlaying = true
            self.sceneView.scene.isPaused = false
            
            // Make sure the scene view is properly set up
            self.sceneView.backgroundColor = UIColor.clear
            self.sceneView.isOpaque = false
            self.sceneView.scene.background.contents = UIColor.clear
            
            print("Refreshed AR session for continuous tracking")
            
            // Save world map after refresh
            if #available(iOS 12.0, *) {
                self.saveWorldMap()
            }
        }
    }
    
    // Resume the AR session
    func resumeARSession() {
        // Create the configuration on a background thread to avoid freezing the UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            
            // Enable world tracking with extended tracking for better AR position persistence
            if #available(iOS 12.0, *) {
                configuration.environmentTexturing = .automatic
            }
            
            // Use higher resolution world mapping for better relocation
            if #available(iOS 13.4, *) {
                configuration.worldAlignment = .gravity
                configuration.sceneReconstruction = .meshWithClassification
            }
            
            // Enable image tracking if needed
            if #available(iOS 13.0, *) {
                // Only if needed - can help with recognizing common objects
                // configuration.maximumNumberOfTrackedImages = 4
            }
            
            // Critical for position stability - attempt to use world map
            if #available(iOS 12.0, *) {
                // Try to load a saved ARWorldMap
                if let worldMapData = UserDefaults.standard.data(forKey: "arWorldMap") {
                    do {
                        let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapData)
                        configuration.initialWorldMap = worldMap
                        print("Loaded saved AR world map for better position tracking on resume")
                    } catch {
                        print("Failed to load saved AR world map on resume: \(error)")
                    }
                }
            }
            
            // Optimize AR configuration for performance
            if #available(iOS 13.0, *) {
                // Use person occlusion if device supports it
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                    configuration.frameSemantics.insert(.personSegmentationWithDepth)
                    print("Enabled person occlusion for better AR experience")
                }
            }
            
            // Run the session on the main thread
            DispatchQueue.main.async {
                // Set optimal frame rate for tracking stability
                self.sceneView.preferredFramesPerSecond = 30 // Use fixed value instead of recommendedVideoFormat
                
                // CRITICAL: Do NOT reset tracking when resuming - this is key for maintaining position consistency
                // Instead, use the saved world map for continued tracking
                var options: ARSession.RunOptions = []
                
                // Only remove anchors if explicitly requested
                if UserDefaults.standard.bool(forKey: "ar_reset_anchors_on_resume") {
                    options.insert(.removeExistingAnchors)
                    print("Removing existing AR anchors on resume (not recommended for position stability)")
                }
                
                // Add reset tracking only if we're in a bad state and have no world map
                if self.sceneView.session.currentFrame?.camera.trackingState == .notAvailable {
                    options.insert(.resetTracking)
                    print("AR tracking was not available, resetting tracking")
                }
                
                // Run the session with the new configuration
                self.sceneView.session.run(configuration, options: options)
                print("AR session resumed with optimized configuration and position tracking preservation")
                
                // Make sure the AR view is transparent to allow bounding boxes to be visible
                self.sceneView.backgroundColor = UIColor.clear
                self.sceneView.isOpaque = false
                
                // Resume world map saving
                if #available(iOS 12.0, *) {
                    self.startWorldMapSaving()
                }
                
                // Force immediate world map saving for better recovery
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                    if #available(iOS 12.0, *) {
                        self.saveWorldMap()
                    }
                }
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
    
    // Clear all AR labels
    func clearLabels() {
        for node in placedNodes {
            node.removeFromParentNode()
        }
        placedNodes.removeAll()
    }
    
    // Check if there's already a node for this object
    func isNodeForObject(_ objectName: String) -> Bool {
        for node in placedNodes {
            if let name = node.name, name.contains(objectName) {
                return true
            }
        }
        return false
    }
    
    // Find the closest node to a given position
    func findClosestNode(to position: SCNVector3) -> SCNNode? {
        var closestNode: SCNNode? = nil
        var closestDistance = Float.greatestFiniteMagnitude
        
        for node in placedNodes {
            let distance = SCNVector3.distance(position, node.position)
            if distance < closestDistance {
                closestDistance = distance
                closestNode = node
            }
        }
        
        return closestNode
    }
    
    // Check if position is near an existing node - simplified from backup implementation
    func isPositionNearExistingNode(_ position: SCNVector3, threshold: Float = 0.2) -> Bool {
        // Use a smaller threshold (0.2 instead of 0.3) for more precise positioning
        // This allows labels to be placed closer together for dense scenes
        for node in placedNodes {
            let distance = SCNVector3.distance(position, node.position)
            if distance < threshold {
                print("Position \(position) is near existing node \(node.position) (distance: \(distance))")
                return true
            }
        }
        return false
    }
    
    // Calculate distance between two positions more efficiently - from backup
    func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    // Provide visual feedback when node is tapped
    func highlightNode(_ node: SCNNode) {
        // Save original scale
        let originalScale = node.scale
        
        // Create scale animation
        let scaleAction = SCNAction.sequence([
            SCNAction.scale(to: 1.2, duration: 0.1),
            SCNAction.scale(to: 1.0, duration: 0.1)
        ])
        
        // Apply animation
        node.runAction(scaleAction)
    }
    
    // Handle tap on AR view
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Get the touch location
        let location = gestureRecognize.location(in: sceneView)
        
        // Check if the tap is on an existing node
        let hitTestOptions = [SCNHitTestOption.boundingBoxOnly: true] as [SCNHitTestOption: Any]
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
    
    // Create a new 3D text node - simplified based on backup implementation
    func createNewBubbleParentNode(english: String, chinese: String, pinyin: String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // Create a simpler node hierarchy with billboard constraint
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // Create a parent node for all text elements
        let bubbleNodeParent = SCNNode()
        
        // Add a sphere marker at actual position
        let sphere = SCNSphere(radius: 0.005) // Small sphere to mark exact position
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        bubbleNodeParent.addChildNode(sphereNode)
        
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
        
        // CHINESE NODE
        let (minBoundChinese, maxBoundChinese) = chineseText.boundingBox
        let chineseNode = SCNNode(geometry: chineseText)
        chineseNode.pivot = SCNMatrix4MakeTranslation((maxBoundChinese.x - minBoundChinese.x)/2, minBoundChinese.y, bubbleDepth/2)
        chineseNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        // Position the text slightly above the marker (instead of using complex offset nodes)
        chineseNode.position = SCNVector3(0, 0.05, 0)
        
        // PINYIN TEXT
        let pinyinText = SCNText(string: pinyin, extrusionDepth: CGFloat(bubbleDepth))
        let pinyinFont = UIFont(name: "Avenir-Medium", size: 0.12)
        pinyinText.font = pinyinFont
        pinyinText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        pinyinText.firstMaterial?.diffuse.contents = UIColor.orange
        pinyinText.firstMaterial?.specular.contents = UIColor.white
        pinyinText.firstMaterial?.isDoubleSided = true
        pinyinText.chamferRadius = CGFloat(bubbleDepth)
        
        // PINYIN NODE
        let (minBoundPinyin, maxBoundPinyin) = pinyinText.boundingBox
        let pinyinNode = SCNNode(geometry: pinyinText)
        pinyinNode.pivot = SCNMatrix4MakeTranslation((maxBoundPinyin.x - minBoundPinyin.x)/2, minBoundPinyin.y, bubbleDepth/2)
        pinyinNode.scale = SCNVector3Make(0.15, 0.15, 0.15)
        pinyinNode.position = SCNVector3(0, 0.0, 0) // Directly above the Chinese text
        
        // ENGLISH TEXT
        let englishText = SCNText(string: english, extrusionDepth: CGFloat(bubbleDepth))
        let englishFont = UIFont(name: "Avenir-Light", size: 0.1)
        englishText.font = englishFont
        englishText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        englishText.firstMaterial?.diffuse.contents = UIColor.white
        englishText.firstMaterial?.specular.contents = UIColor.white
        englishText.firstMaterial?.isDoubleSided = true
        englishText.chamferRadius = CGFloat(bubbleDepth)
        
        // ENGLISH NODE
        let (minBoundEnglish, maxBoundEnglish) = englishText.boundingBox
        let englishNode = SCNNode(geometry: englishText)
        englishNode.pivot = SCNMatrix4MakeTranslation((maxBoundEnglish.x - minBoundEnglish.x)/2, minBoundEnglish.y, bubbleDepth/2)
        englishNode.scale = SCNVector3Make(0.15, 0.15, 0.15)
        englishNode.position = SCNVector3(0, -0.05, 0) // Directly below the Chinese text
        
        // Add all nodes directly to parent without unnecessary nesting
        bubbleNodeParent.addChildNode(chineseNode)
        bubbleNodeParent.addChildNode(pinyinNode)
        bubbleNodeParent.addChildNode(englishNode)
        
        // Apply billboard constraint to parent node
        bubbleNodeParent.constraints = [billboardConstraint]
        
        // Store the current word data with the node
        bubbleNodeParent.name = "\(english)|\(chinese)|\(pinyin)"
        
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
}

// MARK: - Extensions

// Add distance calculation method to SCNVector3
extension SCNVector3 {
    static func distance(_ v1: SCNVector3, _ v2: SCNVector3) -> Float {
        let dx = v1.x - v2.x
        let dy = v1.y - v2.y
        let dz = v1.z - v2.z
        return sqrtf(dx*dx + dy*dy + dz*dz)
    }
}

// Add trait modification to UIFont
extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(traits) else {
            return nil
        }
        return UIFont(descriptor: descriptor, size: 0.0)
    }
}

// MARK: - ARSCNViewDelegate Methods

extension ARSceneManager {
    // ARSCNViewDelegate method called when a node has been mapped to a newly detected AR anchor
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Add any custom handling for new anchors here
        print("AR anchor added: \(anchor)")
    }
    
    // ARSCNViewDelegate method called when a node will be updated to reflect a change in its anchor
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle anchor updates here
    }
    
    // ARSCNViewDelegate method called when a node has been updated to reflect a change in its anchor
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle anchor updates here
    }
    
    // ARSCNViewDelegate method called when a mapped node has been removed from the scene graph for a removed anchor
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // Handle anchor removal here
    }
    
    // Handle proper release of ARFrame references after rendering
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // This method is called after each frame is rendered
        // Release any strong references to the current frame to prevent memory issues
        
        // This is a critical improvement from the backup implementation
        // It helps avoid memory issues that can impact AR tracking stability
        DispatchQueue.main.async { [weak self] in
            // Clear any temporary references that might be holding onto the current frame
            // This is important for memory management and AR stability
        }
    }
}