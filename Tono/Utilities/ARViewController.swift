// ARViewController.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import UIKit
import SceneKit
import ARKit
import AVFoundation
import Speech
import Vision
import CoreData

class ARViewController: UIViewController, ARSCNViewDelegate {
    
    // SCENE
    var sceneView: ARSCNView!
    let bubbleDepth: Float = 0.01 // the 'depth' of 3D text
    var latestPrediction: String = "…" // a variable containing the latest CoreML prediction
    var latestChineseTranslation: String = "..." // Chinese translation of the latest prediction
    var latestPinyin: String = "..." // Pinyin for the latest Chinese translation
    
    // Store placed nodes to prevent duplicates
    var placedNodes: [SCNNode] = []
    
    // Feature points visualization
    var featurePointsNode: SCNNode?
    var isShowingFeaturePoints = false
    var currentDetectionConfidence: Float = 0.0
    var lastFeaturePointsUpdateTime: TimeInterval = 0
    var featurePointsFadingStarted = false
    
    // Text-to-speech synthesizer
    let speechSynthesizer = AVSpeechSynthesizer()
    
    // Model manager for object detection
    let modelManager = ModelManager.shared
    
    // A Serial Queue for ML processing
    let dispatchQueueML = DispatchQueue(label: "com.tono.dispatchqueueml")
    var debugTextView: UITextView!
    
    // Flag to control ML processing
    var isMLProcessingActive = true
    
    // Translation manager for object translations
    let translationManager = TranslationManager.shared
    
    // Core Data managed object context
    var managedObjectContext: NSManagedObjectContext?
    
    // Callback for when a new object is detected
    var onObjectDetected: ((String, String, String) -> Void)?
    
    // Last captured image for object detection
    var lastCapturedImage: UIImage?
    
    // Track the last detected object to avoid duplicate logging
    private var lastDetectedObject: String = ""
    
    // Bounding boxes for detected objects
    private var boundingBoxes: [(node: SCNNode, view: UIView)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the AR SceneView
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
        // Optimize AR performance
        sceneView.antialiasingMode = .none // Disable antialiasing to improve performance
        sceneView.preferredFramesPerSecond = 30 // Limit to 30 FPS to reduce CPU usage
        
        // Create debug text view
        setupDebugTextView()
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        // Set up Vision Model
        setupVisionModel()
        
        // Set up audio session for playback
        setupAudioSession()
        
        // Register for app lifecycle notifications
        registerForAppLifecycleNotifications()
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    // MARK: - App Lifecycle
    
    func registerForAppLifecycleNotifications() {
        // Register for notifications when app enters background or foreground
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(appWillResignActive), 
                                              name: UIApplication.willResignActiveNotification, 
                                              object: nil)
        
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(appDidBecomeActive), 
                                              name: UIApplication.didBecomeActiveNotification, 
                                              object: nil)
        
