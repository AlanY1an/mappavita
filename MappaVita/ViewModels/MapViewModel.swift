import Foundation
import MapKit
import SwiftUI
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var position: MapCameraPosition = .automatic
    @Published var selectedPlace: Place?
    @Published var selectedMemory: Memory?
    @Published var showPlaceDetail = false
    @Published var showMemoryDetail = false
    @Published var isLoadingPlaces = false
    @Published var showOnlyVisitedPlaces = false
    @Published var showPhotoAnnotations = true 
    @Published private(set) var places: [Place] = []
    @Published private(set) var totalMemories: Int = 0
    @Published var showingPhotoPermissionAlert = false
    
 
    private var importedPlaceIds = Set<String>()
    
 
    var currentLocationID: String? 
    var locationEntryTime: Date? 
    private var stayDurationThreshold: TimeInterval = 600 
    private var significantStayPlaces: Set<String> = [] 
    
   
    var savedPlace: Place?
    var memoryToShow: Memory?
    
    private let placeStore = PlaceStore.shared
    private let memoryStore = MemoryStore.shared
    private let photoLibraryManager = PhotoLocationManager.shared
    private let coreDataManager = CoreDataManager.shared
    let locationViewModel = LocationViewModel()
    
    private var updateTimer: Timer?
    

    private var applicationWillResignActiveTime: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    var visitedPlaces: [Place] {
        placeStore.visitedPlaces
    }
    
    var significantPlaces: [Place] {
       
        return visitedPlaces.filter { place in
            if let duration = place.stayDuration {
                return duration >= stayDurationThreshold
            }
            return false
        }
    }
    
    var memories: [Memory] {
        memoryStore.memories
    }
    
    var showingLocationOffAlert: Bool {
        get { locationViewModel.showLocationAlert }
        set { locationViewModel.showLocationAlert = newValue }
    }
    
    var authorizationStatus: CLAuthorizationStatus {
        locationViewModel.authorizationStatus
    }
    
    init() {
        // Request permissions only, don't automatically locate current position
        locationViewModel.requestLocationPermission()
        
        // Set up location change monitoring
        setupLocationChangeMonitoring()
        
        // Fetch memories when initialized
        fetchMemories()
        places = visitedPlaces
        
        // Initialize import records to avoid duplicate imports
        for place in visitedPlaces {
            if place.photoAssetIdentifier != nil {
                importedPlaceIds.insert(place.id)
            }
        }
        
        // Load significant stay places
        loadSignificantStayPlaces()
        
        // Record initial position on start
        recordInitialPosition()
      
        Task {
       
            try? await Task.sleep(nanoseconds: 3_000_000_000)
      
            await mergeSimilarPlaces()
     
            await restoreLocationTracking()
        }
        
  
        setupAppStateObservers()
    }
    

    private func setupAppStateObservers() {
  
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        print("✅ App state observers set up")
    }
    

    @objc private func applicationWillResignActive() {
        print("📱 App is about to enter background, recording current time")
        
    
        applicationWillResignActiveTime = Date()
        
       
        if let currentLocationID = currentLocationID, let entryTime = locationEntryTime {
            updateCurrentLocationStayDuration()
            print("⏱️ Updated stay duration before app entered background")
        }

        startBackgroundTask()
    }
 
    @objc private func applicationDidBecomeActive() {
        print("📱 App returned to foreground")
    
        endBackgroundTask()
    
        if let backgroundTime = applicationWillResignActiveTime,
           let currentLocationID = currentLocationID {
            
            let now = Date()
            let offlineDuration = now.timeIntervalSince(backgroundTime)
            
            print("⏱️ App offline time: \(formattedDuration(offlineDuration))")
            
       
            if let place = visitedPlaces.first(where: { $0.id == currentLocationID }) {
                // Get existing stay duration
                let existingDuration = place.stayDuration ?? 0
                // Add offline time
                let newTotalDuration = existingDuration + offlineDuration
                
    
                let updatedPlace = Place(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    visitDate: place.visitDate,
                    description: place.description,
                    photos: place.photos,
                    category: place.category,
                    address: place.address,
                    photoAssetIdentifier: place.photoAssetIdentifier,
                    memories: place.memories,
                    placeType: place.placeType,
                    stayDuration: newTotalDuration 
                )
                
             
                coreDataManager.savePlace(updatedPlace)
                
              
                locationEntryTime = now
                
                print("✅ Added offline time \(formattedDuration(offlineDuration)) to location: \(place.name)")
                print("   New total stay duration: \(formattedDuration(newTotalDuration))")
                
            
                placeStore.fetchPlaces()
            }
            
   
            applicationWillResignActiveTime = nil
        }
        
    
        if !locationViewModel.locationManager.isMonitoringLocation && 
           (locationViewModel.authorizationStatus == .authorizedWhenInUse || 
            locationViewModel.authorizationStatus == .authorizedAlways) {
       
            startLocationMonitoring()
            print("🔄 Restarted location monitoring after returning to foreground")
        }
        
     
        placeStore.fetchPlaces()
        postPlaceUpdatedNotification()
        
       
        if currentLocationID != nil {
            updateCurrentLocationStayDuration()
            print("🔄 Immediately updated current location stay time after app returned to foreground")
        }
    }
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        print("🔄 Started background task: \(backgroundTask)")
    }
    

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("🛑 Ended background task")
        }
    }
    
    // Record the initial position when app starts
    private func recordInitialPosition() {
        // Check if we have location permission and a valid location
        Task {
            // Give location services a moment to initialize
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if locationViewModel.authorizationStatus == .authorizedWhenInUse || 
               locationViewModel.authorizationStatus == .authorizedAlways {
                // Request a location update
                locationViewModel.centerOnUserLocation(with: nil, forceCenter: false)
                
                // Wait briefly for location to be available
                var attempts = 0
                while locationViewModel.lastLocation == nil && attempts < 5 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    attempts += 1
                }
                
                // If we have a location, handle it as the initial position
                if let location = locationViewModel.lastLocation {
                    await handleLocationChange(location: location, distance: 0)
                    print("📍 Initial position recorded")
                }
            }
        }
    }
    

    private func loadSignificantStayPlaces() {
        significantStayPlaces = Set(visitedPlaces
            .filter { place in place.stayDuration != nil && place.stayDuration! >= stayDurationThreshold }
            .map { $0.id }
        )
    }

    func setStayDurationThreshold(_ minutes: Double) {
        stayDurationThreshold = minutes * 60 
        print("🕒 Stay duration threshold set to: \(minutes) minutes")
    }
    

    private func setupLocationChangeMonitoring() {
        // Set callback for significant location changes
        locationViewModel.locationManager.onSignificantLocationChange = { [weak self] location, distance in
            guard let self = self else { return }
            Task {
                await self.handleLocationChange(location: location, distance: distance)
            }
        }
        
        // Start location monitoring
        startLocationMonitoring()
        
 
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let currentLocationID = self.currentLocationID, let entryTime = self.locationEntryTime {
          
                self.updateCurrentLocationStayDuration()
                print("🕒 Timer update: Location \(currentLocationID) - Updating CoreData data")
            } else {
                print("⚠️ No current location being tracked")
                // Try to initialize with current location if available
                if let location = self.locationViewModel.lastLocation {
                    Task {
                        await self.handleLocationChange(location: location, distance: 0)
                        print("🔄 Initializing location tracking with current location")
                    }
                }
            }
        }
        
        // Immediately record initial stay time for current location
        Task {
            if let location = locationViewModel.lastLocation {
                await handleLocationChange(location: location, distance: 0)
                print("📍 Initial position setup with location")
            } else {
                print("⚠️ No initial location available")
            }
        }
    }
    
    // Handle location changes, calculate stay time and record new locations
    private func handleLocationChange(location: CLLocation, distance: Double) async {
        let currentTime = Date()
        print("📍 Processing location change: \(location.coordinate.latitude), \(location.coordinate.longitude), distance: \(distance) meters")
        
        // Find nearby places within 50 meters
        let nearbyPlaces = findNearbyPlaces(to: location, withinMeters: 50)
        
        // Found nearby places
        if let nearestPlace = nearbyPlaces.first {
            // Get nearby place ID
            let placeID = nearestPlace.id
            
            // User is still near the same known location
            if currentLocationID == placeID {
                // User is still in the same place, just update stay time
                print("📍 User is still at the same location: \(nearestPlace.name)")
                updateCurrentLocationStayDuration()
                return
            }
            
            // User moved to a new location
            print("📍 User moved to a new location: \(nearestPlace.name)")
            
            // First process stay duration for previous location
            if let oldID = currentLocationID, let entryTime = locationEntryTime {
                await saveStayDurationForPlace(withID: oldID, entryTime: entryTime, currentTime: currentTime)
            }
            
            // Update current location status
            currentLocationID = placeID
            locationEntryTime = currentTime
            print("📍 Started tracking location: \(nearestPlace.name), time: \(currentTime)")
            
            // Refresh place list
            placeStore.fetchPlaces()
            postPlaceUpdatedNotification()
        } else {
            // User is not near any known location
            
            // If previously at a location, calculate and save stay duration
            if let oldID = currentLocationID, let entryTime = locationEntryTime {
                await saveStayDurationForPlace(withID: oldID, entryTime: entryTime, currentTime: currentTime)
                
                // Reset location tracking
                currentLocationID = nil
                locationEntryTime = nil
                
                // Refresh place list
                placeStore.fetchPlaces()
                postPlaceUpdatedNotification()
            }
            
            // Automatically create new location record
            await createNewLocationPoint(at: location, time: currentTime, isFirstPosition: false)
        }
    }
    
    // Save stay duration for a place
    private func saveStayDurationForPlace(withID placeID: String, entryTime: Date, currentTime: Date) async {
        // Get place object
        if let place = visitedPlaces.first(where: { $0.id == placeID }) {
            // Calculate stay duration for this session
            let sessionDuration = currentTime.timeIntervalSince(entryTime)
            
            // Get existing stay duration and add to it
            let existingDuration = place.stayDuration ?? 0
            let totalDuration = existingDuration + sessionDuration
            
            // Create updated place object
            let updatedPlace = Place(
                id: place.id,
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                visitDate: place.visitDate,
                description: place.description,
                photos: place.photos,
                category: place.category,
                address: place.address,
                photoAssetIdentifier: place.photoAssetIdentifier,
                memories: place.memories,
                placeType: place.placeType,
                stayDuration: totalDuration // Combined total duration
            )
            
            // Save updated place
            coreDataManager.savePlace(updatedPlace)
            
            print("⏱️ Left location: \(place.name), existing time: \(formattedDuration(existingDuration)), added time: \(formattedDuration(sessionDuration)), total time: \(formattedDuration(totalDuration))")
        }
    }
    
    // Create a new location point
    private func createNewLocationPoint(at location: CLLocation, time: Date, isFirstPosition: Bool) async {
        print("📱 Checking if location needs to be created: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Format coordinates for display
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let coordinateString = String(format: "%.6f, %.6f", latitude, longitude)
        
        // Find places within 50 meters
        let nearbyPlaces = findNearbyPlaces(to: location, withinMeters: 50)
        
        // If there are nearby places, use existing place and add time
        if let existingPlace = nearbyPlaces.first {
            print("📍 Found existing nearby location: \(existingPlace.name)")
            
            // Set as current location
            currentLocationID = existingPlace.id
            locationEntryTime = time
            
            print("✅ Using existing location and starting timer: \(existingPlace.name)")
            return
        }
        
        // No nearby locations found, create a new one
        print("📱 Creating new location point: \(coordinateString)")
        
        // Create a place from current location
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        // Use a consistent name for all automatically recorded locations
        let locationName = "Auto Location (\(dateFormatter.string(from: time)))"
        
        let locationID = UUID().uuidString
        
        let newPlace = Place(
            id: locationID,
            name: locationName,
            latitude: latitude,
            longitude: longitude,
            visitDate: time,
            description: "Automatically saved location at \(coordinateString)",
            category: "Location",
            placeType: "location",
            stayDuration: 0 // Initial stay duration is 0
        )
        
        // Save to CoreData
        coreDataManager.savePlace(newPlace)
        placeStore.fetchPlaces()
        
        // Update current position tracking
        currentLocationID = locationID
        locationEntryTime = time
        
        print("✅ New location created and saved: \(coordinateString)")
    }
    
    // Format stay duration into readable format
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // Find nearby places
    private func findNearbyPlaces(to location: CLLocation, withinMeters distance: Double) -> [Place] {
        return visitedPlaces.filter { place in
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return location.distance(from: placeLocation) <= distance
        }.sorted { place1, place2 in
            let loc1 = CLLocation(latitude: place1.latitude, longitude: place1.longitude)
            let loc2 = CLLocation(latitude: place2.latitude, longitude: place2.longitude)
            return location.distance(from: loc1) < location.distance(from: loc2)
        }
    }
    
    // Automatically save location changes (when location changes exceed threshold)
    private func autoSaveCurrentLocation(location: CLLocation, distance: Double) async {
        // This method has been replaced by createNewLocationPoint
        // Keeping this empty stub for now to avoid errors
        await createNewLocationPoint(at: location, time: Date(), isFirstPosition: false)
    }
    
    func requestLocationPermission() {
        // Only request permission, don't locate
        locationViewModel.requestLocationPermission()
    }
    
    func centerUserLocation() {
        // Explicitly requested to center on user location
        locationViewModel.centerOnUserLocation(with: Binding(
            get: { self.position },
            set: { self.position = $0 }
        ), forceCenter: true)
    }
    
    // Center map on a specific place
    func centerOnPlace(_ place: Place) {
        selectedPlace = place
        centerMapOnCoordinate(place.coordinate)
    }
    
    // Center map on a memory
    func centerOnMemory(_ memory: Memory) {
        Task {
            guard let placeId = memory.placeId else { return }
            
            if let place = visitedPlaces.first(where: { $0.id == placeId }) {
                await MainActor.run {
                    centerMapOnCoordinate(place.coordinate)
                }
            }
        }
    }
    
    func fetchPlacesFromPhotos() {
        isLoadingPlaces = true
        
        Task {
            do {
                // 1. Check photo library permissions
                let photoPermissionGranted = await withCheckedContinuation { continuation in
                    photoLibraryManager.checkPhotoLibraryPermission { hasPermission in
                        continuation.resume(returning: hasPermission)
                    }
                }
                
                if !photoPermissionGranted {
                    await MainActor.run {
                        isLoadingPlaces = false
                        showingPhotoPermissionAlert = true
                    }
                    return
                }
                
                // 2. Get photo locations and save to CoreData
                let photoPlaces = try await photoLibraryManager.fetchPhotoPlaces()
                
                await MainActor.run {
                    // Stricter duplicate checking: check both photoAssetIdentifier and physical location
                    let newPlaces = photoPlaces.filter { newPlace in
                        // If ID already imported, filter it out
                        if importedPlaceIds.contains(newPlace.id) {
                            return false
                        }
                        
                        // Check if already imported same photo asset
                        if let assetId = newPlace.photoAssetIdentifier, 
                           visitedPlaces.contains(where: { $0.photoAssetIdentifier == assetId }) {
                            return false
                        }
                        
                        // Check if there's already a place very close to this location
                        let isNearExistingPlace = visitedPlaces.contains { existingPlace in
                            // If it's the same place, skip
                            if existingPlace.id == newPlace.id {
                                return false
                            }
                            
                            // Calculate distance, if less than 100m, consider it the same place
                            let existingLocation = CLLocation(
                                latitude: existingPlace.latitude,
                                longitude: existingPlace.longitude
                            )
                            let newLocation = CLLocation(
                                latitude: newPlace.latitude,
                                longitude: newPlace.longitude
                            )
                            return existingLocation.distance(from: newLocation) < 100
                        }
                        
                        // Only return true if neither same photo ID nor nearby location
                        return !isNearExistingPlace
                    }
                    
                    if newPlaces.isEmpty {
                        // If no new places, end early
                        isLoadingPlaces = false
                        print("No new photo locations found")
                        return
                    }
                    
                    // Save to database and refresh local cache
                    for place in newPlaces {
                        coreDataManager.savePlace(place)
                        // Add to imported set
                        importedPlaceIds.insert(place.id)
                    }
                    
                    // Update view model state
                    placeStore.fetchPlaces()
                    self.places = placeStore.visitedPlaces
                    isLoadingPlaces = false
                    
                    // Update memory statistics
                    if totalMemories == 0 {
                        totalMemories = self.visitedPlaces.reduce(0) { $0 + $1.memories.count }
                    }
                    
                    print("Successfully imported \(newPlaces.count) new places")
                }
            } catch {
                print("Error fetching places: \(error)")
                await MainActor.run {
                    isLoadingPlaces = false
                }
            }
        }
    }
    
    func fetchMemories() {
        memoryStore.fetchMemories()
    }
    
    func toggleVisitedPlacesOnly() {
        showOnlyVisitedPlaces.toggle()
    }
    
    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    func placeSelected(_ place: Place?) {
        // Use main thread to update UI state
        DispatchQueue.main.async {
            self.selectedPlace = place
            self.savedPlace = place // Also save to savedPlace
            if place != nil {
                self.showPlaceDetail = true
            }
        }
    }
    
    func memorySelected(_ memory: Memory) {
        Task {
            guard let placeId = memory.placeId else { return }
            
            if let place = visitedPlaces.first(where: { $0.id == placeId }) {
                await MainActor.run {
                    self.memoryToShow = memory
                    self.selectedMemory = memory
                    self.selectedPlace = place
                    centerMapOnCoordinate(place.coordinate)
                }
            }
        }
    }
    
    func dismissPlaceDetail() {
        // Add a short delay to ensure state updates don't conflict
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedPlace = nil
            self.showPlaceDetail = false
            // Don't clear savedPlace as it may be needed after adding memory
        }
    }
    
    func dismissMemoryDetail() {
        // Add a short delay to ensure state updates don't conflict
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedMemory = nil
            self.showMemoryDetail = false
        }
    }
    
    // Create a new memory for a place
    func createMemory(for place: Place, title: String, text: String, isStarred: Bool = false) {
        memoryStore.createMemory(placeId: place.id, title: title, text: text, isStarred: isStarred)
        // Refresh memories
        fetchMemories()
    }
    
    // Convert center point to coordinate region
    private func centerMapOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self.position = .region(region)
    }
    
    func togglePhotoAnnotations() {
        showPhotoAnnotations.toggle()
    }
    
    // Save current location as a Place
    func saveCurrentLocation() {
        Task {
            // Request a single location update
            locationViewModel.centerOnUserLocation(with: nil)
            
            // Wait for location update (with timeout)
            var attempts = 0
            while locationViewModel.lastLocation == nil && attempts < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                attempts += 1
            }
            
            guard let location = locationViewModel.lastLocation else {
                print("⚠️ Failed to get current location for saving")
                return
            }
            
            // Use our new function but with a manual name
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            let coordinateString = String(format: "%.6f, %.6f", latitude, longitude)
            
            // Check if we already have a location place very close to this one
            let existingLocationNearby = visitedPlaces.contains { place in
                guard place.placeType == "location" else { return false }
                
                let existingLocation = CLLocation(
                    latitude: place.latitude,
                    longitude: place.longitude
                )
                return location.distance(from: existingLocation) < 50 // Within 50 meters
            }
            
            if existingLocationNearby {
                print("📍 A location place already exists near the current position")
                return
            }
            
            // Create a manual location
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            let locationName = "My Location (\(dateFormatter.string(from: Date())))"
            let locationID = UUID().uuidString
            
            let newPlace = Place(
                id: locationID,
                name: locationName,
                latitude: latitude,
                longitude: longitude,
                visitDate: Date(),
                description: "Manually saved location at \(coordinateString)",
                category: "Location",
                placeType: "location"
            )
            
            // Save to CoreData
            coreDataManager.savePlace(newPlace)
            placeStore.fetchPlaces()
            
            // Center map on the new location
            centerMapOnCoordinate(location.coordinate)
            
            // Update tracking variables
            currentLocationID = locationID
            locationEntryTime = Date()
            
            print("✅ Manual location saved: \(coordinateString)")
        }
    }
    
    // Start monitoring location changes
    func startLocationMonitoring(distanceThreshold: Double = 50.0) {
        locationViewModel.locationManager.monitoringDistance = distanceThreshold
        locationViewModel.locationManager.startMonitoringSignificantLocationChanges()
    }
    
    // Stop monitoring location changes
    func stopLocationMonitoring(resetState: Bool = true) {
        // Save current stay duration before stopping monitoring
        if let placeID = currentLocationID, let entryTime = locationEntryTime {
            // Get the current place
            if let place = visitedPlaces.first(where: { $0.id == placeID }) {
                // Calculate session stay duration
                let sessionDuration = Date().timeIntervalSince(entryTime)
                
                // Get existing stay duration and add to it
                let existingDuration = place.stayDuration ?? 0
                let totalDuration = existingDuration + sessionDuration
                
                // Create updated place with accumulated duration
                let updatedPlace = Place(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    visitDate: place.visitDate,
                    description: place.description,
                    photos: place.photos,
                    category: place.category,
                    address: place.address,
                    photoAssetIdentifier: place.photoAssetIdentifier,
                    memories: place.memories,
                    placeType: place.placeType,
                    stayDuration: totalDuration
                )
                
                // Save the updated place
                coreDataManager.savePlace(updatedPlace)
                placeStore.fetchPlaces()
                
                print("⏱️ Stopped monitoring at place: \(place.name), existing duration: \(formattedDuration(existingDuration)), added session: \(formattedDuration(sessionDuration)), total duration: \(formattedDuration(totalDuration))")
            }
        }
        
        locationViewModel.locationManager.stopMonitoringSignificantLocationChanges()
        
        // Stop timer
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Only reset tracking state if resetState is true
        if resetState {
            currentLocationID = nil
            locationEntryTime = nil
        }
    }
    
    // Set monitoring radius
    func setLocationMonitoringDistance(_ distance: Double) {
        locationViewModel.locationManager.monitoringDistance = distance
        print("📏 Location monitoring distance set to: \(distance) meters")
    }
    
    // For current location, update stay duration
    func updateCurrentLocationStayDuration() {
        if let currentLocationID = currentLocationID, let entryTime = locationEntryTime {
            let currentTime = Date()
            
            // Calculate time since last update
            let sessionDuration = currentTime.timeIntervalSince(entryTime)
            
            print("⏱️ Updating stay duration for location ID \(currentLocationID)")
            print("   Entry time: \(entryTime)")
            print("   Current time: \(currentTime)")
            print("   Session duration: \(formattedDuration(sessionDuration))")
            
            // Get the current place 
            if let place = visitedPlaces.first(where: { $0.id == currentLocationID }) {
                // Get existing stay duration
                let existingDuration = place.stayDuration ?? 0
                // Calculate total stay duration = existing stay time + current session time
                let totalDuration = existingDuration + sessionDuration
                
                // Create updated place with accumulated duration
                let updatedPlace = Place(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    visitDate: place.visitDate,
                    description: place.description,
                    photos: place.photos,
                    category: place.category,
                    address: place.address,
                    photoAssetIdentifier: place.photoAssetIdentifier,
                    memories: place.memories,
                    placeType: place.placeType,
                    stayDuration: totalDuration // Use accumulated total time
                )
                
                // Print before saving
                print("   Updating place: \(place.name)")
                print("   Existing duration: \(formattedDuration(existingDuration))")
                print("   Session duration: \(formattedDuration(sessionDuration))")
                print("   New total duration: \(formattedDuration(totalDuration))")
                
                // Save to CoreData
                coreDataManager.savePlace(updatedPlace)
                
                // Refresh place list
                placeStore.fetchPlaces()
                
                // Update entry time to current time to avoid calculating the same time period repeatedly
                locationEntryTime = currentTime
                
                // Force immediate UI refresh
                postPlaceUpdatedNotification()
                
                print("✅ Duration updated and persisted")
            } else {
                print("❌ Could not find place with ID \(currentLocationID) in visitedPlaces")
            }
        } else {
            print("❌ No current location or entry time available")
        }
    }
    
    // Helper method to post notifications when place data is updated
    private func postPlaceUpdatedNotification() {
        // Post both notifications for different listeners
        NotificationCenter.default.post(name: NSNotification.Name("PlacesUpdated"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("PlaceUpdated"), object: nil)
        print("📢 Posted place update notifications")
    }
    

    private func restoreLocationTracking() async {
        print("🔄 Try to restore location tracking...")
        
        if currentLocationID != nil {
            print("✓ There is already active location tracking, no need to restore")
            return
        }
        
        guard let location = locationViewModel.lastLocation else {
            print("⚠️ Unable to restore location tracking: Current location unknown")
            return
        }
        
        
        let nearbyPlaces = findNearbyPlaces(to: location, withinMeters: 50)
        
        if let nearestPlace = nearbyPlaces.first {
            print("✅ Found nearby place: \(nearestPlace.name)")
            currentLocationID = nearestPlace.id
            locationEntryTime = Date() // Use current time as new entry time
            print("✅ Restored location tracking: \(nearestPlace.name)")
            
            // Ensure location monitoring is started
            if !locationViewModel.locationManager.isMonitoringLocation {
                startLocationMonitoring()
            }
        } else {
            print("⚠️ No known places nearby, unable to restore tracking")
        }
    }
    
    // Merge similar locations - merge locations of the same type within 50 meters
    private func mergeSimilarPlaces() async {
        print("🔄 Checking and merging similar places...")
        
        // Get all location type places
        let locationPlaces = visitedPlaces.filter { $0.placeType == "location" }
        
        // For tracking processed locations
        var processedPlaceIDs = Set<String>()
        // For storing location IDs that need to be deleted
        var placesToDelete = Set<String>()
        
        for place in locationPlaces {
            // If this location has already been processed or marked for deletion, skip
            if processedPlaceIDs.contains(place.id) || placesToDelete.contains(place.id) {
                continue
            }
            
            // Mark this location as processed
            processedPlaceIDs.insert(place.id)
            
            // Find nearby similar locations
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let similarPlaces = locationPlaces.filter { otherPlace in
                // Exclude self and already processed locations
                guard otherPlace.id != place.id && !processedPlaceIDs.contains(otherPlace.id) else {
                    return false
                }
                
                // Check if distance is within 50 meters
                let otherLocation = CLLocation(latitude: otherPlace.latitude, longitude: otherPlace.longitude)
                return placeLocation.distance(from: otherLocation) < 50
            }
            
            // If similar locations found, merge them
            if !similarPlaces.isEmpty {
                print("📍 Found locations to merge: \(place.name) and \(similarPlaces.count) nearby locations")
                
                // Calculate total stay duration
                var totalDuration = place.stayDuration ?? 0
                for similarPlace in similarPlaces {
                    totalDuration += (similarPlace.stayDuration ?? 0)
                    
                    // Mark as processed and to be deleted
                    processedPlaceIDs.insert(similarPlace.id)
                    placesToDelete.insert(similarPlace.id)
                }
                
                // Update current location's duration
                let updatedPlace = Place(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    visitDate: place.visitDate,
                    description: place.description,
                    photos: place.photos,
                    category: place.category,
                    address: place.address,
                    photoAssetIdentifier: place.photoAssetIdentifier,
                    memories: place.memories,
                    placeType: place.placeType,
                    stayDuration: totalDuration // Combined total stay duration
                )
                
                // Save updated location
                coreDataManager.savePlace(updatedPlace)
                print("✅ Merge complete! Location \(place.name) now has total stay duration: \(formattedDuration(totalDuration))")
                
                // Delete similar locations
                for similarPlace in similarPlaces {
                    coreDataManager.deletePlace(withID: similarPlace.id)
                    print("🗑️ Deleted duplicate location: \(similarPlace.name)")
                }
            }
        }
        
        // If any locations were deleted, refresh place list
        if !placesToDelete.isEmpty {
            placeStore.fetchPlaces()
            print("🔄 Deleted \(placesToDelete.count) duplicate locations")
        } else {
            print("✅ No locations found that need to be merged")
        }
    }
}

