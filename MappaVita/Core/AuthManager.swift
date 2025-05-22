import Foundation
import FirebaseAuth
import Combine

enum AuthError: Error {
    case signInFailed
    case signUpFailed
    case signOutFailed
    case userNotFound
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .signInFailed:
            return "Failed to sign in. Please check your credentials."
        case .signUpFailed:
            return "Failed to create account. Please try again."
        case .signOutFailed:
            return "Failed to sign out. Please try again."
        case .userNotFound:
            return "No user found with this email."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password should be at least 6 characters."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .unknown:
            return "An unknown error occurred. Please try again."
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var error: AuthError?
    
    private var cancellables = Set<AnyCancellable>()
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let firebaseUser = user,
               let user = User(firebaseUser: firebaseUser) {
                self.currentUser = user
                self.isAuthenticated = true
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    deinit {
        if let handle = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            if let user = User(firebaseUser: result.user) {
                currentUser = user
                isAuthenticated = true
            }
        } catch {
            handleAuthError(error)
            throw AuthError.signInFailed
        }
    }
    
    func signUp(email: String, password: String, username: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            if let user = User(firebaseUser: result.user) {
                currentUser = user
                isAuthenticated = true
            }
        } catch {
            handleAuthError(error)
            throw AuthError.signUpFailed
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            self.error = .signOutFailed
            throw AuthError.signOutFailed
        }
    }
    
    private func handleAuthError(_ error: Error) {
        if let errorCode = AuthErrorCode(_bridgedNSError: error as NSError) {
            switch errorCode {
            case .userNotFound:
                self.error = .userNotFound
            case .invalidEmail:
                self.error = .invalidEmail
            case .weakPassword:
                self.error = .weakPassword
            case .emailAlreadyInUse:
                self.error = .emailAlreadyInUse
            default:
                self.error = .unknown
            }
        } else {
            self.error = .unknown
        }
    }
} 
