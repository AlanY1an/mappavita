import Foundation
import Combine
import UIKit
import CoreData

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var name = ""
    @Published var gender = "Undisclosed"
    @Published var bio = ""
    @Published var isLoading = false
    @Published var error: AuthError?
    
    private var authManager: AuthManager
    private let coreDataManager = CoreDataManager.shared
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func updateAuthManager(_ newAuthManager: AuthManager) {
        self.authManager = newAuthManager
    }
    
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isValidPassword: Bool {
        return password.count >= 6
    }
    
    var isValidUsername: Bool {
        return username.count >= 3
    }
    
    func signIn() async {
        guard isValidEmail && isValidPassword else {
            error = .invalidEmail
            return
        }
        
        isLoading = true
        do {
            try await authManager.signIn(email: email, password: password)
            error = nil
        } catch {
            self.error = error as? AuthError ?? .unknown
        }
        isLoading = false
    }
    
    func signUp(avatarImage: UIImage? = nil) async {
        guard isValidEmail && isValidPassword && isValidUsername else {
            error = .invalidEmail
            return
        }
        
        isLoading = true
        do {
            try await authManager.signUp(email: email, password: password, username: username)
            
            if let userId = authManager.currentUser?.id {
                saveUserProfile(userId: userId, avatarImage: avatarImage)
            }
            
            error = nil
        } catch {
            self.error = error as? AuthError ?? .unknown
        }
        isLoading = false
    }
    
    func signOut() {
        do {
            try authManager.signOut()
            error = nil
        } catch {
            self.error = error as? AuthError ?? .unknown
        }
    }
    
    private func saveUserProfile(userId: String, avatarImage: UIImage? = nil) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", userId)
        
        do {
            let results = try coreDataManager.viewContext.fetch(fetchRequest)
            let userEntity: NSManagedObject
            
            if let existingUser = results.first {
                userEntity = existingUser
            } else {
                userEntity = NSEntityDescription.insertNewObject(forEntityName: "UserEntity", into: coreDataManager.viewContext)
                userEntity.setValue(userId, forKey: "id")
                userEntity.setValue(Date(), forKey: "joinDate")
            }
            
            userEntity.setValue(email, forKey: "email")
            userEntity.setValue(username, forKey: "username")
            userEntity.setValue(name.isEmpty ? nil : name, forKey: "name")
            userEntity.setValue(gender, forKey: "gender")
            userEntity.setValue(bio.isEmpty ? nil : bio, forKey: "bio")
            
            if let avatarImage {
                if let imageData = avatarImage.jpegData(compressionQuality: 0.7) {
                    userEntity.setValue(imageData, forKey: "avatarImageData")
                }
            }
            
            coreDataManager.saveContext()
            
        } catch {
            print("Failed to save user profile: \(error.localizedDescription)")
        }
    }
    
    func updateUserProfile(userId: String, name: String, username: String? = nil, gender: String, bio: String, avatarImage: UIImage? = nil) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", userId)
        
        do {
            let results = try coreDataManager.viewContext.fetch(fetchRequest)
            
            guard let userEntity = results.first else {
                print("Error: User entity not found for ID: \(userId)")
                return
            }
            
            // Debug existing values
            let existingName = userEntity.value(forKey: "name") as? String
            let existingUsername = userEntity.value(forKey: "username") as? String
            let existingBio = userEntity.value(forKey: "bio") as? String
            print("CoreData - Before update - Name: \(existingName ?? "nil"), Username: \(existingUsername ?? "nil"), Bio: \(existingBio ?? "nil")")
            
            // Set all values, ensuring proper handling of empty strings
            userEntity.setValue(name.isEmpty ? nil : name, forKey: "name")
            if let username = username, !username.isEmpty {
                userEntity.setValue(username, forKey: "username")
            }
            userEntity.setValue(gender, forKey: "gender")
            userEntity.setValue(bio.isEmpty ? nil : bio, forKey: "bio")
            
            if let avatarImage {
                if let imageData = avatarImage.jpegData(compressionQuality: 0.7) {
                    userEntity.setValue(imageData, forKey: "avatarImageData")
                }
            }
            
            // Force save context
            try coreDataManager.viewContext.save()
            coreDataManager.saveContext()
            
            // Debug updated values
            let updatedName = userEntity.value(forKey: "name") as? String
            let updatedUsername = userEntity.value(forKey: "username") as? String
            let updatedBio = userEntity.value(forKey: "bio") as? String
            print("CoreData - After update - Name: \(updatedName ?? "nil"), Username: \(updatedUsername ?? "nil"), Bio: \(updatedBio ?? "nil")")
            
        } catch {
            print("Failed to update user profile: \(error.localizedDescription)")
        }
    }
    
    func loadUserProfile(userId: String) -> UserProfile? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", userId)
        
        do {
            let results = try coreDataManager.viewContext.fetch(fetchRequest)
            
            guard let userEntity = results.first else {
                return nil
            }
            
            var avatar: UIImage? = nil
            if let imageData = userEntity.value(forKey: "avatarImageData") as? Data {
                avatar = UIImage(data: imageData)
            }
            
            return UserProfile(
                id: userEntity.value(forKey: "id") as? String ?? "",
                username: userEntity.value(forKey: "username") as? String ?? "",
                email: userEntity.value(forKey: "email") as? String ?? "",
                name: userEntity.value(forKey: "name") as? String,
                gender: userEntity.value(forKey: "gender") as? String,
                bio: userEntity.value(forKey: "bio") as? String,
                avatarImage: avatar,
                joinDate: userEntity.value(forKey: "joinDate") as? Date ?? Date()
            )
            
        } catch {
            print("Failed to load user profile: \(error.localizedDescription)")
            return nil
        }
    }
}

// Model for user profile
struct UserProfile {
    let id: String
    let username: String
    let email: String
    let name: String?
    let gender: String?
    let bio: String?
    let avatarImage: UIImage?
    let joinDate: Date
}
