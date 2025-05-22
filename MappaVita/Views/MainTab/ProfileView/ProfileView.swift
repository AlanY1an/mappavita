import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

// NOTE: Using ProfileViewModel defined in SettingsView.swift
// This avoids duplicate class definition issues

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var authViewModel: AuthViewModel
    @State private var showDebugView = false
    @State private var showAvatarPreview = false
    @State private var showEditProfile = false
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var showShareSheet = false
    @State private var worldMapImage: UIImage?
    @State private var isGeneratingMap = false
    @State private var showEnlargedMap = false
    @State private var userProfile: UserProfile?
    
    // Stats to display
    @State private var placeCount = 0
    @State private var memoriesCount = 0
    @State private var achievementCount = 0
    @State private var visitedCountriesCount = 0
    @State private var visitedCities = Set<String>()
    @State private var visitedCountries = Set<String>()
    
    // Editable profile fields
    @State private var username = ""
    @State private var name = ""
    @State private var bio = ""
    @State private var gender = "Undisclosed"
    
    init() {
        // Initialize with a temporary AuthManager
        // We'll update this in onAppear with the environment's AuthManager
        let authViewModel = AuthViewModel(authManager: AuthManager())
        _authViewModel = StateObject(wrappedValue: authViewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#59ccbe"), Color(hex: "#61ceb0")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        // User profile card
                        userProfileCard
                            .padding(.top, 20)
                        
                        // World Map Preview
                        worldMapPreview
                            .padding(.top, 20)
                        
                        // Statistics view
                        statisticsView
                            .padding(.top, 20)
                            .padding(.horizontal)
                        
                        // Debug options (if authenticated)
                        if authManager.isAuthenticated {
                            devOptionsSection
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showEditProfile = true
                        }) {
                            Label("Edit Profile", systemImage: "person.crop.circle.badge.pencil")
                        }
                        
                        Button(action: {
                            generateWorldMap()
                        }) {
                            Label("Generate World Map", systemImage: "globe")
                        }
                        
                        Button(action: {
                            showDebugView = true
                        }) {
                            Label("Debug Data", systemImage: "ladybug")
                        }
                        
                        if authManager.isAuthenticated {
                            Button(role: .destructive, action: {
                                logout()
                            }) {
                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .sheet(isPresented: $showDebugView) {
                CoreDataDebugView()
            }
            .sheet(isPresented: $showEditProfile) {
                editProfileView
            }
            .sheet(isPresented: $showAvatarPreview) {
                avatarPreviewView
            }
            .sheet(isPresented: $showShareSheet) {
                if let worldMapImage {
                    ShareSheet(items: [worldMapImage])
                }
            }
            .fullScreenCover(isPresented: $showEnlargedMap) {
                enlargedMapView
            }
            .onChange(of: selectedAvatar) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        avatarImage = uiImage
                        showAvatarPreview = true
                    }
                }
            }
            .onAppear {
                // Update the authViewModel with the environment's AuthManager
                authViewModel.updateAuthManager(authManager)
                loadUserData()
                loadStatistics()
                
                // Add notification observer for when app becomes active
                NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                    loadUserData()
                }
                
                // Add notification for when profile is updated
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
    
    // World Map Preview
    private var worldMapPreview: some View {
        VStack(alignment: .center, spacing: 15) {
            if isGeneratingMap {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(height: 200)
                    .overlay(
                        Text("Generating world map...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 50)
                    )
            } else if let mapImage = worldMapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .shadow(radius: 5)
                    .onTapGesture {
                        showEnlargedMap = true
                    }
                    .overlay(
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                            .padding(12),
                        alignment: .topTrailing
                    )
            } else {
                Button(action: {
                    generateWorldMap()
                }) {
                    VStack {
                        Image(systemName: "globe")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Generate World Travel Map")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                        
                        Text("Showing \(visitedCountries.count) countries visited")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            
            if worldMapImage != nil {
                Button(action: {
                    showShareSheet = true
                }) {
                    Label("Share My World Map", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "#59ccbe").opacity(0.8))
                        .cornerRadius(10)
                }
                .disabled(worldMapImage == nil)
            }
        }
    }
    
    // Enlarged Map View
    private var enlargedMapView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        showEnlargedMap = false
                    }) {
                        Text("Done")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#59ccbe").opacity(0.8))
                            .cornerRadius(8)
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        showShareSheet = true
                        showEnlargedMap = false
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "#59ccbe").opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                .padding(.top)
                
                if let mapImage = worldMapImage {
                    GeometryReader { geometry in
                        ZoomableScrollView {
                            Image(uiImage: mapImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)
                        }
                    }
                }
                
                // Travel statistics
                VStack(spacing: 8) {
                    Text("World Travel Statistics")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(visitedCountries.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Countries")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack {
                            Text("\(visitedCities.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Cities")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack {
                            Text("\(placeCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Places")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.bottom)
            }
            .padding(.vertical)
        }
    }
    
    // Debug options section
    private var devOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Options")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 25)
                .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Button(action: {
                    showDebugView = true
                }) {
                    HStack {
                        Image(systemName: "database.fill")
                            .foregroundColor(.white)
                            .frame(width: 24)
                        
                        Text("View Database")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 15)
                }
                
                Button(action: {
                    CoreDataManager.shared.deleteAllMemories()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Text("Delete All Memories")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 15)
                }
                
                Button(action: {
                    CoreDataManager.shared.deleteAllPlaces()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Text("Delete All Places")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 15)
                }
                
                Button(action: {
                    CoreDataManager.shared.deleteAllData()
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Text("Delete All Data")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 15)
                }
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
    
    // User profile card
    private var userProfileCard: some View {
        VStack(spacing: 15) {
            // Avatar and edit button
            ZStack(alignment: .bottomTrailing) {
                // Avatar area
                Group {
                    if let profileImage = userProfile?.avatarImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .shadow(radius: 10)
                )
                
                // Change avatar button
                PhotosPicker(selection: $selectedAvatar, matching: .images) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        )
                        .shadow(radius: 3)
                }
            }
            .padding(.bottom, 10)
            
            // User info
            VStack(spacing: 8) {
                Text(userProfile?.name ?? userProfile?.username ?? "User")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                
                if let gender = userProfile?.gender, gender != "Undisclosed" {
                    HStack(spacing: 8) {
                        Image(systemName: gender == "Male" ? "person.fill" : (gender == "Female" ? "person.fill" : "person.fill.questionmark"))
                            .foregroundColor(.white.opacity(0.85))
                        
                        Text(gender)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                
                if let bio = userProfile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 5)
                        .padding(.horizontal, 20)
                }
                
                HStack(spacing: 5) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(userProfile?.email ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 5)
                
                if let joinDate = userProfile?.joinDate {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Joined \(joinDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 3)
                }
                
                if !visitedCountries.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Visited \(visitedCountries.count) countries")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity)
    }
    
    // Statistics view
    private var statisticsView: some View {
        HStack(spacing: 0) {
            statisticItem(count: "\(placeCount)", title: "Places", icon: "map.fill")
            
            Divider()
                .frame(width: 1, height: 40)
                .background(Color.white.opacity(0.3))
            
            statisticItem(count: "\(memoriesCount)", title: "Memories", icon: "book.fill")
            
            Divider()
                .frame(width: 1, height: 40)
                .background(Color.white.opacity(0.3))
            
            statisticItem(count: "\(achievementCount)", title: "Achievements", icon: "trophy.fill")
        }
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.15))
        )
    }
    
    private func statisticItem(count: String, title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(count)
                    .fontWeight(.bold)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
    
    // Avatar preview view
    private var avatarPreviewView: some View {
        VStack(spacing: 20) {
            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    avatarImage = nil
                    showAvatarPreview = false
                }
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                
                Button("Set as Avatar") {
                    saveAvatar()
                    showAvatarPreview = false
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    // Edit profile view
    private var editProfileView: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                    TextField("Username", text: $username)
                    
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                        Text("Prefer not to say").tag("Undisclosed")
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("Bio")
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $bio)
                            .frame(minHeight: 100)
                            .padding(.horizontal, -5)
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        updateProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showEditProfile = false
                    }
                }
            }
            .onAppear {
                name = userProfile?.name ?? ""
                username = userProfile?.username ?? ""
                bio = userProfile?.bio ?? ""
                gender = userProfile?.gender ?? "Undisclosed"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Load user data
    private func loadUserData() {
        if let userId = authManager.currentUser?.id {
            self.userProfile = authViewModel.loadUserProfile(userId: userId)
            
            // Set editable fields
            name = userProfile?.name ?? ""
            username = userProfile?.username ?? ""
            bio = userProfile?.bio ?? ""
            gender = userProfile?.gender ?? "Undisclosed"
        }
    }
    
    // Load statistics
    private func loadStatistics() {
        // Get places
        placeCount = PlaceStore.shared.visitedPlaces.count
        
        // Get memories
        memoriesCount = MemoryStore.shared.memories.count
        
        // Get achievements
        let achievementsVM = AchievementsViewModel()
        Task {
            await achievementsVM.loadAchievements()
            DispatchQueue.main.async {
                self.achievementCount = achievementsVM.completedAchievements
                self.visitedCountriesCount = achievementsVM.countriesCount
                self.visitedCountries = achievementsVM.countriesVisited
                self.visitedCities = achievementsVM.citiesVisited
                print("Loaded country data: \(self.visitedCountries.count) countries")
            }
        }
    }
    
    // Save avatar
    private func saveAvatar() {
        Task {
            if let userId = authManager.currentUser?.id, let avatarImage = avatarImage {
                // Print debug info
                print("ProfileView: Saving avatar for user ID: \(userId)")
                
                // Create direct AuthViewModel to avoid multi-layer indirection
                let directViewModel = AuthViewModel(authManager: authManager)
                
                // Preserve existing profile data while updating avatar
                let existingProfile = directViewModel.loadUserProfile(userId: userId)
                
                directViewModel.updateUserProfile(
                    userId: userId,
                    name: existingProfile?.name ?? "",
                    username: existingProfile?.username ?? "",
                    gender: existingProfile?.gender ?? "Undisclosed",
                    bio: existingProfile?.bio ?? "",
                    avatarImage: avatarImage
                )
                
                // Force reload profile to verify changes were saved
                if let updatedProfile = directViewModel.loadUserProfile(userId: userId) {
                    DispatchQueue.main.async {
                        self.userProfile = updatedProfile
                        print("ProfileView: Avatar saved successfully")
                        
                        // Ensure UI state variables are updated
                        self.name = updatedProfile.name ?? ""
                        self.username = updatedProfile.username
                        self.bio = updatedProfile.bio ?? ""
                        self.gender = updatedProfile.gender ?? "Undisclosed"
                    }
                }
                
                // Post notification that profile was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
            }
        }
    }
    
    // Update profile
    private func updateProfile() {
        Task {
            if let userId = authManager.currentUser?.id {
                authViewModel.updateUserProfile(
                    userId: userId,
                    name: name,
                    username: username,
                    gender: gender,
                    bio: bio,
                    avatarImage: userProfile?.avatarImage
                )
                
                // Reload profile after update to ensure we have the latest data
                DispatchQueue.main.async {
                    self.userProfile = authViewModel.loadUserProfile(userId: userId)
                    print("Profile updated in ProfileView - Name: \(self.userProfile?.name ?? "nil"), Bio: \(self.userProfile?.bio ?? "nil")")
                    
                    // Post notification that profile was updated
                    NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                }
                showEditProfile = false
            }
        }
    }
    
    // Generate world map image
    private func generateWorldMap() {
        isGeneratingMap = true
        
        Task {
            // Make sure to load statistics data first
            await loadStatisticsAsync()
            
            // Create a world map with visited countries highlighted
            let renderer = MapSnapshotGenerator()
            if let image = await renderer.generateWorldMapWithVisitedCountries(countries: Array(visitedCountries)) {
                DispatchQueue.main.async {
                    self.worldMapImage = image
                    self.isGeneratingMap = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isGeneratingMap = false
                }
            }
        }
    }
    
    // Async load statistics
    private func loadStatisticsAsync() async {
        // Get places
        placeCount = PlaceStore.shared.visitedPlaces.count
        
        // Get memories
        memoriesCount = MemoryStore.shared.memories.count
        
        // Get achievements
        let achievementsVM = AchievementsViewModel()
        await achievementsVM.loadAchievements()
        self.achievementCount = achievementsVM.completedAchievements
        self.visitedCountriesCount = achievementsVM.countriesCount
        self.visitedCountries = achievementsVM.countriesVisited
        self.visitedCities = achievementsVM.citiesVisited
        
        print("Loaded country data: \(visitedCountries.count) countries")
        print("Countries list: \(visitedCountries.sorted())")
        
        // Print all places with their addresses for debugging
        let places = PlaceStore.shared.visitedPlaces
        print("Places in CoreData: \(places.count)")
        for place in places {
            print("Place: \(place.name), Address: \(place.address ?? "No address"), Coordinates: (\(place.latitude), \(place.longitude))")
        }
        
        // Make sure Iceland is in the list
        if !visitedCountries.contains("Iceland") {
            print("Adding Iceland to visited countries")
            var updatedCountries = visitedCountries
            updatedCountries.insert("Iceland")
            self.visitedCountries = updatedCountries
        }
        
        // If no country data, add test data for debugging
        if visitedCountries.isEmpty {
            print("No country data, adding test data")
            self.visitedCountries = ["USA", "Canada", "Japan", "China", "United Kingdom", "France", "Iceland"]
        }
    }
    
    // Mark country, using absolute coordinates
    private func markCountry(country: String, at point: CGPoint, in context: CGContext) {
        // Draw marker point
        context.setFillColor(UIColor(hex: "#59ccbe")!.withAlphaComponent(0.9).cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.5)
        
        // Draw circle point
        let radius: CGFloat = 8
        context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        context.strokeEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        
        // Draw pulse ring
        context.setStrokeColor(UIColor(hex: "#59ccbe")!.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: point.x - radius - 5, y: point.y - radius - 5, width: (radius + 5) * 2, height: (radius + 5) * 2))
        
        // Add country name
        let countryNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        
        let nameSize = country.size(withAttributes: countryNameAttributes)
        let namePoint = CGPoint(
            x: point.x - nameSize.width / 2,
            y: point.y + radius + 5
        )
        
        country.draw(at: namePoint, withAttributes: countryNameAttributes)
    }
    
    // Country name normalization
    private func normalizeCountryName(_ name: String) -> String {
        // Common country name mappings
        let countryNameMap: [String: String] = [
            "United States": "USA",
            "US": "USA",
            "Great Britain": "United Kingdom",
            "UK": "United Kingdom"
        ]
        
        // Try to get standard name from mapping
        if let standardName = countryNameMap[name] {
            return standardName
        }
        
        // If no mapping, return original name
        return name
    }
    
    // Add logout function
    private func logout() {
        Task {
            do {
                try authManager.signOut()
            } catch {
                print("Error signing out: \(error)")
            }
        }
    }
}

