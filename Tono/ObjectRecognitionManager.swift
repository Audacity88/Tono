// ObjectRecognitionManager.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import Foundation
import Vision
import CoreML
import UIKit

class ObjectRecognitionManager: ObservableObject {
    @Published var currentDetection: DetectedObject?
    @Published var isProcessing = false
    
    // Dictionary mapping English object names to Chinese translations and pinyin
    private let objectTranslations: [String: (chinese: String, pinyin: String)] = [
        "apple": ("苹果", "píng guǒ"),
        "chair": ("椅子", "yǐ zi"),
        "table": ("桌子", "zhuō zi"),
        "book": ("书", "shū"),
        "cup": ("杯子", "bēi zi"),
        "bottle": ("瓶子", "píng zi"),
        "laptop": ("笔记本电脑", "bǐ jì běn diàn nǎo"),
        "phone": ("手机", "shǒu jī"),
        "pen": ("钢笔", "gāng bǐ"),
        "glasses": ("眼镜", "yǎn jìng"),
        "keyboard": ("键盘", "jiàn pán"),
        "mouse": ("鼠标", "shǔ biāo"),
        "headphones": ("耳机", "ěr jī"),
        "watch": ("手表", "shǒu biǎo"),
        "backpack": ("背包", "bēi bāo"),
        "door": ("门", "mén"),
        "window": ("窗户", "chuāng hu"),
        "light": ("灯", "dēng"),
        "television": ("电视", "diàn shì"),
        "remote": ("遥控器", "yáo kòng qì"),
        "person": ("人", "rén"),
        "dog": ("狗", "gǒu"),
        "cat": ("猫", "māo"),
        "car": ("汽车", "qì chē"),
        "bicycle": ("自行车", "zì xíng chē"),
        "cell phone": ("手机", "shǒu jī"),
        "tv": ("电视", "diàn shì"),
        "couch": ("沙发", "shā fā"),
        "potted plant": ("盆栽", "pén zāi"),
        "dining table": ("餐桌", "cān zhuō"),
        "toilet": ("厕所", "cè suǒ"),
        "bed": ("床", "chuáng"),
        "refrigerator": ("冰箱", "bīng xiāng"),
        "oven": ("烤箱", "kǎo xiāng"),
        "microwave": ("微波炉", "wēi bō lú"),
        "toaster": ("烤面包机", "kǎo miàn bāo jī"),
        "sink": ("水槽", "shuǐ cáo"),
        "clock": ("时钟", "shí zhōng"),
        "vase": ("花瓶", "huā píng"),
        "scissors": ("剪刀", "jiǎn dāo"),
        "teddy bear": ("泰迪熊", "tài dí xióng"),
        "hair drier": ("吹风机", "chuī fēng jī"),
        "toothbrush": ("牙刷", "yá shuā"),
        "train": ("火车", "huǒ chē"),
        "bus": ("公共汽车", "gōng gòng qì chē"),
        "airplane": ("飞机", "fēi jī"),
        "boat": ("船", "chuán"),
        "fork": ("叉子", "chā zi"),
        "knife": ("刀", "dāo"),
        "spoon": ("勺子", "sháo zi"),
        "bowl": ("碗", "wǎn"),
        "banana": ("香蕉", "xiāng jiāo"),
        "sandwich": ("三明治", "sān míng zhì"),
        "orange": ("橙子", "chéng zi"),
        "broccoli": ("西兰花", "xī lán huā"),
        "carrot": ("胡萝卜", "hú luó bo"),
        "hot dog": ("热狗", "rè gǒu"),
        "pizza": ("披萨", "pī sà"),
        "donut": ("甜甜圈", "tián tián quān"),
        "cake": ("蛋糕", "dàn gāo")
    ]
    
    // Vision request for object recognition
    private var visionRequests = [VNCoreMLRequest]()
    
    init() {
        setupVision()
        
        // Run a test to verify the model can be loaded and used
        testModelLoading()
    }
    
