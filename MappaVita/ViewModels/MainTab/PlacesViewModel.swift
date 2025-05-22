import SwiftUI
import CoreLocation

@MainActor
class PlacesViewModel: ObservableObject {
    @Published var places: [Place] = []
    @Published var filteredPlaces: [Place] = []
    @Published var isLoading: Bool = false
    @Published var selectedFilterOption = FilterOption.significant
    @Published var searchText: String = ""
    @Published var minimumStayMinutes: Double = 10 // Default 10 minutes for significant stay
    
    private let placeStore = PlaceStore.shared
    let mapViewModel: MapViewModel // Make this public for PlaceRow to access
    
    // Filter options
    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All Places"
        case significant = "Important Places (>10 min)"
        case photos = "Photo Places"
        case manualLocation = "Manual Locations"
        case autoLocation = "Auto Locations"
        
        var id: String { self.rawValue }
    }
    
    init(mapViewModel: MapViewModel) {
        self.mapViewModel = mapViewModel
        
        // Set place time threshold
        mapViewModel.setStayDurationThreshold(minimumStayMinutes)
        
        loadPlaces()
        
        // Listen for place updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlacesUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadPlaces()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Load places
    func loadPlaces() {
        isLoading = true
        
        places = placeStore.visitedPlaces
        applyFilters()
        
        isLoading = false
    }
    
    // Apply filters
    func applyFilters() {
        var result = places
        
        // Apply stay duration filter
        switch selectedFilterOption {
        case .all:
            // No filtering
            break
        case .significant:
            // Stay time exceeds threshold
            result = result.filter { place in
                if let duration = place.stayDuration {
                    return duration >= (minimumStayMinutes * 60)
                }
                return false
            }
        case .photos:
            // Only show photo places
            result = result.filter { $0.photoAssetIdentifier != nil }
        case .manualLocation:
            // Only show manually marked locations
            result = result.filter { $0.placeType == "location" && $0.name.contains("My Location") }
        case .autoLocation:
            // Only show automatically recorded locations
            result = result.filter { $0.placeType == "location" && $0.name.contains("Auto Location") }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            result = result.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                (place.description ?? "").localizedCaseInsensitiveContains(searchText) ||
                (place.category ?? "").localizedCaseInsensitiveContains(searchText) ||
                (place.address ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort: by visit date in descending order
        result.sort { $0.visitDate > $1.visitDate }
        
        filteredPlaces = result
    }
    
    // Update minimum stay duration threshold
    func updateMinimumStayDuration(_ minutes: Double) {
        minimumStayMinutes = minutes
        mapViewModel.setStayDurationThreshold(minutes)
        applyFilters()
    }
    
    // Get formatted stay duration for a place
    func formattedStayDuration(for place: Place) -> String {
        guard let duration = place.stayDuration else {
            return "Unknown"
        }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours) hrs \(minutes) min"
        } else if minutes > 0 {
            return "\(minutes) min \(seconds) sec"
        } else {
            return "\(seconds) sec"
        }
    }
    
    // Get relative visit date text compared to current time
    func relativeVisitDate(for place: Place) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "en_US")
        return formatter.localizedString(for: place.visitDate, relativeTo: Date())
    }
    
    // Select a place
    func selectPlace(_ place: Place) {
        mapViewModel.placeSelected(place)
    }
    
    // Delete a place
    func deletePlace(_ place: Place) {
        placeStore.deletePlace(place)
        loadPlaces()
    }
    
    // Check if a place is the current location
    func isCurrentLocation(_ place: Place) -> Bool {
        return mapViewModel.currentLocationID == place.id
    }
    
    // Get the entry time for current location
    func getEntryTimeForCurrentLocation() -> Date? {
        return mapViewModel.locationEntryTime
    }
    
    // Get real-time duration for a place
    func getRealTimeDuration(for place: Place) -> TimeInterval? {
        // If this is the current location, calculate real-time duration
        if isCurrentLocation(place), let entryTime = getEntryTimeForCurrentLocation() {
            return Date().timeIntervalSince(entryTime)
        }
        // Otherwise just return stored duration
        return place.stayDuration
    }
} 