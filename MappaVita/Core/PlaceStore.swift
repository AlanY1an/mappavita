import Foundation
import CoreData
import CoreLocation
import SwiftUI

class PlaceStore: ObservableObject {
    static let shared = PlaceStore()
    
    @Published var visitedPlaces: [Place] = []
    private let coreDataManager = CoreDataManager.shared
    
    private init() {
        fetchPlaces()
        
        // Listen for data update notifications 
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlacesUpdated),
            name: NSNotification.Name("PlacesUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePlacesUpdated() {
        fetchPlaces()
    }
    
    // MARK: - Core Data Operations
    
    func fetchPlaces() {
        let request: NSFetchRequest<PlaceEntity> = PlaceEntity.fetchRequest()
        
        do {
            let placeEntities = try coreDataManager.viewContext.fetch(request)
            let memoryStore = MemoryStore.shared
            
            self.visitedPlaces = placeEntities.compactMap { entity in
                guard let id = entity.id,
                      let name = entity.name,
                      let visitDate = entity.visitDate else { return nil }
                
                // Get memories associated with this place
                let placeMemories = memoryStore.getMemoriesForPlace(placeId: id)
                
                return Place(
                    id: id,
                    name: name,
                    latitude: entity.latitude,
                    longitude: entity.longitude,
                    visitDate: visitDate,
                    description: entity.placeDescription,
                    category: entity.category,
                    address: entity.address,
                    photoAssetIdentifier: entity.photoAssetIdentifier,
                    memories: placeMemories,
                    placeType: entity.placeType,
                    stayDuration: entity.stayDuration
                )
            }
        } catch {
            print("Failed to fetch places: \(error.localizedDescription)")
        }
    }
    
    func addPlace(_ place: Place) {
        // First check by ID
        if visitedPlaces.contains(where: { $0.id == place.id }) {
            return
        }
        
        // Then check by location proximity
        if isDuplicateLocation(place) {
            return
        }
        
        // Check for existing photoAssetIdentifier to avoid duplicates
        if let assetId = place.photoAssetIdentifier,
           visitedPlaces.contains(where: { $0.photoAssetIdentifier == assetId }) {
            return
        }
        
        if coreDataManager.savePlace(place) {
            fetchPlaces()
        }
    }
    
    // Helper method to check if a place with similar location exists
    private func isDuplicateLocation(_ place: Place) -> Bool {
        return visitedPlaces.contains { existingPlace in
            let existingLocation = CLLocation(
                latitude: existingPlace.latitude,
                longitude: existingPlace.longitude
            )
            let newLocation = CLLocation(
                latitude: place.latitude,
                longitude: place.longitude
            )
            // Consider places within 50 meters as duplicates
            return existingLocation.distance(from: newLocation) < 50
        }
    }
    
    func deletePlace(_ place: Place) {
        let request: NSFetchRequest<PlaceEntity> = PlaceEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", place.id)
        
        do {
            let matches = try coreDataManager.viewContext.fetch(request)
            for match in matches {
                coreDataManager.viewContext.delete(match)
            }
            
            coreDataManager.saveContext()
            fetchPlaces()
        } catch {
            print("Failed to delete place: \(error.localizedDescription)")
        }
    }
} 