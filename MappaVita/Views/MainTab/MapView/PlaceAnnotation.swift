import Foundation
import MapKit

class PlaceAnnotation: NSObject, MKAnnotation {
    let id: String
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let subtitle: String?
    let type: AnnotationType
    let photoAssetIdentifier: String?
    
    init(id: String, 
         title: String?, 
         coordinate: CLLocationCoordinate2D, 
         subtitle: String? = nil, 
         type: AnnotationType = .place,
         photoAssetIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.coordinate = coordinate
        self.subtitle = subtitle
        self.type = type
        self.photoAssetIdentifier = photoAssetIdentifier
        super.init()
    }
    
    static func fromPlace(_ place: Place) -> PlaceAnnotation {
        return PlaceAnnotation(
            id: place.id,
            title: place.name,
            coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            subtitle: place.category,
            type: place.placeType == "location" ? .location : .place,
            photoAssetIdentifier: place.photoAssetIdentifier
        )
    }
    
    static func fromPhoto(_ photo: Photo) -> PlaceAnnotation {
        return PlaceAnnotation(
            id: photo.id ?? UUID().uuidString,
            title: photo.description ?? "Photo",
            coordinate: photo.coordinate,
            subtitle: nil,
            type: .photo,
            photoAssetIdentifier: nil
        )
    }
    
    static func fromUserLocation(_ location: CLLocation, name: String = "My Location") -> PlaceAnnotation {
        return PlaceAnnotation(
            id: UUID().uuidString,
            title: name,
            coordinate: location.coordinate,
            subtitle: "Current Location",
            type: .location,
            photoAssetIdentifier: nil
        )
    }
}

enum AnnotationType {
    case place
    case photo
    case location
}
