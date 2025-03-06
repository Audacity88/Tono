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

class ARViewController: UIViewController, ARSCNViewDelegate {
    
    // SCENE
    var sceneView: ARSCNView!
    let bubbleDepth: Float = 0.01 // the 'depth' of 3D text
    var latestPrediction: String = "…" // a variable containing the latest CoreML prediction
    var latestChineseTranslation: String = "..." // Chinese translation of the latest prediction
    var latestPinyin: String = "..." // Pinyin for the latest Chinese translation
    
    // Store placed nodes to prevent duplicates
    var placedNodes: [SCNNode] = []
    
    // Text-to-speech synthesizer
    let speechSynthesizer = AVSpeechSynthesizer()
    
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.tono.dispatchqueueml") // A Serial Queue
    var debugTextView: UITextView!
    
    // Dictionary for English to Chinese translations
    let translationDictionary: [String: (chinese: String, pinyin: String)] = [
        "cup": (chinese: "杯子", pinyin: "bēizi"),
        "bottle": (chinese: "瓶子", pinyin: "píngzi"),
        "chair": (chinese: "椅子", pinyin: "yǐzi"),
        "table": (chinese: "桌子", pinyin: "zhuōzi"),
        "book": (chinese: "书", pinyin: "shū"),
        "pen": (chinese: "笔", pinyin: "bǐ"),
        "phone": (chinese: "手机", pinyin: "shǒujī"),
        "computer": (chinese: "电脑", pinyin: "diànnǎo"),
        "keyboard": (chinese: "键盘", pinyin: "jiànpán"),
        "mouse": (chinese: "鼠标", pinyin: "shǔbiāo"),
        "monitor": (chinese: "显示器", pinyin: "xiǎnshìqì"),
        "desk": (chinese: "桌子", pinyin: "zhuōzi"),
        "lamp": (chinese: "灯", pinyin: "dēng"),
        "window": (chinese: "窗户", pinyin: "chuānghu"),
        "door": (chinese: "门", pinyin: "mén"),
        "wall": (chinese: "墙", pinyin: "qiáng"),
        "floor": (chinese: "地板", pinyin: "dìbǎn"),
        "ceiling": (chinese: "天花板", pinyin: "tiānhuābǎn"),
        "sofa": (chinese: "沙发", pinyin: "shāfā"),
        "television": (chinese: "电视", pinyin: "diànshì"),
        "remote": (chinese: "遥控器", pinyin: "yáokòngqì"),
        "clock": (chinese: "钟", pinyin: "zhōng"),
        "watch": (chinese: "手表", pinyin: "shǒubiǎo"),
        "glasses": (chinese: "眼镜", pinyin: "yǎnjìng"),
        "shoe": (chinese: "鞋", pinyin: "xié"),
        "hat": (chinese: "帽子", pinyin: "màozi"),
        "shirt": (chinese: "衬衫", pinyin: "chènshān"),
        "pants": (chinese: "裤子", pinyin: "kùzi"),
        "jacket": (chinese: "夹克", pinyin: "jiákè"),
        "coat": (chinese: "外套", pinyin: "wàitào"),
        "train": (chinese: "火车", pinyin: "huǒchē"),
        "person": (chinese: "人", pinyin: "rén"),
        "dog": (chinese: "狗", pinyin: "gǒu"),
        "cat": (chinese: "猫", pinyin: "māo"),
        "car": (chinese: "汽车", pinyin: "qìchē"),
        "bicycle": (chinese: "自行车", pinyin: "zìxíngchē"),
        "cell phone": (chinese: "手机", pinyin: "shǒujī"),
        "tv": (chinese: "电视", pinyin: "diànshì"),
        "couch": (chinese: "沙发", pinyin: "shāfā"),
        "potted plant": (chinese: "盆栽", pinyin: "pénzāi"),
        "dining table": (chinese: "餐桌", pinyin: "cānzhuō"),
        "toilet": (chinese: "厕所", pinyin: "cèsuǒ"),
        "bed": (chinese: "床", pinyin: "chuáng"),
        "refrigerator": (chinese: "冰箱", pinyin: "bīngxiāng"),
        "oven": (chinese: "烤箱", pinyin: "kǎoxiāng"),
        "microwave": (chinese: "微波炉", pinyin: "wēibōlú"),
        "toaster": (chinese: "烤面包机", pinyin: "kǎomiànbāojī"),
        "sink": (chinese: "水槽", pinyin: "shuǐcáo"),
        "vase": (chinese: "花瓶", pinyin: "huāpíng"),
        "scissors": (chinese: "剪刀", pinyin: "jiǎndāo"),
        "teddy bear": (chinese: "泰迪熊", pinyin: "tàidíxióng"),
        "hair drier": (chinese: "吹风机", pinyin: "chuīfēngjī"),
        "toothbrush": (chinese: "牙刷", pinyin: "yáshuā"),
        "bus": (chinese: "公共汽车", pinyin: "gōnggòngqìchē"),
        "airplane": (chinese: "飞机", pinyin: "fēijī"),
        "boat": (chinese: "船", pinyin: "chuán"),
        "fork": (chinese: "叉子", pinyin: "chāzi"),
        "knife": (chinese: "刀", pinyin: "dāo"),
        "spoon": (chinese: "勺子", pinyin: "sháozi"),
        "bowl": (chinese: "碗", pinyin: "wǎn"),
        "banana": (chinese: "香蕉", pinyin: "xiāngjiāo"),
        "sandwich": (chinese: "三明治", pinyin: "sānmíngzhì"),
        "orange": (chinese: "橙子", pinyin: "chéngzi"),
        "broccoli": (chinese: "西兰花", pinyin: "xīlánhuā"),
        "carrot": (chinese: "胡萝卜", pinyin: "húluóbo"),
        "hot dog": (chinese: "热狗", pinyin: "règǒu"),
        "pizza": (chinese: "披萨", pinyin: "pīsà"),
        "donut": (chinese: "甜甜圈", pinyin: "tiántiánquān"),
        "cake": (chinese: "蛋糕", pinyin: "dàngāo")
    ]
    
