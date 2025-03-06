//
//  Persistence.swift
//  Tono
//
//  Created by Daniel Gilles on 3/6/25.
//

import CoreData
import SceneKit

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Tono")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// Helper methods for working with TaggedObjects
extension PersistenceController {
    
    // Save a new tagged object
    func saveTaggedObject(english: String, chinese: String, pinyin: String, image: UIImage?, position: SCNVector3, context: NSManagedObjectContext) {
        let newObject = TaggedObject(context: context)
        newObject.english = english
        newObject.chinese = chinese
        newObject.pinyin = pinyin
        newObject.timestamp = Date()
        newObject.lastReviewDate = Date()
        newObject.reviewCount = 0
        
        // Store position components separately
        newObject.positionX = position.x
        newObject.positionY = position.y
        newObject.positionZ = position.z
        
        // Convert image to data for storage
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            newObject.image = imageData
        }
        
        do {
            try context.save()
            print("Successfully saved tagged object: \(english)")
        } catch {
            let nsError = error as NSError
            print("Error saving tagged object: \(nsError), \(nsError.userInfo)")
        }
    }
    
    // Get all tagged objects
    func fetchTaggedObjects(context: NSManagedObjectContext) -> [TaggedObject] {
        let fetchRequest: NSFetchRequest<TaggedObject> = TaggedObject.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching tagged objects: \(error)")
            return []
        }
    }
    
    // Get tagged objects due for review based on SRS
    func fetchObjectsDueForReview(context: NSManagedObjectContext) -> [TaggedObject] {
        let fetchRequest: NSFetchRequest<TaggedObject> = TaggedObject.fetchRequest()
        
        // Objects are due for review if lastReviewDate + interval < now
        let now = Date()
        fetchRequest.predicate = NSPredicate(format: "lastReviewDate < %@", now as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaggedObject.lastReviewDate, ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching objects due for review: \(error)")
            return []
        }
    }
    
    // Update review status after a successful review
    func updateReviewStatus(for object: TaggedObject, wasCorrect: Bool, context: NSManagedObjectContext) {
        // Simple SRS implementation - increase interval based on review count
        object.lastReviewDate = Date()
        
        if wasCorrect {
            object.reviewCount += 1
        } else {
            // Reset review count if answer was incorrect
            object.reviewCount = max(0, object.reviewCount - 1)
        }
        
        do {
            try context.save()
            print("Updated review status for: \(object.english ?? "unknown")")
        } catch {
            print("Error updating review status: \(error)")
        }
    }
}

// Extension to TaggedObject to provide convenience methods for position
extension TaggedObject {
    // Get the position as SCNVector3
    var position: SCNVector3 {
        return SCNVector3(x: positionX, y: positionY, z: positionZ)
    }
    
    // Set the position from SCNVector3
    func setPosition(_ vector: SCNVector3) {
        positionX = vector.x
        positionY = vector.y
        positionZ = vector.z
    }
}
