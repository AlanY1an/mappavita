import Foundation

import CoreLocation

struct Memory: Identifiable, Codable, Equatable {
    var id: String?
    var title: String
    var description: String?
    var dateCreated: Date
    var latitude: Double
    var longitude: Double
    var userId: String
    var placeId: String?
    var photoIds: [String]?
    var tags: [String]?
    var isStarred: Bool = false
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    static func == (lhs: Memory, rhs: Memory) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case dateCreated
        case latitude
        case longitude
        case userId
        case placeId
        case photoIds
        case tags
        case isStarred
    }
}
