import Foundation
import MapKit
import SwiftUI
import Photos
import CoreLocation

@MainActor
class PlaceDetailViewModel: ObservableObject {
    let place: Place
    @Published var placeImage: UIImage?
    @Published var isLoadingImage = false
    
    init(place: Place) {
        self.place = place
        loadPlaceImage()
    }
    
    var formattedVisitDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: place.visitDate)
    }
    
    var formattedCoordinates: String {
        return String(format: "%.6f, %.6f", place.latitude, place.longitude)
    }
    
    var hasAddress: Bool {
        place.address != nil && !place.address!.isEmpty
    }
    
    var hasCategory: Bool {
        place.category != nil && !place.category!.isEmpty
    }
    
    var hasPhotoAsset: Bool {
        place.photoAssetIdentifier != nil
    }
    
    func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = place.name
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        ])
    }
    
    private func loadPlaceImage() {
        guard let assetIdentifier = place.photoAssetIdentifier else { return }
        
        isLoadingImage = true
        
        // Fetch the asset using its identifier
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            isLoadingImage = false
            return
        }
        
        // Request the image
        PhotoLocationManager.shared.getImage(from: asset, targetSize: CGSize(width: 600, height: 400)) { [weak self] image in
                DispatchQueue.main.async {
                    self?.placeImage = image
                self?.isLoadingImage = false
            }
        }
    }
    
    func memorySelected(_ memory: Memory) {
        // Post notification to show memory detail
        NotificationCenter.default.post(
            name: NSNotification.Name("MemorySelected"),
            object: memory
        )
    }
} 