        // Register for clear labels notification
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handleClearLabelsNotification),
                                              name: NSNotification.Name("ClearARLabels"),
                                              object: nil)
        
        // Register for model change notification
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handleModelChanged),
                                              name: NSNotification.Name("ModelChanged"),
                                              object: nil)
    }
    
    @objc func handleModelChanged() {
        // Update the UI to reflect the new model
        DispatchQueue.main.async {
            self.debugTextView.text = "Switching to \(self.modelManager.currentModelType.rawValue) model..."
            
            // Clear existing bounding boxes
            self.clearBoundingBoxes()
            
            // Clear existing labels
            self.clearLabels()
        }
    }
    
    @objc func appWillResignActive() {
        // Pause ML processing when app goes to background or screen turns off
        isMLProcessingActive = false
        // Pause the AR session
        sceneView.session.pause()
        // Deactivate audio session
        deactivateAudioSession()
        print("App resigned active: Paused ML processing and AR session, deactivated audio session")
    }
    
    @objc func appDidBecomeActive() {
        // Resume ML processing when app comes to foreground
        if !isMLProcessingActive {
            isMLProcessingActive = true
            
            // Resume the AR session with the current configuration
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            sceneView.session.run(configuration)
            
            // Reactivate audio session
            setupAudioSession()
            
            print("App became active: Resumed ML processing and AR session, reactivated audio session")
            // Restart the ML loop if it was paused
            loopCoreMLUpdate()
        }
    }
    
    deinit {
        // Remove observers when view controller is deallocated
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupDebugTextView() {
        debugTextView = UITextView(frame: CGRect(x: 20, y: 20, width: 200, height: 60))
        debugTextView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        debugTextView.textColor = UIColor.white
        debugTextView.font = UIFont.systemFont(ofSize: 10)
        debugTextView.isEditable = false
        debugTextView.isSelectable = false
        debugTextView.layer.cornerRadius = 8
        debugTextView.clipsToBounds = true
        view.addSubview(debugTextView)
    }
    
    func setupVisionModel() {
        // No need to set up Vision model here as we're using ModelManager
        print("Using \(modelManager.currentModelType.rawValue) model")
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Optimize AR configuration for performance
        configuration.environmentTexturing = .none // Disable environment texturing
        configuration.isLightEstimationEnabled = false // Disable light estimation
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Update feature points visualization if needed
            if self.isShowingFeaturePoints && self.currentDetectionConfidence > 0.3 {
                // Only update feature points if it's been more than 1 second since last update
                if time - self.lastFeaturePointsUpdateTime > 1.0 {
                    self.updateFeaturePoints()
                    self.lastFeaturePointsUpdateTime = time
                    self.featurePointsFadingStarted = false
                }
            } else if self.featurePointsNode != nil && !self.featurePointsFadingStarted {
                // Start fading out feature points if they exist but we're not showing new ones
                self.startFeaturePointsFade()
                self.featurePointsFadingStarted = true
            }
        }
    }
    
    // Add this method to properly manage ARFrame retention
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // This method is called after each frame is rendered
        // We can use it to ensure we're not holding onto ARFrames unnecessarily
        
        // Clear any references to the current frame after processing
        DispatchQueue.main.async {
            // Release any strong references to the current frame
            self.lastCapturedImage = nil
        }
    }
    
    // MARK: - Feature Points Visualization
    
    func updateFeaturePoints() {
        // Remove existing feature points node if it exists
        featurePointsNode?.removeFromParentNode()
        
        // Get current feature points from the AR session
        guard let pointCloud = sceneView.session.currentFrame?.rawFeaturePoints else {
            return
        }
        
        // Create a new node to hold all feature points
        featurePointsNode = SCNNode()
        
        // Create a material for the feature points
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan
        material.lightingModel = .constant
        material.transparency = 1.0  // Start fully visible
        
        // Get the points from the point cloud
        let points = pointCloud.points
        
        // Limit the number of points to display for performance
        let maxPoints = min(points.count, 50) // Reduced from 100 to 50 for better performance
        
        // Add each feature point as a small sphere
        for i in 0..<maxPoints {
            let point = points[i]
            
            // Create a small sphere for each point
            let sphere = SCNSphere(radius: 0.002) // 2mm radius
            sphere.materials = [material]
            
            // Create a node for the sphere
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(point.x, point.y, point.z)
            
            // Add the node to the feature points parent node
            featurePointsNode?.addChildNode(node)
        }
        
        // Add the feature points node to the scene
        sceneView.scene.rootNode.addChildNode(featurePointsNode!)
        
        // Reset fading state
        featurePointsFadingStarted = false
    }
    
    // Start a gradual fade-out of feature points
    func startFeaturePointsFade() {
        guard let featurePointsNode = featurePointsNode else { return }
        
        // Create a fade-out animation
        let fadeAction = SCNAction.fadeOut(duration: 3.0)
        
        // After fading out, remove the node
        let removeAction = SCNAction.removeFromParentNode()
        
        // Combine the actions
        let sequence = SCNAction.sequence([fadeAction, removeAction])
        
        // Run the animation on the feature points node
        featurePointsNode.runAction(sequence) {
            // Reset after animation completes
            self.featurePointsNode = nil
            self.isShowingFeaturePoints = false
            self.featurePointsFadingStarted = false
        }
    }
    
    // MARK: - Interaction
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Get tap location in the AR scene view
        let location = gestureRecognize.location(in: sceneView)
        
        // Perform hit test against existing nodes
        let hitTestResults = sceneView.hitTest(location, options: [:])
        
        // Check if we hit an existing node
        if let hitNode = hitTestResults.first?.node, isNodeInPlacedNodes(hitNode) {
            // We tapped on an existing node, play pronunciation
            // Extract the word data from the node name
            if let nodeName = hitNode.name, nodeName.contains("|") {
                let components = nodeName.components(separatedBy: "|")
                if components.count >= 3 {
                    let chinese = components[1]
                    let pinyin = components[2]
                    playPronunciation(for: chinese, pinyin: pinyin)
                } else {
                    playPronunciation(for: latestChineseTranslation, pinyin: latestPinyin)
                }
            } else {
                playPronunciation(for: latestChineseTranslation, pinyin: latestPinyin)
            }
            
            // Highlight the node briefly to provide visual feedback
            highlightNode(hitNode)
            
            return
        }
        
        // If we didn't hit an existing node, perform a hit test against AR features
        let arHitTestResults = sceneView.hitTest(location, types: [.featurePoint])
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform = closestResult.worldTransform
            let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Check if there's already a node close to this position
            if isPositionNearExistingNode(worldCoord) {
                // If there's a node nearby, don't create a new one
                // Find the closest node and play its pronunciation
                if let closestNode = findClosestNode(to: worldCoord) {
                    // Extract the word data from the node name
                    if let nodeName = closestNode.name, nodeName.contains("|") {
                        let components = nodeName.components(separatedBy: "|")
                        if components.count >= 3 {
                            let chinese = components[1]
                            let pinyin = components[2]
                            playPronunciation(for: chinese, pinyin: pinyin)
                        } else {
                            playPronunciation(for: latestChineseTranslation, pinyin: latestPinyin)
                        }
                    } else {
                        playPronunciation(for: latestChineseTranslation, pinyin: latestPinyin)
                    }
                    highlightNode(closestNode)
                }
                return
            }
            
            // Create 3D Text with Chinese translation and pinyin
            let node = createNewBubbleParentNode()
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
            
            // Store the node to prevent duplicates
            placedNodes.append(node)
            
            // Play pronunciation audio
            playPronunciation(for: latestChineseTranslation, pinyin: latestPinyin)
            
            // Save the tagged object to Core Data
            saveTaggedObject(at: worldCoord)
            
            // Notify about the detected object
            onObjectDetected?(latestPrediction, latestChineseTranslation, latestPinyin)
        }
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
    
    func createNewBubbleParentNode() -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // Create a parent node for all text elements
        let bubbleNodeParent = SCNNode()
        
        // CHINESE TEXT
        let chineseText = SCNText(string: latestChineseTranslation, extrusionDepth: CGFloat(bubbleDepth))
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
        
        // PINYIN TEXT
        let pinyinText = SCNText(string: latestPinyin, extrusionDepth: CGFloat(bubbleDepth))
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
        pinyinNode.position = SCNVector3(0, -0.05, 0)
        
        // ENGLISH TEXT
        let englishText = SCNText(string: latestPrediction, extrusionDepth: CGFloat(bubbleDepth))
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
        englishNode.position = SCNVector3(0, -0.1, 0)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // Add all nodes to parent
        bubbleNodeParent.addChildNode(chineseNode)
        bubbleNodeParent.addChildNode(pinyinNode)
        bubbleNodeParent.addChildNode(englishNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        // Store the current word data with the node
        bubbleNodeParent.name = "\(latestPrediction)|\(latestChineseTranslation)|\(latestPinyin)"
        
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
    
    // MARK: - CoreML Vision Handling
    
    func loopCoreMLUpdate() {
        // Only continue the loop if ML processing is active
        guard isMLProcessingActive else {
            print("ML processing is paused")
            return
        }
        
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function only if ML processing is still active
            if self.isMLProcessingActive {
                // Add a small delay to reduce CPU usage and frame retention
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    self.loopCoreMLUpdate()
                }
            }
        }
    }
    
    func updateCoreML() {
        // Skip processing if ML is not active
        guard isMLProcessingActive else { return }
        
        // Check if the current model is ready
        if !modelManager.isCurrentModelReady() {
            // Update UI to show that the model is initializing
            DispatchQueue.main.async {
                self.debugTextView.text = "Initializing \(self.modelManager.currentModelType.rawValue) model..."
            }
            return
        }
        
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        
        // Create a local copy to avoid holding reference to the ARFrame
        var localPixelBuffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(kCFAllocatorDefault,
                           CVPixelBufferGetWidth(pixbuff!),
                           CVPixelBufferGetHeight(pixbuff!),
                           CVPixelBufferGetPixelFormatType(pixbuff!),
                           nil,
                           &localPixelBuffer)
        
        if let localBuffer = localPixelBuffer {
            CVPixelBufferLockBaseAddress(pixbuff!, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferLockBaseAddress(localBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            // Copy the pixel data
            let pixelData = CVPixelBufferGetBaseAddress(pixbuff!)
            let localData = CVPixelBufferGetBaseAddress(localBuffer)
            let dataSize = CVPixelBufferGetDataSize(pixbuff!)
            memcpy(localData, pixelData, dataSize)
            
            CVPixelBufferUnlockBaseAddress(localBuffer, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(pixbuff!, CVPixelBufferLockFlags.readOnly)
            
            // Use ModelManager to detect objects
            modelManager.detectObjects(in: localBuffer) { [weak self] detections, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Detection error: \(error)")
                    
                    // Update UI to show the error
                    DispatchQueue.main.async {
                        self.debugTextView.text = "Error: \(error.localizedDescription)"
                    }
                    return
                }
                
                // Process the detections
                self.processDetections(detections)
            }
        }
    }
    
    // Process detections from the model
    func processDetections(_ detections: [DetectedObject]?) {
        guard let detections = detections, !detections.isEmpty else {
            return
        }
        
        // Get the top detection
        if let topDetection = detections.first {
            // Update the latest prediction
            let objectName = topDetection.label
            
            // Only update if this is a new detection or confidence is higher
            if objectName != lastDetectedObject || topDetection.confidence > currentDetectionConfidence {
                lastDetectedObject = objectName
                currentDetectionConfidence = topDetection.confidence
                
                // Get translation for the detected object
                if let translation = translationManager.getTranslation(for: objectName) {
                    // Update the latest prediction and translation
                    latestPrediction = objectName
                    latestChineseTranslation = translation.chinese
                    latestPinyin = translation.pinyin
                    
                    // Update debug text view
                    DispatchQueue.main.async {
                        self.debugTextView.text = "\(objectName): \(Int(topDetection.confidence * 100))%\n\(translation.chinese) (\(translation.pinyin))"
                    }
                    
                    // Show feature points if confidence is high enough
                    isShowingFeaturePoints = topDetection.confidence > 0.5
                    
                    // Update bounding boxes if using YOLO
                    if modelManager.currentModelType == .yolo {
                        updateBoundingBoxes(for: detections)
                    } else {
                        // Clear bounding boxes if not using YOLO
                        clearBoundingBoxes()
                    }
                }
            }
        }
    }
    
    // Update bounding boxes for detected objects (only for YOLO)
    func updateBoundingBoxes(for detections: [DetectedObject]?) {
        DispatchQueue.main.async {
            // Clear existing bounding boxes
            self.clearBoundingBoxes()
            
            // Only show bounding boxes for YOLO model
            guard self.modelManager.currentModelType == .yolo, let detections = detections else {
                return
            }
            
            // Create new bounding boxes
            for detection in detections {
                // Only show boxes for objects with confidence above threshold
                guard detection.confidence > 0.3 else { continue }
                
                // Create a bounding box in the AR scene
                self.addBoundingBox(for: detection)
            }
        }
    }
    
    // Clear all bounding boxes
    func clearBoundingBoxes() {
        for (node, view) in boundingBoxes {
            node.removeFromParentNode()
            view.removeFromSuperview()
        }
        boundingBoxes.removeAll()
    }
    
    // Clear all labels
    func clearLabels() {
        // Remove all placed nodes
        for node in placedNodes {
            node.removeFromParentNode()
        }
        placedNodes.removeAll()
        
        // Reset latest prediction
        latestPrediction = "…"
        latestChineseTranslation = "..."
        latestPinyin = "..."
        
        // Reset last detected object
        lastDetectedObject = ""
        
        // Update debug text view
        DispatchQueue.main.async {
            self.debugTextView.text = "Labels cleared"
        }
    }
    
    @objc func handleClearLabelsNotification() {
        clearLabels()
        clearBoundingBoxes()
    }
    
    // Translate English word to Chinese
    func translateToChinese(_ englishWord: String) {
        // First try the full phrase
        let fullPhrase = englishWord.lowercased()
        
        // Then try just the first word as fallback
        let firstWord = englishWord.components(separatedBy: " ")[0].lowercased()
        
        // Look up in dictionary - try full phrase first, then fall back to first word
        if let translation = translationManager.getTranslation(for: fullPhrase) {
            latestChineseTranslation = translation.chinese
            latestPinyin = translation.pinyin
            print("Translation: '\(fullPhrase)' → '\(translation.chinese)' (\(translation.pinyin))")
        } else if let translation = translationManager.getTranslation(for: firstWord) {
            latestChineseTranslation = translation.chinese
            latestPinyin = translation.pinyin
            print("Translation (first word): '\(firstWord)' → '\(translation.chinese)' (\(translation.pinyin))")
        } else {
            // If not found, use a default message
            latestChineseTranslation = "未知"
            latestPinyin = "wèizhī"
            print("No translation found for: '\(englishWord)'")
        }
        
        // Update debug text with a more concise format
        DispatchQueue.main.async {
            self.debugTextView.text = "\(self.latestPrediction)\n\(self.latestChineseTranslation) (\(self.latestPinyin))"
        }
    }
    
    // Check if an object is already tagged in the scene
    func isObjectAlreadyTagged(_ objectName: String) -> Bool {
        // Check if any of the placed nodes contain this object name
        for node in placedNodes {
            if let nodeName = node.name, nodeName.contains(objectName) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Object Capture and Storage
    
    // Save the tagged object to Core Data
    func saveTaggedObject(at position: SCNVector3) {
        guard let managedObjectContext = managedObjectContext else {
            print("Error: Managed object context not available")
            return
        }
        
        // Use a background thread for Core Data operations
        let backgroundContext = managedObjectContext.perform {
            // Capture the current frame as an image
            self.captureCurrentFrame { [weak self] image in
                guard let self = self, let image = image else { return }
                
                // Get the object's image by cropping around the detected object
                if let objectImage = self.cropObjectImage(from: image) {
                    // Save to Core Data on a background thread
                    DispatchQueue.global(qos: .userInitiated).async {
                        PersistenceController.shared.saveTaggedObject(
                            english: self.latestPrediction,
                            chinese: self.latestChineseTranslation,
                            pinyin: self.latestPinyin,
                            image: objectImage,
                            position: position,
                            context: managedObjectContext
                        )
                        
                        // Show a success message on the main thread
                        DispatchQueue.main.async {
                            self.showSavedConfirmation()
                        }
                    }
                }
            }
        }
    }
    
    // Capture the current AR frame as a UIImage
    func captureCurrentFrame(completion: @escaping (UIImage?) -> Void) {
        // Make sure we're on the main thread when accessing the AR session
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let pixelBuffer = self.sceneView.session.currentFrame?.capturedImage else {
                completion(nil)
                return
            }
            
            // Process the image on a background thread to avoid blocking the main thread
            DispatchQueue.global(qos: .userInitiated).async {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                
                // Convert CIImage to CGImage
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    // Create UIImage from CGImage
                    let uiImage = UIImage(cgImage: cgImage)
                    
                    // Store the image for later use
                    DispatchQueue.main.async {
                        self.lastCapturedImage = uiImage
                        completion(uiImage)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // Crop the image to focus on the detected object
    func cropObjectImage(from image: UIImage) -> UIImage? {
        // For now, we'll just use a simple center crop as a placeholder
        // In a real implementation, you would use object detection bounding boxes
        
        let size = image.size
        let cropSize = min(size.width, size.height) * 0.5 // 50% of the smaller dimension
        
        let originX = (size.width - cropSize) / 2
        let originY = (size.height - cropSize) / 2
        
        let cropRect = CGRect(x: originX, y: originY, width: cropSize, height: cropSize)
        
        // Crop the image
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage)
            
            // Rotate the image 90 degrees clockwise to fix the orientation
            return croppedImage.rotate90DegreesClockwise()
        }
        
        return nil
    }
    
    // Show a confirmation that the object was saved
    func showSavedConfirmation() {
        // Make sure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let confirmationView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
            confirmationView.backgroundColor = UIColor.green.withAlphaComponent(0.7)
            confirmationView.layer.cornerRadius = 10
            confirmationView.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.height - 100)
            
            let label = UILabel(frame: confirmationView.bounds)
            label.text = "Object Saved!"
            label.textColor = .white
            label.textAlignment = .center
            label.font = UIFont.boldSystemFont(ofSize: 16)
            
            confirmationView.addSubview(label)
            self.view.addSubview(confirmationView)
            
            // Animate the confirmation
            confirmationView.alpha = 0
            UIView.animate(withDuration: 0.3, animations: {
                confirmationView.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: {
                    confirmationView.alpha = 0
                }) { _ in
                    confirmationView.removeFromSuperview()
                }
            }
        }
    }
    
    // MARK: - AR Session Management
    
    // Pause the AR session and ML processing
    func pauseARSession() {
        if isMLProcessingActive {
            isMLProcessingActive = false
            sceneView.session.pause()
            print("AR session paused")
        }
    }
    
    // Resume the AR session and ML processing
    func resumeARSession() {
        if !isMLProcessingActive {
            isMLProcessingActive = true
            
            // Resume the AR session with the current configuration
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            sceneView.session.run(configuration)
            
            // Restart the ML loop
            loopCoreMLUpdate()
            
            print("AR session resumed")
        }
    }
    
    // Add a bounding box for a detected object
    func addBoundingBox(for detection: DetectedObject) {
        // Convert normalized coordinates to screen coordinates
        let viewWidth = sceneView.bounds.width
        let viewHeight = sceneView.bounds.height
        
        let boxRect = CGRect(
            x: detection.boundingBox.minX * viewWidth,
            y: (1 - detection.boundingBox.maxY) * viewHeight,
            width: detection.boundingBox.width * viewWidth,
            height: detection.boundingBox.height * viewHeight
        )
        
        // Create a view for the bounding box
        let boxView = UIView(frame: boxRect)
        boxView.layer.borderColor = UIColor.red.cgColor
        boxView.layer.borderWidth = 2
        boxView.backgroundColor = UIColor.clear
        
        // Add label to the box
        let label = UILabel(frame: CGRect(x: 0, y: -25, width: boxRect.width, height: 20))
        label.text = "\(detection.label) (\(Int(detection.confidence * 100))%)"
        label.textColor = UIColor.red
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        boxView.addSubview(label)
        
        // Add the box view to the main view
        sceneView.addSubview(boxView)
        
        // Create a node in the AR scene for the bounding box
        let boxNode = SCNNode()
        
        // Store the box view and node for later removal
        boundingBoxes.append((node: boxNode, view: boxView))
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

extension UIImage {
    func rotate90DegreesClockwise() -> UIImage? {
        UIGraphicsBeginImageContext(CGSize(width: self.size.height, height: self.size.width))
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: self.size.height / 2, y: self.size.width / 2)
        context.rotate(by: .pi / 2)
        context.translateBy(x: -self.size.height / 2, y: -self.size.width / 2)
        
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
} 