//
//  Persistence.swift
//  YOLO
//
//  Created as part of the Tono integration
//

import CoreData
import SceneKit
import UIKit

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
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
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

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                print("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// Helper methods for working with TaggedObjects
extension PersistenceController {
    
    // Save a new tagged object
    func saveTaggedObject(english: String, chinese: String, pinyin: String, image: UIImage?, position: SCNVector3, context: NSManagedObjectContext) {
        print("\n=========== SAVING TAGGED OBJECT: \(english) ===========")
        
        // Check if this object already exists in the collection
        if isDuplicate(english: english, chinese: chinese, context: context) {
            print("Object '\(english)' already exists in collection, not saving duplicate")
            return
        }
        
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
        
        // Debug image info
        if let image = image {
            print("Original image dimensions: \(image.size.width) x \(image.size.height)")
            print("Original image scale: \(image.scale)")
            print("Original image orientation: \(image.imageOrientation.rawValue)")
        } else {
            print("WARNING: No image provided for object: \(english)")
        }
        
        // Convert image to data for storage
        if let image = image {
            // First normalize the image orientation
            let normalizedImage = normalizeImageOrientation(image)
            print("Image orientation normalized: \(normalizedImage.imageOrientation.rawValue)")
            
            // Then resize the image to a reasonable size
            let maxDimension: CGFloat = 1200
            var scaledImage = normalizedImage
            
            if normalizedImage.size.width > maxDimension || normalizedImage.size.height > maxDimension {
                let scale = min(maxDimension / normalizedImage.size.width, maxDimension / normalizedImage.size.height)
                let newSize = CGSize(width: normalizedImage.size.width * scale, height: normalizedImage.size.height * scale)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                normalizedImage.draw(in: CGRect(origin: .zero, size: newSize))
                if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    scaledImage = resizedImage
                    print("Resized image to: \(newSize.width) x \(newSize.height)")
                } else {
                    print("WARNING: Failed to resize image")
                }
                UIGraphicsEndImageContext()
            }
            
            // Try progressively lower quality until we succeed or give up
            var imageData: Data?
            var quality: CGFloat = 1.0
            
            while imageData == nil && quality >= 0.5 {
                imageData = scaledImage.jpegData(compressionQuality: quality)
                if imageData == nil {
                    print("Failed to create JPEG with quality \(quality), trying lower")
                    quality -= 0.1
                }
            }
            
            if let imageData = imageData {
                newObject.image = imageData
                print("Successfully converted image (\(scaledImage.size.width)x\(scaledImage.size.height)) to JPEG data: \(imageData.count) bytes with quality \(quality)")
                
                // Verify the image data is valid
                if UIImage(data: imageData) != nil {
                    print("Verified image data is valid - can create UIImage from it")
                } else {
                    print("WARNING: Image data verification failed - cannot create UIImage from saved data!")
                }
            } else {
                print("ERROR: Failed to convert image to JPEG data for object: \(english) after multiple attempts")
            }
        }
        
        do {
            try context.save()
            print("Successfully saved tagged object: \(english) to Core Data")
            
            // Post a notification that a new object was saved
            NotificationCenter.default.post(name: Notification.Name("TaggedObjectSaved"), object: nil)
            print("Posted TaggedObjectSaved notification")
        } catch {
            let nsError = error as NSError
            print("ERROR saving tagged object: \(nsError), \(nsError.userInfo)")
        }
        print("=============== SAVE COMPLETED ==============\n")
    }
    
    // Helper to normalize image orientation
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
    
    // Check if an object with the same Chinese text already exists
    func isDuplicate(english: String, chinese: String, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<TaggedObject> = TaggedObject.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chinese ==[c] %@", chinese)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if !results.isEmpty {
                print("Object with Chinese text '\(chinese)' already exists in collection, not saving duplicate")
                return true
            }
            return false
        } catch {
            print("Error checking for duplicate: \(error)")
            return false
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
        
        // Objects are due for review if nextReviewDate <= now
        let now = Date()
        fetchRequest.predicate = NSPredicate(format: "nextReviewDate <= %@ OR nextReviewDate == nil", now as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaggedObject.lastReviewDate, ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching objects due for review: \(error)")
            return []
        }
    }
    
    // Delete all tagged objects from Core Data
    func deleteAllTaggedObjects(context: NSManagedObjectContext) {
        // Fetch all objects
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TaggedObject.fetchRequest()
        
        // Create a batch delete request
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            // Execute the delete
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                // Sync the deletion with the managed object context
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
            
            // Save context changes
            try context.save()
            print("Successfully deleted all tagged objects")
        } catch {
            print("Error deleting tagged objects: \(error)")
        }
    }
    
    // Update review status after a successful review
    func updateReviewStatus(for object: TaggedObject, wasCorrect: Bool, context: NSManagedObjectContext) {
        // Implementation of SM-2 spaced repetition algorithm
        // Based on SuperMemo-2 algorithm: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
        
        let now = Date()
        object.lastReviewDate = now
        
        if wasCorrect {
            // Increase success count
            object.successCount += 1
            
            // Calculate new interval based on review count and success
            if object.reviewCount == 0 {
                // First successful review - review again in 1 day
                object.reviewInterval = 1
            } else if object.reviewCount == 1 {
                // Second successful review - review again in 6 days
                object.reviewInterval = 6
            } else {
                // For subsequent reviews, multiply the previous interval by a factor
                // The factor increases as the success count increases
                let factor = min(2.5, 1.3 + Double(object.successCount) * 0.1)
                object.reviewInterval = Int32(Double(object.reviewInterval) * factor)
                
                // Cap the maximum interval at 60 days
                object.reviewInterval = min(60, object.reviewInterval)
            }
            
            // Increment review count
            object.reviewCount += 1
        } else {
            // Reset success count on failure
            object.successCount = 0
            
            // Reset interval to 1 day on failure
            object.reviewInterval = 1
            
            // Don't increment review count on failure
        }
        
        // Calculate next review date
        object.nextReviewDate = Calendar.current.date(byAdding: .day, value: Int(object.reviewInterval), to: now)
        
        do {
            try context.save()
            print("Updated review status for: \(object.english ?? "unknown"), next review in \(object.reviewInterval) days")
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