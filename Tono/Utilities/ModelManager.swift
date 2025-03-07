// ModelManager.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import Foundation
import Vision
import UIKit
import CoreML

// Enum to represent available models
enum ModelType: String, CaseIterable, Identifiable {
    case inception = "Inception"
    case yolo = "YOLO"
    case mobileNet = "MobileNet"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .inception:
            return "Inception v3 - General object recognition"
        case .yolo:
            return "YOLOv8 - Fast object detection with bounding boxes"
        case .mobileNet:
            return "MobileNet - Efficient object recognition"
        }
    }
}

// Protocol for object detection models
protocol ObjectDetector {
    func detectObjects(in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]?, Error?) -> Void)
}

// Detected object structure
struct DetectedObject {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}

class ModelManager {
    // Singleton instance
    static let shared = ModelManager()
    
    // Current model type
    private var _currentModelType: ModelType = .inception
    var currentModelType: ModelType {
        get {
            return _currentModelType
        }
        set {
            if _currentModelType != newValue {
                _currentModelType = newValue
                // Save the selection to UserDefaults
                UserDefaults.standard.set(newValue.rawValue, forKey: "selectedModel")
                // Initialize the new model
                initializeCurrentModel()
                // Notify observers about the model change
                NotificationCenter.default.post(name: NSNotification.Name("ModelChanged"), object: nil)
            }
        }
    }
    
    // Model instances
    private var inceptionModel: VNCoreMLModel?
    private var mobileNetModel: VNCoreMLModel?
    
    // Model initialization status
    private var isInceptionInitialized = false
    private var isMobileNetInitialized = false
    private var isInitializing = false
    
    // Confidence threshold for detections
    private let confidenceThreshold: Float = 0.3
    
    // Initialize with saved preference or default to Inception
    private init() {
        if let savedModel = UserDefaults.standard.string(forKey: "selectedModel"),
           let modelType = ModelType(rawValue: savedModel) {
            _currentModelType = modelType
        } else {
            _currentModelType = .inception
        }
        
        // Initialize all models at startup
        initializeAllModels()
    }
    
    // Initialize all models to avoid delays when switching
    private func initializeAllModels() {
        initializeInceptionModel()
        // YOLO is already initialized as a singleton
        initializeMobileNetModel()
    }
    
    // Initialize the current model based on the selected type
    private func initializeCurrentModel() {
        switch currentModelType {
        case .inception:
            if !isInceptionInitialized && !isInitializing {
                initializeInceptionModel()
            }
        case .yolo:
            // YOLO is already initialized as a singleton
            break
        case .mobileNet:
            if !isMobileNetInitialized && !isInitializing {
                initializeMobileNetModel()
            }
        }
    }
    
    // Check if the current model is ready
    func isCurrentModelReady() -> Bool {
        switch currentModelType {
        case .inception:
            return isInceptionInitialized && inceptionModel != nil
        case .yolo:
            return YOLOv8ObjectDetector.shared.isModelInitialized()
        case .mobileNet:
            return isMobileNetInitialized && mobileNetModel != nil
        }
    }
    
    // Initialize Inception model
    private func initializeInceptionModel() {
        isInitializing = true
        print("Starting Inception model initialization...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                if let modelURL = Bundle.main.url(forResource: "Inceptionv3", withExtension: "mlmodel") {
                    // Create model configuration
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuAndGPU
                    
                    // Compile the model first if needed
                    print("Compiling Inception model...")
                    let compiledURL = try MLModel.compileModel(at: modelURL)
                    print("Inception model compiled successfully at: \(compiledURL.path)")
                    
                    // Load the model
                    let model = try MLModel(contentsOf: compiledURL, configuration: config)
                    self.inceptionModel = try VNCoreMLModel(for: model)
                    self.isInceptionInitialized = true
                    print("Inception model initialized successfully")
                } else {
                    print("Failed to find Inception model in bundle")
                    // Try to find the compiled model
                    if let compiledURL = Bundle.main.url(forResource: "Inceptionv3", withExtension: "mlmodelc") {
                        print("Found compiled Inception model at: \(compiledURL.path)")
                        
                        // Create model configuration
                        let config = MLModelConfiguration()
                        config.computeUnits = .cpuAndGPU
                        
                        // Load the model
                        let model = try MLModel(contentsOf: compiledURL, configuration: config)
                        self.inceptionModel = try VNCoreMLModel(for: model)
                        self.isInceptionInitialized = true
                        print("Inception model initialized successfully from compiled model")
                    } else {
                        print("Failed to find compiled Inception model in bundle")
                    }
                }
            } catch {
                print("Error initializing Inception model: \(error)")
            }
            
