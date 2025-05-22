import Foundation
import FirebaseAuth

struct User: Identifiable, Codable {
    var id: String
    var email: String
    var username: String
    var createdAt: Date
    var profileImageURL: String?
    
    init(id: String = UUID().uuidString,
         email: String,
         username: String,
         createdAt: Date = Date(),
         profileImageURL: String? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.createdAt = createdAt
        self.profileImageURL = profileImageURL
    }
    
    // Firebase user conversion
    init?(firebaseUser: FirebaseAuth.User) {
        guard let email = firebaseUser.email else { return nil }
        self.id = firebaseUser.uid
        self.email = email
        self.username = email.components(separatedBy: "@")[0]
        self.createdAt = Date()
        self.profileImageURL = firebaseUser.photoURL?.absoluteString
    }
}
