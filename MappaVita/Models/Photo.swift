import Foundation
import CoreLocation


struct Photo: Identifiable, Codable, Equatable {
    var id: String?
    var url: String
    var thumbnailUrl: String?
    var dateCreated: Date
    var latitude: Double
    var longitude: Double
    var userId: String
    var placeId: String?
    var memoryId: String?
    var description: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case thumbnailUrl
        case dateCreated
        case latitude
        case longitude
        case userId
        case placeId
        case memoryId
        case description
    }
}
