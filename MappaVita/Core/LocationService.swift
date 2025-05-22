import Foundation
import CoreLocation
import Photos

// This class is used to provide the function like reverse geocoding, extracting places from photos, etc.   
actor LocationService {
    static let shared = LocationService()
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> (String?, String?, String?) {
        return await withCheckedContinuation { continuation in
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                guard error == nil, let placemark = placemarks?.first else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }
                
                // Get place name (locality or name of the point of interest)
                let name = placemark.name ?? placemark.locality ?? placemark.subLocality ?? "Unknown Location"
                
                // Get address
                let address = [
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.locality,
                    placemark.subLocality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                    placemark.country
                ]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                
                // Get category (we can use areasOfInterest or administrativeArea)
                let category = placemark.areasOfInterest?.first ?? placemark.administrativeArea ?? "Place"
                
                continuation.resume(returning: (name, address, category))
            }
        }
    }
    
    func extractPlacesFromPhotos() async -> [Place] {
        return await withCheckedContinuation { continuation in
            let photoManager = PhotoLocationManager.shared
            var places: [Place] = []
            
            photoManager.checkPhotoLibraryPermission { granted in
                guard granted else {
                    continuation.resume(returning: [])
                    return
                }
                
                photoManager.fetchPhotosWithLocation { assets in
                    Task {
                        let group = DispatchGroup()
                        
                        for asset in assets {
                            group.enter()
                            
                            guard let location = asset.location else {
                                group.leave()
                                continue
                            }
                            
                            let (name, address, category) = await self.reverseGeocode(coordinate: location.coordinate)
                            
                            if let name = name {
                                let place = Place(
                                    id: UUID().uuidString,
                                    name: name,
                                    latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude,
                                    visitDate: asset.creationDate ?? Date(),
                                    category: category,
                                    address: address,
                                    photoAssetIdentifier: asset.localIdentifier
                                )
                                
                                // Check for duplicates before adding based on photo identifier
                                let isDuplicate = places.contains { existingPlace in
                                    // Check if we already have this photo asset
                                    if existingPlace.photoAssetIdentifier == asset.localIdentifier {
                                        return true
                                    }
                                    
                                    // Consider places within 50 meters as the same place
                                    let existingLocation = CLLocation(
                                        latitude: existingPlace.latitude,
                                        longitude: existingPlace.longitude
                                    )
                                    let newLocation = CLLocation(
                                        latitude: place.latitude,
                                        longitude: place.longitude
                                    )
                                    return existingLocation.distance(from: newLocation) < 50
                                }
                                
                                if !isDuplicate {
                                    places.append(place)
                                }
                            }
                            
                            group.leave()
                        }
                        
                        group.notify(queue: .main) {
                            continuation.resume(returning: places)
                        }
                    }
                }
            }
        }
    }
    
    func extractAndSavePlacesFromPhotos(_ completion: @escaping (Bool) -> Void) async {
        let places = await extractPlacesFromPhotos()
        
        await MainActor.run {
            let placeStore = PlaceStore.shared
            
            for place in places {
                placeStore.addPlace(place)
            }
            
            completion(!places.isEmpty)
        }
    }
} 