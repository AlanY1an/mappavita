import Foundation
import Photos
import CoreLocation
import UIKit

class PhotoLocationManager {
    
    static let shared = PhotoLocationManager()
    
    private init() {}
    
    // Check if we have photo library access permissions
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        @unknown default:
            completion(false)
        }
    }
    
    // Extract location data from a PHAsset
    func getLocationData(from asset: PHAsset, completion: @escaping (CLLocation?) -> Void) {
        if let location = asset.location {
            completion(location)
        } else {
            completion(nil)
        }
    }
    
    // Fetch photos with location data
    func fetchPhotosWithLocation(completion: @escaping ([PHAsset]) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        var assetsWithLocation: [PHAsset] = []
        
        fetchResult.enumerateObjects { (asset, _, _) in
            if asset.location != nil {
                assetsWithLocation.append(asset)
            }
        }
        
        completion(assetsWithLocation)
    }
    
    // Convert PHAsset to UIImage
    func getImage(from asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    // Get all necessary information about a photo including image, location, and creation date
    func getPhotoInfo(from asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?, CLLocation?, Date?) -> Void) {
        getImage(from: asset, targetSize: targetSize) { image in
            completion(image, asset.location, asset.creationDate)
        }
    }
    
    // Fetch places from photos with location data
    func fetchPhotoPlaces() async throws -> [Place] {
        // 1. Check permission
        let hasPermission = await withCheckedContinuation { continuation in
            checkPhotoLibraryPermission { hasPermission in
                continuation.resume(returning: hasPermission)
            }
        }
        
        guard hasPermission else { return [] }
        
        // 2. Get photos with location data
        let assets = await withCheckedContinuation { continuation in
            fetchPhotosWithLocation { assets in
                continuation.resume(returning: assets)
            }
        }
        
        // 3. Process photos and create places
        var places = [Place]()
        let geocoder = CLGeocoder()
        
        for asset in assets {
            guard let location = asset.location else { continue }
            
            // Get place information using reverse geocoding
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks?.first else { continue }
            
            // Create place object
            let place = Place(
                id: UUID().uuidString,
                name: generatePlaceName(from: placemark),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                visitDate: asset.creationDate ?? Date(),
                description: nil,
                photos: nil,
                category: categoryFromPlacemark(placemark),
                address: generateAddress(from: placemark),
                photoAssetIdentifier: asset.localIdentifier,
                memories: []
            )
            
            // Prevent duplicate places
            if !places.contains(where: { arePlacesNearby($0, place) }) {
                places.append(place)
            }
        }
        
        return places
    }
    
    // Helper method to generate place name
    private func generatePlaceName(from placemark: CLPlacemark) -> String {
        if let name = placemark.name, !name.isEmpty {
            return name
        } else if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                return "\(subThoroughfare) \(thoroughfare)"
            }
            return thoroughfare
        } else if let locality = placemark.locality {
            return locality
        } else if let administrativeArea = placemark.administrativeArea {
            return administrativeArea
        } else {
            return "Unknown Location"
        }
    }
    
    // Helper method to generate address
    private func generateAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    // Helper method to determine category from placemark
    private func categoryFromPlacemark(_ placemark: CLPlacemark) -> String? {
        if placemark.areasOfInterest?.first != nil {
            return "Point of Interest"
        } else if placemark.inlandWater != nil || placemark.ocean != nil {
            return "Water Feature"
        } else if placemark.administrativeArea != nil {
            return "City/Region"
        }
        return nil
    }
    
    // Helper method to check if two places are nearby (to avoid duplicates)
    private func arePlacesNearby(_ place1: Place, _ place2: Place) -> Bool {
        let location1 = CLLocation(latitude: place1.latitude, longitude: place1.longitude)
        let location2 = CLLocation(latitude: place2.latitude, longitude: place2.longitude)
        
        // If they're within 100 meters, consider them the same place
        return location1.distance(from: location2) < 100
    }
} 