            self.isInitializing = false
        }
    }
    
    // Initialize MobileNet model
    private func initializeMobileNetModel() {
        isInitializing = true
        print("Starting MobileNet model initialization...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                if let modelURL = Bundle.main.url(forResource: "MobileNet", withExtension: "mlmodel") {
                    // Create model configuration
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuAndGPU
                    
                    // Compile the model first if needed
                    print("Compiling MobileNet model...")
                    let compiledURL = try MLModel.compileModel(at: modelURL)
                    print("MobileNet model compiled successfully at: \(compiledURL.path)")
                    
                    // Load the model
                    let model = try MLModel(contentsOf: compiledURL, configuration: config)
                    self.mobileNetModel = try VNCoreMLModel(for: model)
                    self.isMobileNetInitialized = true
                    print("MobileNet model initialized successfully")
                } else {
                    print("Failed to find MobileNet model in bundle")
                    // Try to find the compiled model
                    if let compiledURL = Bundle.main.url(forResource: "MobileNet", withExtension: "mlmodelc") {
                        print("Found compiled MobileNet model at: \(compiledURL.path)")
                        
                        // Create model configuration
                        let config = MLModelConfiguration()
                        config.computeUnits = .cpuAndGPU
                        
                        // Load the model
                        let model = try MLModel(contentsOf: compiledURL, configuration: config)
                        self.mobileNetModel = try VNCoreMLModel(for: model)
                        self.isMobileNetInitialized = true
                        print("MobileNet model initialized successfully from compiled model")
                    } else {
                        print("Failed to find compiled MobileNet model in bundle")
                    }
                }
            } catch {
                print("Error initializing MobileNet model: \(error)")
            }
            
            self.isInitializing = false
        }
    }
    
    // Detect objects in an image using the current model
    func detectObjects(in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]?, Error?) -> Void) {
        switch currentModelType {
        case .inception:
            if isInceptionInitialized {
                detectWithInception(in: pixelBuffer, completion: completion)
            } else {
                // If model is not initialized yet, try to initialize it and retry after a delay
                if !isInitializing {
                    initializeInceptionModel()
                }
                
                // Retry after a short delay
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if self.isInceptionInitialized {
                        self.detectWithInception(in: pixelBuffer, completion: completion)
                    } else {
                        let error = NSError(domain: "ModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Inception model not initialized"])
                        completion(nil, error)
                    }
                }
            }
        case .yolo:
            YOLOv8ObjectDetector.shared.detectObjects(in: pixelBuffer) { detections, error in
                if let detections = detections {
                    // Convert YOLO detections to our common format
                    let convertedDetections = detections.map { detection in
                        DetectedObject(
                            label: detection.label,
                            confidence: detection.confidence,
                            boundingBox: detection.boundingBox
                        )
                    }
                    completion(convertedDetections, nil)
                } else {
                    completion(nil, error)
                }
            }
        case .mobileNet:
            if isMobileNetInitialized {
                detectWithMobileNet(in: pixelBuffer, completion: completion)
            } else {
                // If model is not initialized yet, try to initialize it and retry after a delay
                if !isInitializing {
                    initializeMobileNetModel()
                }
                
                // Retry after a short delay
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if self.isMobileNetInitialized {
                        self.detectWithMobileNet(in: pixelBuffer, completion: completion)
                    } else {
                        let error = NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "MobileNet model not initialized"])
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    // Detect objects using Inception model
    private func detectWithInception(in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]?, Error?) -> Void) {
        guard let model = inceptionModel else {
            completion(nil, NSError(domain: "ModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Inception model not initialized"]))
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let results = request.results as? [VNClassificationObservation] else {
                completion(nil, NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected result type"]))
                return
            }
            
            // Filter results by confidence threshold
            let filteredResults = results.filter { $0.confidence > self.confidenceThreshold }
            
            // Convert to DetectedObject format
            let detections = filteredResults.map { observation in
                // Inception doesn't provide bounding boxes, so we use the full image
                DetectedObject(
                    label: observation.identifier,
                    confidence: observation.confidence,
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            }
            
            completion(detections, nil)
        }
        
        request.imageCropAndScaleOption = .centerCrop
        
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try handler.perform([request])
        } catch {
            completion(nil, error)
        }
    }
    
    // Detect objects using MobileNet model
    private func detectWithMobileNet(in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]?, Error?) -> Void) {
        guard let model = mobileNetModel else {
            completion(nil, NSError(domain: "ModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "MobileNet model not initialized"]))
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let results = request.results as? [VNClassificationObservation] else {
                completion(nil, NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected result type"]))
                return
            }
            
            // Filter results by confidence threshold
            let filteredResults = results.filter { $0.confidence > self.confidenceThreshold }
            
            // Convert to DetectedObject format
            let detections = filteredResults.map { observation in
                // MobileNet doesn't provide bounding boxes, so we use the full image
                DetectedObject(
                    label: observation.identifier,
                    confidence: observation.confidence,
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            }
            
            completion(detections, nil)
        }
        
        request.imageCropAndScaleOption = .centerCrop
        
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try handler.perform([request])
        } catch {
            completion(nil, error)
        }
    }
} 