import Foundation
import Vision
import UIKit
import CoreML

class YOLOv8ObjectDetector {
    // YOLO model constants
    private let yoloClassLabels = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
        "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
        "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
        "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
        "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
        "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair",
        "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
        "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
        "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
    ]
    
    // Confidence threshold for detections
    private let confidenceThreshold: Float = 0.3
    
    // Vision request for object detection
    private var visionRequest: VNCoreMLRequest?
    
    // Flag to track initialization status
    private var isInitialized = false
    private var initializationError: Error?
    
    // Throttle detection to reduce CPU usage
    private var lastDetectionTime: TimeInterval = 0
    private let detectionThrottleInterval: TimeInterval = 0.2 // 5 detections per second max
    
    // Completion handler type
    typealias DetectionCompletion = (_ detections: [DetectedObject]?, _ error: Error?) -> Void
    
    // Detected object structure
    struct DetectedObject {
        let label: String
        let confidence: Float
        let boundingBox: CGRect
    }
    
    // Singleton instance
    static let shared = YOLOv8ObjectDetector()
    
    // Initialize the detector
    init() {
        // Setup in background to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupVisionModel()
        }
    }
    
    // Set up the Vision model
    private func setupVisionModel() {
        do {
            // List all resources in the bundle to debug
            if let bundleURL = Bundle.main.resourceURL {
                print("Bundle URL: \(bundleURL.path)")
                let fileManager = FileManager.default
                if let contents = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil) {
                    print("Bundle contents:")
                    for item in contents {
                        print("- \(item.lastPathComponent)")
                    }
                }
            }
            
            // Try different approaches to find the model
            var modelURL: URL?
            
            // Approach 1: Try to find the .mlpackage file directly
            if let url = Bundle.main.url(forResource: "yolov8n", withExtension: "mlpackage") {
                print("Found model at path 1: \(url.path)")
                modelURL = url
            }
            // Approach 2: Try to find the model in a subdirectory
            else if let url = Bundle.main.url(forResource: "Models/yolov8n", withExtension: "mlpackage") {
                print("Found model at path 2: \(url.path)")
                modelURL = url
            }
            // Approach 3: Try to find the compiled model
            else if let url = Bundle.main.url(forResource: "yolov8n", withExtension: "mlmodelc") {
                print("Found compiled model at: \(url.path)")
                modelURL = url
            }
            
            guard let finalModelURL = modelURL else {
                // Search for any .mlpackage or .mlmodelc files in the bundle
                if let bundleURL = Bundle.main.resourceURL {
                    let fileManager = FileManager.default
                    if let contents = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
                        print("Searching for ML models in bundle:")
                        for item in contents {
                            if item.pathExtension == "mlpackage" || item.pathExtension == "mlmodelc" {
                                print("Found potential model: \(item.path)")
                            }
                        }
                    }
                }
                
                let error = NSError(domain: "YOLODetector", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to find yolov8n model in bundle"])
                print("Error: \(error.localizedDescription)")
                self.initializationError = error
                return
            }
            
            print("Using model at: \(finalModelURL.path)")
            
            // Try to access the model file to verify it exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: finalModelURL.path) {
                let error = NSError(domain: "YOLODetector", code: 4, userInfo: [NSLocalizedDescriptionKey: "Model file exists in bundle but cannot be accessed"])
                print("Error: \(error.localizedDescription)")
                self.initializationError = error
                return
            }
            
            // Load the model with memory optimization options
            let model: MLModel
            do {
                // Create model configuration with memory optimization
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndGPU // Use both CPU and GPU for better performance
                config.allowLowPrecisionAccumulationOnGPU = true // Allow low precision for better performance
                config.preferredMetalDevice = MTLCreateSystemDefaultDevice() // Use default Metal device
                
                if finalModelURL.pathExtension == "mlpackage" {
                    // Compile the model first if it's an .mlpackage
                    print("Compiling model...")
                    let compiledModelURL = try MLModel.compileModel(at: finalModelURL)
                    print("Model compiled successfully at: \(compiledModelURL.path)")
                    model = try MLModel(contentsOf: compiledModelURL, configuration: config)
                } else {
                    // Load directly if it's already compiled
                    model = try MLModel(contentsOf: finalModelURL, configuration: config)
                }
                print("Model loaded successfully")
            } catch {
                print("Error loading model: \(error.localizedDescription)")
                self.initializationError = error
                return
            }
            
            // Create a Vision model from the Core ML model
            let visionModel: VNCoreMLModel
            do {
                visionModel = try VNCoreMLModel(for: model)
                print("Vision model created successfully")
            } catch {
                print("Error creating Vision model: \(error.localizedDescription)")
                self.initializationError = error
                return
            }
            
            // Create a Vision request with the model
            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            }
            
            // Configure the request
            request.imageCropAndScaleOption = .centerCrop
            visionRequest = request
            isInitialized = true
            print("YOLOv8n model initialized successfully")
        } catch {
            print("Unexpected error setting up Vision model: \(error)")
            self.initializationError = error
        }
    }
    
    // Process detections from the Vision request
    private var currentDetectionCompletion: DetectionCompletion?
    
    private func processDetections(for request: VNRequest, error: Error?) {
        // Handle any errors
        if let error = error {
            currentDetectionCompletion?(nil, error)
            return
        }
        
        // Get the results
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            currentDetectionCompletion?(nil, NSError(domain: "YOLODetector", code: 1, userInfo: [NSLocalizedDescriptionKey: "No detection results"]))
            return
        }
        
        // Process the results
        var detectedObjects: [DetectedObject] = []
        
        for observation in results {
            // Only include observations with confidence above threshold
            guard observation.confidence > confidenceThreshold else { continue }
            
            // Get the top classification
            if let topClassification = observation.labels.first {
                let object = DetectedObject(
                    label: topClassification.identifier,
                    confidence: topClassification.confidence,
                    boundingBox: observation.boundingBox
                )
                detectedObjects.append(object)
            }
        }
        
        // Sort by confidence (highest first)
        detectedObjects.sort { $0.confidence > $1.confidence }
        
        // Limit the number of detections to reduce memory usage
        let limitedDetections = Array(detectedObjects.prefix(5))
        
        // Return the results
        currentDetectionCompletion?(limitedDetections, nil)
        currentDetectionCompletion = nil
    }
    
    // Detect objects in an image
    func detectObjects(in pixelBuffer: CVPixelBuffer, completion: @escaping DetectionCompletion) {
        // Check if model is initialized
        if !isInitialized {
            if let error = initializationError {
                completion(nil, error)
            } else {
                // If still initializing, wait a bit and try again
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.detectObjects(in: pixelBuffer, completion: completion)
                }
            }
            return
        }
        
        // Throttle detection to reduce CPU usage
        let currentTime = CACurrentMediaTime()
        if currentTime - lastDetectionTime < detectionThrottleInterval {
            // Skip this detection to reduce CPU usage
            completion(nil, nil)
            return
        }
        lastDetectionTime = currentTime
        
        // Store the completion handler
        currentDetectionCompletion = completion
        
        // Create a handler for the pixel buffer
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        // Perform the request
        guard let request = visionRequest else {
            completion(nil, NSError(domain: "YOLODetector", code: 2, userInfo: [NSLocalizedDescriptionKey: "Vision request not initialized"]))
            return
        }
        
        do {
            try handler.perform([request])
        } catch {
            completion(nil, error)
        }
    }
    
    // Get all class labels
    func getClassLabels() -> [String] {
        return yoloClassLabels
    }
    
    // Check if the model is initialized and ready to use
    func isModelInitialized() -> Bool {
        return isInitialized
    }
} 