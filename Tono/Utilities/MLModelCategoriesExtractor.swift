import Foundation
import CoreML
import Vision

class MLModelCategoriesExtractor {
    static let shared = MLModelCategoriesExtractor()
    
    // YOLO class labels
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
    
    // Get all categories from the model
    func extractCategories() -> [String] {
        // For YOLOv8n, we return the predefined class labels
        return yoloClassLabels
    }
    
    // Get categories from Inceptionv3 (legacy method)
    func extractCategoriesFromInceptionv3() -> [String] {
        // First try to find the model in the bundle
        guard let modelURL = Bundle.main.url(forResource: "Inceptionv3", withExtension: "mlmodel") else {
            print("Failed to find model in bundle")
            return []
        }
        
        print("Found model at: \(modelURL.path)")
        
        // Compile the model
        do {
            print("Compiling model...")
            let compiledURL = try MLModel.compileModel(at: modelURL)
            print("Model compiled successfully at: \(compiledURL.path)")
            return extractCategoriesFromModel(at: compiledURL)
        } catch {
            print("Failed to compile model: \(error)")
            
            // As a fallback, try to find the already compiled model
            if let compiledModelURL = Bundle.main.url(forResource: "Inceptionv3", withExtension: "mlmodelc") {
                print("Found compiled model at: \(compiledModelURL.path)")
                return extractCategoriesFromModel(at: compiledModelURL)
            }
            
            return []
        }
    }
    
    private func extractCategoriesFromModel(at url: URL) -> [String] {
        do {
            // Load the model
            let model = try MLModel(contentsOf: url)
            
            // Get the model description
            let modelDescription = model.modelDescription
            
            // Check if the model has class labels
            guard let classLabels = modelDescription.classLabels else {
                print("Model does not have class labels")
                return []
            }
            
            // Convert class labels to strings
            var categories: [String] = []
            for label in classLabels {
                if let stringLabel = label as? String {
                    // Clean up the label (remove numbers, underscores, etc.)
                    let cleanedLabel = cleanLabel(stringLabel)
                    categories.append(cleanedLabel)
                }
            }
            
            return categories.sorted()
        } catch {
            print("Failed to load model: \(error)")
            return []
        }
    }
    
    // Clean up the label to make it more readable
    private func cleanLabel(_ label: String) -> String {
        // Replace underscores with spaces
        return label.replacingOccurrences(of: "_", with: " ")
    }
    
    // Save categories to a file
    func saveCategoriesToFile(categories: [String], outputPath: String) -> Bool {
        let content = categories.joined(separator: "\n")
        
        do {
            try content.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error saving categories to file: \(error)")
            return false
        }
    }
} 