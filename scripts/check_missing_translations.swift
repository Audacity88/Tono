#!/usr/bin/swift

import Foundation

// Define the translation structures
struct TranslationItem: Codable {
    let english: String
    let chinese: String
    let pinyin: String
    let category: String
}

struct TranslationData: Codable {
    let objects: [TranslationItem]
}

// Load translations from file
func loadTranslations(from path: String) -> [String: (chinese: String, pinyin: String)]? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        print("Error: Could not load translations file at \(path)")
        return nil
    }
    
    do {
        let translationData = try JSONDecoder().decode(TranslationData.self, from: data)
        
        // Build dictionary
        var translationDictionary: [String: (chinese: String, pinyin: String)] = [:]
        for object in translationData.objects {
            translationDictionary[object.english.lowercased()] = (chinese: object.chinese, pinyin: object.pinyin)
        }
        
        return translationDictionary
    } catch {
        print("Error decoding translations: \(error)")
        return nil
    }
}

// Load objects from file
func loadObjects(from path: String) -> [String]? {
    guard let data = try? String(contentsOfFile: path) else {
        print("Error: Could not load objects file at \(path)")
        return nil
    }
    
    // Split by lines and trim whitespace
    let objects = data.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    
    return objects
}

// Find missing translations
func findMissingTranslations(objects: [String], translations: [String: (chinese: String, pinyin: String)]) -> [String] {
    var missingTranslations: [String] = []
    
    for object in objects {
        let lowercased = object.lowercased()
        if translations[lowercased] == nil {
            missingTranslations.append(object)
        }
    }
    
    return missingTranslations
}

// Generate JSON template for missing translations
func generateJSONTemplate(missingTranslations: [String], outputPath: String) -> Bool {
    var jsonObjects: [[String: String]] = []
    
    for english in missingTranslations {
        // Use lowercase for english field and maintain the correct order
        jsonObjects.append([
            "english": english.lowercased(),
            "chinese": "",
            "pinyin": "",
            "category": english.lowercased()
        ])
    }
    
    do {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Create a custom encoder to maintain field order
        let customEncoder = JSONEncoder()
        customEncoder.outputFormatting = [.prettyPrinted]
        
        // Convert to JSON string with custom formatting
        var jsonString = "{\n  \"objects\": [\n"
        
        for (index, object) in jsonObjects.enumerated() {
            jsonString += "    {\n"
            jsonString += "      \"english\": \"\(object["english"] ?? "")\",\n"
            jsonString += "      \"chinese\": \"\",\n"
            jsonString += "      \"pinyin\": \"\",\n"
            jsonString += "      \"category\": \"\(object["category"] ?? "")\"\n"
            jsonString += "    }"
            
            if index < jsonObjects.count - 1 {
                jsonString += ","
            }
            
            jsonString += "\n"
        }
        
        jsonString += "  ]\n}"
        
        try jsonString.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        return true
    } catch {
        print("Error generating JSON template: \(error)")
        return false
    }
}

// Main function
func main() {
    // Parse command line arguments
    let arguments = CommandLine.arguments
    
    if arguments.count < 3 {
        print("Usage: \(arguments[0]) <translations_json_path> <objects_list_path> [output_json_path]")
        print("  translations_json_path: Path to the translations.json file")
        print("  objects_list_path: Path to a text file with one object name per line")
        print("  output_json_path: (Optional) Path to save the JSON template for missing translations")
        exit(1)
    }
    
    let translationsPath = arguments[1]
    let objectsPath = arguments[2]
    let outputPath = arguments.count > 3 ? arguments[3] : "missing_translations_template.json"
    
    // Load translations
    guard let translations = loadTranslations(from: translationsPath) else {
        print("Failed to load translations")
        exit(1)
    }
    
    // Load objects
    guard let objects = loadObjects(from: objectsPath) else {
        print("Failed to load objects")
        exit(1)
    }
    
    // Find missing translations
    let missingTranslations = findMissingTranslations(objects: objects, translations: translations)
    
    // Print results
    if missingTranslations.isEmpty {
        print("No missing translations found!")
    } else {
        print("Found \(missingTranslations.count) missing translations:")
        for (index, translation) in missingTranslations.enumerated() {
            print("\(index + 1). \(translation)")
        }
        
        // Generate JSON template
        if generateJSONTemplate(missingTranslations: missingTranslations, outputPath: outputPath) {
            print("\nJSON template saved to: \(outputPath)")
        }
    }
}

// Run the main function
main() 