import Foundation


struct Achievement: Identifiable, Codable, Equatable {
    var id: String?
    var title: String
    var description: String
    var icon: String
    var dateUnlocked: Date?
    var isUnlocked: Bool
    var requiredCount: Int
    var currentCount: Int
    var type: AchievementType
    var userId: String?
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case icon
        case dateUnlocked
        case isUnlocked
        case requiredCount
        case currentCount
        case type
        case userId
    }
}

enum AchievementType: String, Codable, CaseIterable {
    case places
    case photos
    case memories
    case countries
    case cities
    case distance
    case streak
}
