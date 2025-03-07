#!/usr/bin/swift

import Foundation
import CoreML

// Clean up the label to make it more readable
func cleanLabel(_ label: String) -> String {
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

// Extract categories from the ML model
func extractCategories(from modelPath: String) -> [String] {
    let modelURL = URL(fileURLWithPath: modelPath)
    
    do {
        // First, try to compile the model
        print("Compiling model at \(modelPath)...")
        let compiledURL = try MLModel.compileModel(at: modelURL)
        print("Model compiled successfully at: \(compiledURL.path)")
        
        // Load the compiled model
        let model = try MLModel(contentsOf: compiledURL)
        
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
                // Clean up the label
                let cleanedLabel = cleanLabel(stringLabel)
                categories.append(cleanedLabel)
            }
        }
        
        return categories.sorted()
    } catch {
        print("Failed to process model: \(error)")
        return []
    }
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

// Main function
func main() {
    // Parse command line arguments
    let arguments = CommandLine.arguments
    
    if arguments.count < 3 {
        print("Usage: \(arguments[0]) <model_path> <output_path>")
        print("  model_path: Path to the .mlmodel file")
        print("  output_path: Path to save the extracted categories")
        exit(1)
    }
    
    let modelPath = arguments[1]
    let outputPath = arguments[2]
    
    // Check if model file exists
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: modelPath) {
        print("Error: Model file not found at \(modelPath)")
        exit(1)
    }
    
    print("Model file found at: \(modelPath)")
    
    // Extract categories
    let categories = extractCategories(from: modelPath)
    
    // Print results
    if categories.isEmpty {
        print("No categories found in the model")
    } else {
        print("Found \(categories.count) categories")
        
        // Save to file
        if saveCategoriesToFile(categories: categories, outputPath: outputPath) {
            print("Categories saved to: \(outputPath)")
        }
    }
}

// Run the main function
main() 