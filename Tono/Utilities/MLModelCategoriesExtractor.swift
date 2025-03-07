import Foundation
import CoreML
import Vision

class MLModelCategoriesExtractor {
    static let shared = MLModelCategoriesExtractor()
    
    // Get all categories from the Inceptionv3 model
    func extractCategories() -> [String] {
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
        // Remove numbers and underscores
        var cleanedLabel = label
        
        // Replace underscores with spaces
        cleanedLabel = cleanedLabel.replacingOccurrences(of: "_", with: " ")
        
        // Remove any leading numbers and dots (e.g., "123. cat" -> "cat")
        if let range = cleanedLabel.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
            cleanedLabel = String(cleanedLabel[range.upperBound...])
        }
        
        // Trim whitespace
        cleanedLabel = cleanedLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize first letter of each word
        cleanedLabel = cleanedLabel.split(separator: " ")
            .map { $0.prefix(1).capitalized + $0.dropFirst() }
            .joined(separator: " ")
        
        return cleanedLabel
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