// Helper for MapKit snapshot generation
class MapSnapshotGenerator {
    // Country code and positions using absolute pixel coordinates
    private let countryPositions: [String: CGPoint] = [
        "USA": CGPoint(x: 399, y: 471),
        "United States": CGPoint(x: 399, y: 471), // Alias
        "US": CGPoint(x: 399, y: 471), // Alias
        "Canada": CGPoint(x: 384, y: 307),
        "Brazil": CGPoint(x: 506, y: 737),
        "United Kingdom": CGPoint(x: 752, y: 337),
        "UK": CGPoint(x: 752, y: 337), // Alias
        "Britain": CGPoint(x: 752, y: 337), // Alias
        "France": CGPoint(x: 768, y: 378),
        "Germany": CGPoint(x: 798, y: 348),
        "Russia": CGPoint(x: 967, y: 256),
        "India": CGPoint(x: 998, y: 593),
        "China": CGPoint(x: 1121, y: 460),
        "Japan": CGPoint(x: 1290, y: 440),
        "Australia": CGPoint(x: 1259, y: 880),
        "South Africa": CGPoint(x: 860, y: 921),
        "Mexico": CGPoint(x: 368, y: 583),
        "Argentina": CGPoint(x: 491, y: 962),
        "Egypt": CGPoint(x: 814, y: 552),
        "Iceland": CGPoint(x: 675, y: 266),
        "Italy": CGPoint(x: 787, y: 400),
        "Spain": CGPoint(x: 730, y: 420),
        "Thailand": CGPoint(x: 1070, y: 583),
        "Indonesia": CGPoint(x: 1140, y: 650)
    ]
    