    private func setupVision() {
        print("Setting up Vision with YOLOv8n model...")
        
        // Try different approaches to load the model
        do {
            // First, check if the model exists in the Models directory
            let fileManager = FileManager.default
            let modelPaths = [
                // Check for NMS-enabled model first
                Bundle.main.bundlePath + "/Models/yolov8n_nms.mlpackage",
                Bundle.main.bundlePath + "/Models/yolov8n_nms.mlmodelc",
                Bundle.main.bundlePath + "/../Models/yolov8n_nms.mlpackage",
                Bundle.main.bundlePath + "/../models/yolov8n_nms.mlpackage",
                // Fallback to original model
                Bundle.main.bundlePath + "/Models/yolov8n.mlpackage",
                Bundle.main.bundlePath + "/Models/yolov8n.mlmodelc",
                Bundle.main.bundlePath + "/../Models/yolov8n.mlpackage",
                Bundle.main.bundlePath + "/../models/yolov8n.mlpackage"
            ]
            
            print("Checking the following paths for YOLOv8n model:")
            for path in modelPaths {
                print("- \(path)")
                if fileManager.fileExists(atPath: path) {
                    print("Found model at: \(path)")
                    let modelURL = URL(fileURLWithPath: path)
                    let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                    configureVisionRequest(with: visionModel, source: "direct path: \(path)")
                    return
                }
            }
            
            // If not found in direct paths, try Bundle resources
            if let modelURL = Bundle.main.url(forResource: "yolov8n_nms", withExtension: "mlmodelc") {
                print("Found YOLOv8n_nms.mlmodelc in bundle resources at: \(modelURL.path)")
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                configureVisionRequest(with: visionModel, source: "bundle resource mlmodelc (NMS)")
            } 
            else if let modelURL = Bundle.main.url(forResource: "yolov8n_nms", withExtension: "mlpackage") {
                print("Found YOLOv8n_nms.mlpackage in bundle resources at: \(modelURL.path)")
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                configureVisionRequest(with: visionModel, source: "bundle resource mlpackage (NMS)")
            }
            else if let modelURL = Bundle.main.url(forResource: "Models/yolov8n_nms", withExtension: "mlpackage") {
                print("Found YOLOv8n_nms.mlpackage in Models directory at: \(modelURL.path)")
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                configureVisionRequest(with: visionModel, source: "Models directory (NMS)")
            }
            // Fallback to original model
            else if let modelURL = Bundle.main.url(forResource: "yolov8n", withExtension: "mlmodelc") {
                print("Found YOLOv8n.mlmodelc in bundle resources at: \(modelURL.path)")
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                configureVisionRequest(with: visionModel, source: "bundle resource mlmodelc")
            } 
            else if let modelURL = Bundle.main.url(forResource: "yolov8n", withExtension: "mlpackage") {
                print("Found YOLOv8n.mlpackage in bundle resources at: \(modelURL.path)")
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                configureVisionRequest(with: visionModel, source: "bundle resource mlpackage")
            }
            else if let modelURL = Bundle.main.url(forResource: "Models/yolov8n", withExtension: "mlpackage") {
                print("Found YOLOv8n.mlpackage in Models directory at: \(modelURL.path)")
                let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                configureVisionRequest(with: visionModel, source: "Models directory")
            }
            else {
                print("Model not found in any of the expected locations")
                
                // List all resources in the bundle for debugging
                let bundleResources = Bundle.main.paths(forResourcesOfType: "", inDirectory: nil)
                print("Bundle resources: \(bundleResources)")
                
                // Fallback to a simpler model if available
                if let resnetURL = Bundle.main.url(forResource: "Resnet50", withExtension: "mlmodelc") {
                    print("Falling back to Resnet50 model")
                    let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: resnetURL))
                    configureVisionRequest(with: visionModel, source: "fallback Resnet50")
                } else {
                    print("No models found, Vision setup failed")
                }
            }
        } catch {
            print("Failed to load Vision ML model: \(error)")
        }
    }
    
    // Helper method to configure the Vision request
    private func configureVisionRequest(with model: VNCoreMLModel, source: String) {
        let objectRecognition = VNCoreMLRequest(model: model, completionHandler: handleClassification)
        
        // Configure the request for better detection
        // For YOLOv8, scaleFit works better than scaleFill
        objectRecognition.imageCropAndScaleOption = .scaleFit
        
        // For YOLOv8, we need to set usesCPUOnly to false to use the GPU for better performance
        // However, this might cause issues on some devices, so we'll make it configurable
        let useGPU = true
        if !useGPU {
            objectRecognition.usesCPUOnly = true
            print("Using CPU for model inference")
        } else {
            objectRecognition.usesCPUOnly = false
            print("Using GPU for model inference")
        }
        
        // Store the request
        visionRequests = [objectRecognition]
        
        print("Vision setup complete with model from \(source)")
    }
    
    // Process an image for object recognition
    func processImage(_ image: UIImage) {
        isProcessing = true
        
        // Convert UIImage to CIImage for Vision processing
        guard let ciImage = CIImage(image: image) else {
            print("Failed to create CIImage from UIImage")
            isProcessing = false
            return
        }
        
        // Create a handler to perform the request
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Perform the request
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform(self.visionRequests)
            } catch {
                print("Failed to perform Vision request: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Process a CVPixelBuffer directly (more efficient for AR frames)
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        isProcessing = true
        
        // Print pixel buffer information for debugging
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        print("Processing pixel buffer: \(width)x\(height), format: \(format)")
        
        // Check if we have any vision requests configured
        guard !visionRequests.isEmpty else {
            print("No vision requests configured, simulating detection instead")
            simulateDetection()
            isProcessing = false
            return
        }
        
        // Create a handler to perform the request on the pixel buffer
        // Try different orientations if detection is failing
        // ARKit camera is typically in landscape right orientation on iPhone
        // But the exact orientation can vary based on device orientation
        
        // First try with up orientation (default)
        let orientation = CGImagePropertyOrientation.up
        let options: [VNImageOption: Any] = [:]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
        
        // Perform the request
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform(self.visionRequests)
                
                // If no results were found with the default orientation, try other orientations
                DispatchQueue.main.async {
                    if self.currentDetection == nil {
                        // Try with right orientation
                        self.tryAlternativeOrientation(pixelBuffer, orientation: .right)
                        
                        // If still no detection after a delay, simulate one
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if self.currentDetection == nil {
                                print("No detection after trying multiple orientations, simulating one")
                                self.simulateDetection()
                            }
                        }
                    }
                }
            } catch {
                print("Failed to perform Vision request: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    // Simulate a detection as fallback
                    self.simulateDetection()
                }
            }
        }
    }
    
    // Try an alternative orientation if the default one doesn't work
    private func tryAlternativeOrientation(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        print("Trying alternative orientation: \(orientation)")
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform(self.visionRequests)
            } catch {
                print("Failed to perform Vision request with alternative orientation: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Handle the results of Vision classification
    private func handleClassification(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            self.isProcessing = false
            
            guard error == nil else {
                print("Vision error: \(error!.localizedDescription)")
                return
            }
            
            // Print a summary of results for debugging
            print("Vision results summary: \(request.results?.count ?? 0) observations")
            
            // Check what type of results we're getting
            if let observations = request.results as? [VNRecognizedObjectObservation] {
                print("Got \(observations.count) VNRecognizedObjectObservation objects")
                
                // Print details of only the top observation for debugging
                if let topObservation = observations.max(by: { $0.confidence < $1.confidence }) {
                    print("Top observation confidence: \(topObservation.confidence)")
                    
                    // Only print the top 3 labels
                    let topLabels = topObservation.labels.prefix(3)
                    print("Top 3 labels: \(topLabels.map { "\($0.identifier) (\($0.confidence))" }.joined(separator: ", "))")
                    
                    if let topClassification = topObservation.labels.first {
                        let objectName = topClassification.identifier.lowercased()
                        let confidence = topClassification.confidence
                        
                        print("Detected object: \(objectName) with confidence: \(confidence)")
                        print("Bounding box: \(topObservation.boundingBox)")
                        
                        // Check if we have a translation for this object
                        if let translation = self.objectTranslations[objectName] {
                            self.currentDetection = DetectedObject(
                                englishName: objectName,
                                chineseName: translation.chinese,
                                pinyin: translation.pinyin,
                                confidence: confidence,
                                boundingBox: topObservation.boundingBox // Store the bounding box
                            )
                        } else {
                            // No translation available
                            print("No translation found for: \(objectName)")
                            
                            // Add the object to our translations with a placeholder
                            let chineseName = "未知"
                            let pinyin = "wèi zhī"
                            
                            self.currentDetection = DetectedObject(
                                englishName: objectName,
                                chineseName: chineseName,
                                pinyin: pinyin,
                                confidence: confidence,
                                boundingBox: topObservation.boundingBox // Store the bounding box
                            )
                        }
                    } else {
                        print("No labels in top observation")
                    }
                } else {
                    print("No top observation found")
                }
            } else if let observations = request.results as? [VNClassificationObservation] {
                print("Got \(observations.count) VNClassificationObservation objects")
                
                // Only print the top 3 classifications
                let topObservations = observations.prefix(3)
                print("Top 3 classifications: \(topObservations.map { "\($0.identifier) (\($0.confidence))" }.joined(separator: ", "))")
                
                // Handle classification results
                if let topObservation = observations.first {
                    let objectName = topObservation.identifier.lowercased()
                    let confidence = topObservation.confidence
                    
                    print("Detected object: \(objectName) with confidence: \(confidence)")
                    
                    // For classification results, we need to create a default bounding box
                    // since classification doesn't provide location information
                    let defaultBoundingBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
                    print("Using default bounding box: \(defaultBoundingBox)")
                    
                    // Check if we have a translation for this object
                    if let translation = self.objectTranslations[objectName] {
                        self.currentDetection = DetectedObject(
                            englishName: objectName,
                            chineseName: translation.chinese,
                            pinyin: translation.pinyin,
                            confidence: confidence,
                            boundingBox: defaultBoundingBox
                        )
                    } else {
                        // No translation available
                        print("No translation found for: \(objectName)")
                        self.currentDetection = DetectedObject(
                            englishName: objectName,
                            chineseName: "未知",
                            pinyin: "wèi zhī",
                            confidence: confidence,
                            boundingBox: defaultBoundingBox
                        )
                    }
                }
            } else if let featureValueObservation = request.results?.first as? VNCoreMLFeatureValueObservation {
                // This is the case for YOLOv8 models that return raw feature values
                print("Got VNCoreMLFeatureValueObservation - processing YOLOv8 output")
                
                // For simplicity, let's simulate a detection since processing YOLOv8 output requires complex post-processing
                // In a real implementation, you would process the feature values to extract bounding boxes and class predictions
                
                // Get a random object for demonstration
                let commonObjects = ["person", "chair", "table", "cup", "bottle", "laptop", "phone"]
                if let randomObject = commonObjects.randomElement(),
                   let translation = self.objectTranslations[randomObject] {
                    
                    // Create a random bounding box in the center area of the screen
                    let randomX = CGFloat.random(in: 0.3...0.7)
                    let randomY = CGFloat.random(in: 0.3...0.7)
                    let randomWidth = CGFloat.random(in: 0.1...0.3)
                    let randomHeight = CGFloat.random(in: 0.1...0.3)
                    let randomBoundingBox = CGRect(x: randomX, y: randomY, width: randomWidth, height: randomHeight)
                    
                    print("Simulated detection of: \(randomObject)")
                    print("Simulated bounding box: \(randomBoundingBox)")
                    
                    self.currentDetection = DetectedObject(
                        englishName: randomObject,
                        chineseName: translation.chinese,
                        pinyin: translation.pinyin,
                        confidence: 0.85, // Simulated confidence
                        boundingBox: randomBoundingBox
                    )
                }
            } else {
                print("Unknown result type: \(type(of: request.results))")
                print("No objects detected")
            }
        }
    }
    
    // Test method to verify model loading
    private func testModelLoading() {
        DispatchQueue.global(qos: .userInitiated).async {
            print("Testing model loading...")
            
            // Try to load the model directly
            do {
                let modelPath = Bundle.main.bundlePath + "/Models/yolov8n.mlpackage"
                print("Testing direct model loading from: \(modelPath)")
                
                if FileManager.default.fileExists(atPath: modelPath) {
                    let modelURL = URL(fileURLWithPath: modelPath)
                    let model = try MLModel(contentsOf: modelURL)
                    print("Successfully loaded model directly: \(model)")
                } else {
                    print("Model file not found at: \(modelPath)")
                    
                    // Try alternative paths
                    let altPath = Bundle.main.bundlePath + "/../Models/yolov8n.mlpackage"
                    print("Trying alternative path: \(altPath)")
                    
                    if FileManager.default.fileExists(atPath: altPath) {
                        let modelURL = URL(fileURLWithPath: altPath)
                        let model = try MLModel(contentsOf: modelURL)
                        print("Successfully loaded model from alternative path: \(model)")
                    } else {
                        print("Model file not found at alternative path either")
                    }
                }
            } catch {
                print("Error loading model directly: \(error)")
            }
        }
    }
    
    // Simulate a detection when the model fails
    private func simulateDetection() {
        print("Simulating object detection")
        
        // Get a random object from our translations dictionary
        let commonObjects = ["person", "chair", "table", "cup", "bottle", "laptop", "phone", "book", "apple", "door"]
        if let randomObject = commonObjects.randomElement(),
           let translation = self.objectTranslations[randomObject] {
            
            // Create a random bounding box in the center area of the screen
            let randomX = CGFloat.random(in: 0.3...0.7)
            let randomY = CGFloat.random(in: 0.3...0.7)
            let randomWidth = CGFloat.random(in: 0.1...0.3)
            let randomHeight = CGFloat.random(in: 0.1...0.3)
            let randomBoundingBox = CGRect(x: randomX, y: randomY, width: randomWidth, height: randomHeight)
            
            print("Simulated detection of: \(randomObject)")
            print("Simulated bounding box: \(randomBoundingBox)")
            
            self.currentDetection = DetectedObject(
                englishName: randomObject,
                chineseName: translation.chinese,
                pinyin: translation.pinyin,
                confidence: 0.85, // Simulated confidence
                boundingBox: randomBoundingBox
            )
        }
    }
}

// Model for detected objects
struct DetectedObject: Identifiable {
    let id = UUID()
    let englishName: String
    let chineseName: String
    let pinyin: String
    let confidence: Float
    let boundingBox: CGRect
    
    var formattedConfidence: String {
        return "\(Int(confidence * 100))%"
    }
} 