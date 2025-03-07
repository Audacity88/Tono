#!/usr/bin/swift

import Foundation
import CoreData

// Define the Core Data model
class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Tono")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}

// Extract objects from Core Data
func extractObjects() -> [String] {
    let context = CoreDataStack.shared.viewContext
    
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TaggedObject")
    fetchRequest.propertiesToFetch = ["english"]
    
    do {
        let results = try context.fetch(fetchRequest) as! [NSManagedObject]
        
        var objects: [String] = []
        for result in results {
            if let english = result.value(forKey: "english") as? String {
                objects.append(english)
            }
        }
        
        return objects.sorted()
    } catch {
        print("Error fetching objects: \(error)")
        return []
    }
}

// Save objects to file
func saveObjectsToFile(objects: [String], outputPath: String) -> Bool {
    let content = objects.joined(separator: "\n")
    
    do {
        try content.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        return true
    } catch {
        print("Error saving objects to file: \(error)")
        return false
    }
}

// Main function
func main() {
    // Parse command line arguments
    let arguments = CommandLine.arguments
    
    if arguments.count < 2 {
        print("Usage: \(arguments[0]) <output_path>")
        print("  output_path: Path to save the extracted objects")
        exit(1)
    }
    
    let outputPath = arguments[1]
    
    // Extract objects
    let objects = extractObjects()
    
    // Print results
    if objects.isEmpty {
        print("No objects found in the Core Data store")
    } else {
        print("Found \(objects.count) objects")
        
        // Save to file
        if saveObjectsToFile(objects: objects, outputPath: outputPath) {
            print("Objects saved to: \(outputPath)")
        }
    }
}

// Run the main function
main() 