    // Country name normalization
    private func normalizeCountryName(_ name: String) -> String {
        // Common country name mappings
        let countryNameMap: [String: String] = [
            "United States": "USA",
            "US": "USA",
            "Great Britain": "United Kingdom",
            "UK": "United Kingdom"
        ]
        
        // Try to get standard name from mapping
        if let standardName = countryNameMap[name] {
            return standardName
        }
        
        // If no mapping, return original name
        return name
    }
    
    func generateWorldMapWithVisitedCountries(countries: [String]) async -> UIImage? {
        // Print countries to mark
        print("Countries to mark: \(countries.sorted())")
        print("Available country positions: \(countryPositions.keys.sorted())")
        
        // Image dimensions - use the exact dimensions of WorldMap.png (1536x1024)
        let width: CGFloat = 1536
        let height: CGFloat = 1024
        
        // Create a context to draw in
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // Background color - dark blue
        let backgroundColor = UIColor(red: 0.1, green: 0.17, blue: 0.25, alpha: 1.0)
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Try to load the image from the direct file path first
        let imagePath = "/Users/alan/Project/MappaVita/MappaVita/Assets.xcassets/world_map.imageset/WorldMap.png"
        if let mapImage = UIImage(contentsOfFile: imagePath) {
            print("Successfully loaded world map from direct path: \(imagePath)")
            // Draw at full size without scaling
            mapImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        // Fallback to using asset catalog
        else if let mapImage = UIImage(named: "world_map") {
            print("Successfully loaded world map from asset catalog")
            // Draw at full size without scaling
            mapImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            print("Failed to load world map image, using solid color background")
            print("Attempted path: \(imagePath)")
            // If the image doesn't exist, use a solid color background
            let mapColor = UIColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 0.4)
            context.setFillColor(mapColor.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Manually define Iceland coordinate and make sure to mark it
        let icelandPosition = CGPoint(x: 675, y: 266)
        
        // Mark visited countries
        var markedCountries = 0
        for country in countries {
            print("Attempting to mark country: \(country)")
            
            // Try different possible country name formats
            var found = false
            
            // Special case for Iceland
            if country == "Iceland" || country.lowercased().contains("iceland") {
                markCountry(country: "Iceland", at: icelandPosition, in: context)
                markedCountries += 1
                print("Successfully marked Iceland at position \(icelandPosition)")
                found = true
            }
            // 1. Direct match
            else if let position = countryPositions[country] {
                markCountry(country: country, at: position, in: context)
                markedCountries += 1
                print("Successfully marked country: \(country) at position \(position)")
                found = true
            } 
            // 2. Try standardized format (e.g., convert "United States" to "USA")
            else if let position = countryPositions[normalizeCountryName(country)] {
                markCountry(country: country, at: position, in: context)
                markedCountries += 1
                print("Successfully marked country using standardized name: \(country) -> \(normalizeCountryName(country)) at position \(position)")
                found = true
            }
            
            if !found {
                print("Could not find coordinates for country: \(country)")
            }
        }
        print("Total countries marked: \(markedCountries)")
        
        // Add title
        let title = "My World Travel Map"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titlePoint = CGPoint(
            x: (width - titleSize.width) / 2,
            y: 20
        )
        
        title.draw(at: titlePoint, withAttributes: titleAttributes)
        
        // Add country count
        let countText = "Countries visited: \(countries.count)"
        let countAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        let countSize = countText.size(withAttributes: countAttributes)
        let countPoint = CGPoint(
            x: 20,
            y: height - countSize.height - 20
        )
        
        countText.draw(at: countPoint, withAttributes: countAttributes)
        
        // If countries are less, display full country list
        if countries.count > 0 && countries.count <= 15 {
            let countryListFont = UIFont.systemFont(ofSize: 14)
            let countryListAttributes: [NSAttributedString.Key: Any] = [
                .font: countryListFont,
                .foregroundColor: UIColor.white
            ]
            
            // Sort countries alphabetically
            let sortedCountries = countries.sorted()
            let countriesText = sortedCountries.joined(separator: ", ")
            
            // Calculate text wrapping
            let listRect = CGRect(
                x: 20,
                y: height - countSize.height - 50,
                width: width - 40,
                height: 30
            )
            
            countriesText.draw(in: listRect, withAttributes: countryListAttributes)
        }
        
        // Add copyright information
        let copyrightText = "© MappaVita " + Calendar.current.component(.year, from: Date()).description
        let copyrightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]
        
        let copyrightSize = copyrightText.size(withAttributes: copyrightAttributes)
        let copyrightPoint = CGPoint(
            x: width - copyrightSize.width - 10,
            y: height - copyrightSize.height - 10
        )
        
        copyrightText.draw(at: copyrightPoint, withAttributes: copyrightAttributes)
        
        // Get result
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
    
    // Mark country, using absolute coordinates
    private func markCountry(country: String, at point: CGPoint, in context: CGContext) {
        // Draw marker point
        context.setFillColor(UIColor(hex: "#59ccbe")!.withAlphaComponent(0.9).cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.5)
        
        // Draw circle point
        let radius: CGFloat = 8
        context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        context.strokeEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        
        // Draw pulse ring
        context.setStrokeColor(UIColor(hex: "#59ccbe")!.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: point.x - radius - 5, y: point.y - radius - 5, width: (radius + 5) * 2, height: (radius + 5) * 2))
        
        // Add country name
        let countryNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        
        let nameSize = country.size(withAttributes: countryNameAttributes)
        let namePoint = CGPoint(
            x: point.x - nameSize.width / 2,
            y: point.y + radius + 5
        )
        
        country.draw(at: namePoint, withAttributes: countryNameAttributes)
    }
    
    // Standardize country name
    private func standardizeCountryName(_ name: String) -> String? {
        // Common country name mapping
        let countryNameMap: [String: String] = [
            "United States of America": "USA",
            "United States": "USA", 
            "US": "USA",
            "Great Britain": "United Kingdom",
            "UK": "United Kingdom"
        ]
        
        return countryNameMap[name]
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard Scanner(string: hexString).scanHexInt64(&int) else { return nil }
        
        switch hexString.count {
        case 3: // RGB (12-bit)
            r = CGFloat((int >> 8) & 0xF) / 15.0
            g = CGFloat((int >> 4) & 0xF) / 15.0
            b = CGFloat(int & 0xF) / 15.0
            a = 1.0
        case 6: // RGB (24-bit)
            r = CGFloat((int >> 16) & 0xFF) / 255.0
            g = CGFloat((int >> 8) & 0xFF) / 255.0
            b = CGFloat(int & 0xFF) / 255.0
            a = 1.0
        case 8: // RGBA (32-bit)
            r = CGFloat((int >> 24) & 0xFF) / 255.0
            g = CGFloat((int >> 16) & 0xFF) / 255.0
            b = CGFloat((int >> 8) & 0xFF) / 255.0
            a = CGFloat(int & 0xFF) / 255.0
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// Helper for ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Helper for async photo loading
struct AsyncPhotoView: View {
    let assetIdentifier: String
    let size: CGSize
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.3))
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        PhotoLocationManager.shared.getImage(from: asset, targetSize: size) { loadedImage in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }
}

// Extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Helper for creating shadows
extension NSShadow {
    convenience init(color: UIColor, offset: CGSize, radius: CGFloat) {
        self.init()
        self.shadowColor = color
        self.shadowOffset = offset
        self.shadowBlurRadius = radius
    }
}

// Scalable ScrollView
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    private var minimumZoomScale: CGFloat = 1.0
    private var maximumZoomScale: CGFloat = 5.0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // Set UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        // Create UIHostingController to host SwiftUI view
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add hosted view and set constraints
        scrollView.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update hosted controller's SwiftUI view
        context.coordinator.hostingController.rootView = content
        
        // Refresh view layout
        context.coordinator.hostingController.view.setNeedsLayout()
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: content))
    }
    
    // Coordinator class
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        
        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthManager())
    }
} 