    // Callback for when a new object is detected
    var onObjectDetected: ((String, String, String) -> Void)?
    
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
        
        // Create debug text view
        setupDebugTextView()
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        // Set up Vision Model
        setupVisionModel()
        
        // Set up audio session for playback
        setupAudioSession()
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    func setupDebugTextView() {
        debugTextView = UITextView(frame: CGRect(x: 20, y: 20, width: 250, height: 100))
        debugTextView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        debugTextView.textColor = UIColor.white
        debugTextView.font = UIFont.systemFont(ofSize: 12)
        debugTextView.isEditable = false
        debugTextView.isSelectable = false
        debugTextView.layer.cornerRadius = 8
        debugTextView.clipsToBounds = true
        view.addSubview(debugTextView)
    }
    
    func setupVisionModel() {
        do {
            // Try to load Inceptionv3 model
            if let model = try? VNCoreMLModel(for: Inceptionv3().model) {
                // Set up Vision-CoreML Request
                let classificationRequest = VNCoreMLRequest(model: model, completionHandler: classificationCompleteHandler)
                classificationRequest.imageCropAndScaleOption = .centerCrop
                visionRequests = [classificationRequest]
                print("Loaded Inceptionv3 model")
            } else if let model = try? VNCoreMLModel(for: MobileNet().model) {
                // Fallback to MobileNet if Inceptionv3 is not available
                let classificationRequest = VNCoreMLRequest(model: model, completionHandler: classificationCompleteHandler)
                classificationRequest.imageCropAndScaleOption = .centerCrop
                visionRequests = [classificationRequest]
                print("Loaded MobileNet model")
            } else {
                print("Failed to load any CoreML model")
            }
        } catch {
            print("Error setting up Vision model: \(error)")
        }
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection
        configuration.planeDetection = [.horizontal, .vertical]
        
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
            // Do any desired updates to SceneKit here.
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
        utterance.rate = 0.0
        
        // Adjust pitch (0.5 to 2.0, default is 1.0)
        utterance.pitchMultiplier = 1.0
        
        // Adjust volume (0.0 to 1.0, default is 1.0)
        utterance.volume = 1.0
        
        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Speak the utterance
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - CoreML Vision Handling
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...1] // top 2 results
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        
        DispatchQueue.main.async {
            // Print Classifications
            print(classifications)
            print("--")
            
            // Display Debug Text on screen
            var debugText:String = ""
            debugText += classifications
            self.debugTextView.text = debugText
            
            // Store the latest prediction
            var objectName:String = "…"
            objectName = classifications.components(separatedBy: "-")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            self.latestPrediction = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look up Chinese translation and pinyin
            self.translateToChinese(self.latestPrediction)
        }
    }
    
    func translateToChinese(_ englishWord: String) {
        // Extract the main word (remove any descriptors)
        let mainWord = englishWord.components(separatedBy: " ")[0].lowercased()
        
        // Look up in dictionary
        if let translation = translationDictionary[mainWord] {
            latestChineseTranslation = translation.chinese
            latestPinyin = translation.pinyin
        } else {
            // If not found, use a default message
            latestChineseTranslation = "未知"
            latestPinyin = "wèizhī"
        }
        
        // Update debug text
        DispatchQueue.main.async {
            self.debugTextView.text += "\n\nChinese: \(self.latestChineseTranslation)\nPinyin: \(self.latestPinyin)"
        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        ///////////////////////////
        // Run Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0)
    }
} 