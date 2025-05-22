import Foundation
import CoreLocation

struct Place: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let visitDate: Date
    let description: String?
    let photos: [String]? // URLs to photos
    let category: String?
    let address: String?
    let photoAssetIdentifier: String? // Store the PHAsset localIdentifier
    let memories: [Memory]
    let placeType: String? // "photo", "place", or "location"
    let stayDuration: TimeInterval? // Duration in seconds the user stayed at this location
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(id: String = UUID().uuidString,
         name: String,
         latitude: Double,
         longitude: Double,
         visitDate: Date = Date(),
         description: String? = nil,
         photos: [String]? = nil,
         category: String? = nil,
         address: String? = nil,
         photoAssetIdentifier: String? = nil,
         memories: [Memory] = [],
         placeType: String? = nil,
         stayDuration: TimeInterval? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.visitDate = visitDate
        self.description = description
        self.photos = photos
        self.category = category
        self.address = address
        self.photoAssetIdentifier = photoAssetIdentifier
        self.memories = memories
        self.placeType = placeType
        self.stayDuration = stayDuration
    }
    
    init(id: String = UUID().uuidString,
         name: String,
         coordinate: CLLocationCoordinate2D,
         visitDate: Date = Date(),
         description: String? = nil,
         photos: [String]? = nil,
         category: String? = nil,
         address: String? = nil,
         photoAssetIdentifier: String? = nil,
         memories: [Memory] = [],
         placeType: String? = nil,
         stayDuration: TimeInterval? = nil) {
        self.init(
            id: id,
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            visitDate: visitDate,
            description: description,
            photos: photos,
            category: category,
            address: address,
            photoAssetIdentifier: photoAssetIdentifier,
            memories: memories,
            placeType: placeType,
            stayDuration: stayDuration
        )
    }
    
    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Codable
extension Place {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case visitDate
        case description
        case photos
        case category
        case address
        case photoAssetIdentifier
        case memories
        case placeType
        case stayDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        visitDate = try container.decode(Date.self, forKey: .visitDate)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        photos = try container.decodeIfPresent([String].self, forKey: .photos)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        photoAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .photoAssetIdentifier)
        memories = try container.decodeIfPresent([Memory].self, forKey: .memories) ?? []
        placeType = try container.decodeIfPresent(String.self, forKey: .placeType)
        stayDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .stayDuration)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(visitDate, forKey: .visitDate)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(photos, forKey: .photos)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(photoAssetIdentifier, forKey: .photoAssetIdentifier)
        try container.encode(memories, forKey: .memories)
        try container.encodeIfPresent(placeType, forKey: .placeType)
        try container.encodeIfPresent(stayDuration, forKey: .stayDuration)
    }
}
