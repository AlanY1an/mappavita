import Foundation
import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MappaVita")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                print("CoreData: Saving context with changes...")
                try context.save()
                print("CoreData: Context saved successfully")
            } catch {
                let nserror = error as NSError
                print("CoreData: Error saving context - \(nserror), \(nserror.userInfo)")
                // Log error instead of fatal error to prevent app crash
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        } else {
            print("CoreData: No changes to save in context")
        }
    }
    
    // MARK: - Memory CRUD Operations
    
    func createMemory(placeId: String, title: String, text: String, isStarred: Bool = false) -> Memory? {
        let context = viewContext
        
      
        guard let placeEntity = fetchPlaceEntity(withId: placeId) else {
            print("Failed to find place with ID: \(placeId)")
            return nil
        }
        
    
        let memoryEntity = MemoryEntity(context: context)
        memoryEntity.id = UUID().uuidString
        memoryEntity.title = title
        memoryEntity.text = text
        memoryEntity.dateCreated = Date()
        memoryEntity.placeId = placeId
        memoryEntity.isStarred = isStarred
        
        memoryEntity.place = placeEntity
    
        do {
            try context.save()
            
            return convertToMemory(from: memoryEntity)
        } catch {
            print("Failed to save memory: \(error)")
            context.rollback()
            return nil
        }
    }
    
    func fetchAllMemories() -> [Memory] {
        let context = viewContext
        let fetchRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        
        do {
            let memoryEntities = try context.fetch(fetchRequest)
            return memoryEntities.compactMap { convertToMemory(from: $0) }
        } catch {
            print("Failed to fetch memories: \(error)")
            return []
        }
    }
    
    func updateMemory(_ memory: Memory) -> Bool {
        guard let id = memory.id else { return false }
        
        let context = viewContext
        let fetchRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let memoryEntity = results.first else { return false }
            
            memoryEntity.title = memory.title
            memoryEntity.text = memory.description
            memoryEntity.isStarred = memory.isStarred
            
            try context.save()
            return true
        } catch {
            print("Failed to update memory: \(error)")
            return false
        }
    }
    
    func toggleStarred(_ memory: Memory) -> Memory? {
        guard let id = memory.id else { return nil }
        
        let context = viewContext
        let fetchRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let memoryEntity = results.first else { return nil }
            
            memoryEntity.isStarred.toggle()
            
            try context.save()
            return convertToMemory(from: memoryEntity)
        } catch {
            print("Failed to toggle star: \(error)")
            return nil
        }
    }
    
    func deleteMemory(_ memory: Memory) -> Bool {
        guard let id = memory.id else { return false }
        
        let context = viewContext
        let fetchRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let memoryEntity = results.first else { return false }
            
            context.delete(memoryEntity)
            try context.save()
            return true
        } catch {
            print("Failed to delete memory: \(error)")
            return false
        }
    }
    
    // MARK: - Place Operations
    
    func fetchPlaceEntity(withId id: String) -> PlaceEntity? {
        let context = viewContext
        let fetchRequest: NSFetchRequest<PlaceEntity> = PlaceEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Failed to fetch place: \(error)")
            return nil
        }
    }
    
    func savePlace(_ place: Place) -> Bool {
        let context = viewContext
        
        do {
            // Check if the place already exists
            let fetchRequest: NSFetchRequest<PlaceEntity> = PlaceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", place.id)
            
            let existingPlaces = try context.fetch(fetchRequest)
            
            if let existingPlace = existingPlaces.first {
                // Update existing place
                print("Updating existing place: \(place.name) (ID: \(place.id))")
                existingPlace.name = place.name
                existingPlace.latitude = place.latitude
                existingPlace.longitude = place.longitude
                existingPlace.visitDate = place.visitDate
                existingPlace.placeDescription = place.description
                existingPlace.category = place.category
                existingPlace.address = place.address
                existingPlace.photoAssetIdentifier = place.photoAssetIdentifier
                existingPlace.placeType = place.placeType
                
           
                if let stayDuration = place.stayDuration {
                    existingPlace.stayDuration = stayDuration
                }
            } else {
                // Create new place
                print("Creating new place: \(place.name) (ID: \(place.id))")
                let placeEntity = PlaceEntity(context: context)
                placeEntity.id = place.id
                placeEntity.name = place.name
                placeEntity.latitude = place.latitude
                placeEntity.longitude = place.longitude
                placeEntity.visitDate = place.visitDate
                placeEntity.placeDescription = place.description
                placeEntity.category = place.category
                placeEntity.address = place.address
                placeEntity.photoAssetIdentifier = place.photoAssetIdentifier
                placeEntity.placeType = place.placeType
                
           
                if let stayDuration = place.stayDuration {
                    placeEntity.stayDuration = stayDuration
                }
            }
            
            try context.save()
            return true
        } catch {
            print("Failed to save place: \(error)")
            return false
        }
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToMemory(from entity: MemoryEntity) -> Memory? {
        guard let id = entity.id,
              let title = entity.title,
              let placeId = entity.placeId,
              let dateCreated = entity.dateCreated else {
            return nil
        }
        
  
        var latitude: Double = 0
        var longitude: Double = 0
        
        if let place = entity.place {
            latitude = place.latitude
            longitude = place.longitude
        }
        
        return Memory(
            id: id,
            title: title,
            description: entity.text,
            dateCreated: dateCreated,
            latitude: latitude,
            longitude: longitude,
            userId: UserDefaults.standard.string(forKey: "userId") ?? "unknown",
            placeId: placeId,
            isStarred: entity.isStarred
        )
    }
    
    // MARK: - Batch Delete Operations
    
    func deleteAllMemories() {
        let context = viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MemoryEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            NotificationCenter.default.post(name: NSNotification.Name("MemoriesUpdated"), object: nil)
        } catch {
            print("Failed to delete all memories: \(error)")
        }
    }
    
    func deleteAllPlaces() {
        let context = viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PlaceEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            NotificationCenter.default.post(name: NSNotification.Name("PlacesUpdated"), object: nil)
        } catch {
            print("Failed to delete all places: \(error)")
        }
    }
    
    func deleteAllData() {
        deleteAllMemories()
        deleteAllPlaces()
    }
    
   
    func deletePlace(withID id: String) {
        let request: NSFetchRequest<PlaceEntity> = PlaceEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try persistentContainer.viewContext.fetch(request)
            if let placeToDelete = results.first {
                persistentContainer.viewContext.delete(placeToDelete)
                saveContext()
                print("✅ Successfully deleted place with ID \(id)")
            } else {
                print("⚠️ Place with ID \(id) not found")
            }
        } catch {
            print("❌ Error deleting place: \(error.localizedDescription)")
        }
    }
} 