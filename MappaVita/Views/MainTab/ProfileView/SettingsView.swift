import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isEditingProfile = false
    @State private var showLogoutAlert = false
    
    // Editable fields
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var gender: String = "Undisclosed"
    
    init() {
        // Initialize the view model with the environment AuthManager
        // This will be set properly when the view appears
        _viewModel = StateObject(wrappedValue: ProfileViewModel(authManager: AuthManager()))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header Section
                        profileHeader
                        
                        // Profile Edit Form
                        if isEditingProfile {
                            profileEditForm
                        }
                        
                        // Settings Sections
                        settingsSections
                        
                        // Logout Button
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            Text("Log Out")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if isEditingProfile {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveProfile()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isEditingProfile = false
                            resetFormFields()
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            isEditingProfile = true
                        }
                    }
                }
            }
            .onChange(of: selectedAvatar) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        avatarImage = uiImage
                    }
                }
            }
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("Log Out"),
                    message: Text("Are you sure you want to log out?"),
                    primaryButton: .destructive(Text("Log Out")) {
                        viewModel.logout()
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                // Update the viewModel with the environment's AuthManager
                viewModel.updateAuthManager(authManager)
                loadUserData()
                
                // Add notification for when profile is updated elsewhere
                NotificationCenter.default.addObserver(forName: NSNotification.Name("ProfileUpdated"), object: nil, queue: .main) { _ in
                    loadUserData()
                }
            }
            .onDisappear {
                // Remove notification observers
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 15) {
            if isEditingProfile {
                // Avatar picker in edit mode
                PhotosPicker(
                    selection: $selectedAvatar,
                    matching: .images,
                    photoLibrary: .shared()) {
                        profileImageView
                            .overlay(
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(Color.white))
                                    .offset(x: 40, y: 40)
                            )
                    }
            } else {
                // Static avatar in view mode
                profileImageView
            }
            
            if !isEditingProfile {
                VStack(spacing: 4) {
                    Text(viewModel.profile?.name ?? viewModel.profile?.username ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(viewModel.profile?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let gender = viewModel.profile?.gender, gender != "Undisclosed" {
                        Text(gender)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    
                    if let bio = viewModel.profile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    
                    if let joinDate = viewModel.profile?.joinDate {
                        Text("Joined \(joinDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var profileImageView: some View {
        Group {
            if let avatarImage = avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(radius: 3)
            } else if let profileImage = viewModel.profile?.avatarImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(radius: 3)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(radius: 3)
            }
        }
    }
    
    // MARK: - Profile Edit Form
    private var profileEditForm: some View {
        VStack(spacing: 20) {
            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Your full name", text: $name)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Username Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Your username", text: $username)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Bio Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Bio")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $bio)
                    .frame(height: 100)
                    .padding(4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Gender Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Select gender", selection: $gender) {
                    Text("Prefer not to say").tag("Undisclosed")
                    Text("Male").tag("Male")
                    Text("Female").tag("Female")
                    Text("Non-binary").tag("Non-binary")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Settings Sections
    private var settingsSections: some View {
        VStack(spacing: 20) {
            // App Preferences
            settingsSection(title: "App Preferences", items: [
                SettingsItem(title: "App Theme", icon: "paintbrush.fill", iconColor: .purple) {
                    // Theme selection action
                },
                SettingsItem(title: "Notifications", icon: "bell.fill", iconColor: .red) {
                    // Notifications settings action
                },
                SettingsItem(title: "Privacy", icon: "lock.fill", iconColor: .blue) {
                    // Privacy settings action
                }
            ])
            
            // Help & Support
            settingsSection(title: "Help & Support", items: [
                SettingsItem(title: "FAQ", icon: "questionmark.circle.fill", iconColor: .orange) {
                    // FAQ action
                },
                SettingsItem(title: "Contact Support", icon: "envelope.fill", iconColor: .green) {
                    // Contact action
                },
                SettingsItem(title: "About", icon: "info.circle.fill", iconColor: .gray) {
                    // About action
                }
            ])
        }
    }
    
    private func settingsSection(title: String, items: [SettingsItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button(action: item.action) {
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundColor(item.iconColor)
                                .frame(width: 24, height: 24)
                            
                            Text(item.title)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    
                    if items.last?.id != item.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    private func loadUserData() {
        Task {
            // Print debug info
            print("SettingsView: Loading user data with userID: \(authManager.currentUser?.id ?? "nil")")
            
            if let userId = authManager.currentUser?.id {
                // Create direct AuthViewModel to avoid multi-layer indirection
                let directViewModel = AuthViewModel(authManager: authManager)
                
                // Load profile directly
                if let profile = directViewModel.loadUserProfile(userId: userId) {
                    DispatchQueue.main.async {
                        self.viewModel.profile = profile
                        
                        // Set local states for editing
                        self.name = profile.name ?? ""
                        self.username = profile.username
                        self.bio = profile.bio ?? ""
                        self.gender = profile.gender ?? "Undisclosed"
                        
                        if let profileImage = profile.avatarImage {
                            self.avatarImage = profileImage
                        }
                        
                        print("SettingsView: Profile loaded - Name: \(profile.name ?? "nil"), Bio: \(profile.bio ?? "nil")")
                    }
                } else {
                    print("SettingsView: Failed to load profile for user ID: \(userId)")
                }
            }
        }
    }
    
    private func saveProfile() {
        Task {
            guard let userId = authManager.currentUser?.id else {
                print("Error: No user ID available when saving profile")
                return
            }
            
            // Create direct AuthViewModel to avoid multi-layer indirection
            let directViewModel = AuthViewModel(authManager: authManager)
            
            // Debug info
            print("SettingsView: Saving profile - Name: \(name), Bio: \(bio), UserID: \(userId)")
            
            // Update user profile directly
            directViewModel.updateUserProfile(
                userId: userId,
                name: name,
                username: username,
                gender: gender,
                bio: bio,
                avatarImage: avatarImage
            )
            
            // Force refresh the profile
            if let updatedProfile = directViewModel.loadUserProfile(userId: userId) {
                DispatchQueue.main.async {
                    self.viewModel.profile = updatedProfile
                    print("SettingsView: Profile saved - Name: \(updatedProfile.name ?? "nil"), Bio: \(updatedProfile.bio ?? "nil")")
                }
            }
            
            // Post notification that profile was updated
            NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
            
            isEditingProfile = false
        }
    }
    
    private func resetFormFields() {
        if let profile = viewModel.profile {
            name = profile.name ?? ""
            username = profile.username
            bio = profile.bio ?? ""
            gender = profile.gender ?? "Undisclosed"
            
            // Reset avatar image back to original
            if avatarImage != profile.avatarImage {
                avatarImage = profile.avatarImage
            }
        }
    }
}

// MARK: - Supporting Types
struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
}

// MARK: - View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func updateAuthManager(_ newAuthManager: AuthManager) {
        self.authManager = newAuthManager
    }
    
    func loadProfile() async {
        isLoading = true
        
        if let userId = authManager.currentUser?.id {
            let authViewModel = AuthViewModel(authManager: authManager)
            profile = authViewModel.loadUserProfile(userId: userId)
        }
        
        isLoading = false
    }
    
    func updateProfile(name: String, username: String, bio: String, gender: String, avatarImage: UIImage?) async {
        isLoading = true
        
        if let userId = authManager.currentUser?.id {
            let authViewModel = AuthViewModel(authManager: authManager)
            
            // Ensure CoreData operation completes
            authViewModel.updateUserProfile(
                userId: userId,
                name: name,
                username: username,
                gender: gender,
                bio: bio,
                avatarImage: avatarImage
            )
            
            // Reload profile after update to ensure we have the latest data
            DispatchQueue.main.async {
                self.profile = authViewModel.loadUserProfile(userId: userId)
            }
        }
        
        isLoading = false
    }
    
    func logout() {
        Task {
            do {
                try authManager.signOut()
            } catch {
                self.error = error
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}
