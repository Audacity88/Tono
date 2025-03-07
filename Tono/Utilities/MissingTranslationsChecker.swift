import Foundation
import CoreData
import SwiftUI

class MissingTranslationsChecker {
    static let shared = MissingTranslationsChecker()
    
    // Find all ML model categories without translations
    func findMissingTranslations() -> [String] {
        // Get all categories from the ML model
        let modelCategories = MLModelCategoriesExtractor.shared.extractCategories()
        
        // Get all translations
        let translationManager = TranslationManager.shared
        let allTranslations = translationManager.getAllTranslations()
        
        // Find categories without translations
        var missingTranslations: [String] = []
        
        for category in modelCategories {
            let lowercased = category.lowercased()
            if allTranslations[lowercased] == nil {
                missingTranslations.append(category)
            }
        }
        
        return missingTranslations.sorted()
    }
    
    // Save missing translations to a file
    func saveMissingTranslationsToFile(missingTranslations: [String]) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("missing_translations.txt")
        
        let content = missingTranslations.joined(separator: "\n")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Missing translations saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error saving missing translations: \(error)")
            return nil
        }
    }
    
    // Generate a JSON template for missing translations
    func generateJSONTemplate(missingTranslations: [String]) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("missing_translations_template.json")
        
        var jsonObjects: [[String: String]] = []
        
        for english in missingTranslations {
            jsonObjects.append([
                "english": english,
                "chinese": "",
                "pinyin": "",
                "category": "general"
            ])
        }
        
        let jsonData: [String: [[String: String]]] = ["objects": jsonObjects]
        
        do {
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try jsonEncoder.encode(jsonData)
            try data.write(to: fileURL)
            print("JSON template saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error generating JSON template: \(error)")
            return nil
        }
    }
}

// SwiftUI View for checking missing translations
struct MissingTranslationsCheckerView: View {
    @State private var missingTranslations: [String] = []
    @State private var isChecking = false
    @State private var fileURL: URL? = nil
    @State private var jsonURL: URL? = nil
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Actions")) {
                    Button(action: checkMissingTranslations) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Check Missing Translations")
                        }
                    }
                    .disabled(isChecking)
                    
                    if !missingTranslations.isEmpty {
                        Button(action: saveToFile) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Save to Text File")
                            }
                        }
                        
                        Button(action: generateTemplate) {
                            HStack {
                                Image(systemName: "doc.badge.gearshape")
                                Text("Generate JSON Template")
                            }
                        }
                    }
                    
                    if let url = fileURL {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Saved to: \(url.lastPathComponent)")
                                .font(.caption)
                        }
                    }
                    
                    if let url = jsonURL {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("JSON template saved to: \(url.lastPathComponent)")
                                .font(.caption)
                        }
                    }
                }
                
                if isChecking {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if missingTranslations.isEmpty {
                    Text("No missing translations found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Section(header: Text("Missing Translations (\(missingTranslations.count))")) {
                        ForEach(missingTranslations, id: \.self) { english in
                            Text(english)
                        }
                    }
                }
            }
            .navigationTitle("Missing Translations")
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    private func checkMissingTranslations() {
        isChecking = true
        fileURL = nil
        jsonURL = nil
        
        // Use background thread for processing
        DispatchQueue.global(qos: .userInitiated).async {
            let missing = MissingTranslationsChecker.shared.findMissingTranslations()
            
            DispatchQueue.main.async {
                missingTranslations = missing
                isChecking = false
            }
        }
    }
    
    private func saveToFile() {
        let url = MissingTranslationsChecker.shared.saveMissingTranslationsToFile(missingTranslations: missingTranslations)
        fileURL = url
    }
    
    private func generateTemplate() {
        let url = MissingTranslationsChecker.shared.generateJSONTemplate(missingTranslations: missingTranslations)
        jsonURL = url
    }
}

// Preview provider
struct MissingTranslationsCheckerView_Previews: PreviewProvider {
    static var previews: some View {
        MissingTranslationsCheckerView()
    }
} 