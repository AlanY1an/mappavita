import SwiftUI
import CoreLocation

struct PlacesListView: View {
    @StateObject private var viewModel: PlacesViewModel
    @State private var showingFilterSheet = false
    @State private var timer: Timer?
    
    init(mapViewModel: MapViewModel) {
        // Break down the complex initialization
        let initialViewModel = PlacesViewModel(mapViewModel: mapViewModel)
        _viewModel = StateObject(wrappedValue: initialViewModel)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Extract filter options to a separate view
                FilterOptionsView(viewModel: viewModel)
                
                // Extract search bar to a separate view
                SearchBarView(searchText: $viewModel.searchText, onSearchChange: {
                    viewModel.applyFilters()
                })
                
                // Extract place list to a separate view
                PlacesContentView(viewModel: viewModel)
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadPlaces()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .environmentObject(viewModel.mapViewModel)
            .environmentObject(viewModel)
        }
        .onAppear {
            // Load once first
            viewModel.loadPlaces()
            
            // Ensure timer is created on the main thread
            DispatchQueue.main.async {
                // Avoid creating duplicate timers
                if self.timer == nil {
                    // Start periodic refresh timer - more frequent updates (every 3 seconds)
                    self.timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                        self.viewModel.loadPlaces()
                    }
                    
                    // Ensure timer is added to the current run loop
                    if let activeTimer = self.timer {
                        RunLoop.current.add(activeTimer, forMode: .common)
                    }
                }
            }
            
            // Also refresh when notification is received
            setupNotifications()
        }
        .onDisappear {
            // Invalidate timer when view disappears
            timer?.invalidate()
            timer = nil
            
            // Remove notification observer
            removeNotifications()
        }
    }
    
    // Setup notification observers for real-time updates
    private func setupNotifications() {
        // First remove existing observers to avoid duplicates
        removeNotifications()
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlacesUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            // Immediately reload data when places are updated
            self.viewModel.loadPlaces()
        }
    }
    
    // Remove notification observers
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("PlacesUpdated"),
            object: nil
        )
    }
}

// MARK: - Subviews

// Filter options view
struct FilterOptionsView: View {
    @ObservedObject var viewModel: PlacesViewModel
    
    var body: some View {
        VStack {
            // Filter options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PlacesViewModel.FilterOption.allCases) { option in
                        FilterChip(
                            title: option.rawValue,
                            isSelected: viewModel.selectedFilterOption == option
                        )
                        .onTapGesture {
                            withAnimation {
                                viewModel.selectedFilterOption = option
                                viewModel.applyFilters()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // Stay duration slider
            if viewModel.selectedFilterOption == .significant {
                VStack(alignment: .leading) {
                    Text("Minimum stay time: \(Int(viewModel.minimumStayMinutes)) minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("5 min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(
                            value: $viewModel.minimumStayMinutes,
                            in: 5...60,
                            step: 5
                        )
                        .onChange(of: viewModel.minimumStayMinutes) { _ in
                            viewModel.updateMinimumStayDuration(viewModel.minimumStayMinutes)
                        }
                        
                        Text("60 min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}

// Search bar view
struct SearchBarView: View {
    @Binding var searchText: String
    var onSearchChange: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search places", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: searchText) { _ in
                    onSearchChange()
                }
        }
        .padding(.horizontal)
    }
}

// Places content view
struct PlacesContentView: View {
    @ObservedObject var viewModel: PlacesViewModel
    @State private var refreshID = UUID()
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding()
        } else if viewModel.filteredPlaces.isEmpty {
            ContentUnavailableView(
                "No places found matching your criteria",
                systemImage: "location.slash",
                description: Text("Try changing your filters or search terms")
            )
            .padding()
        } else {
            List {
                ForEach(viewModel.filteredPlaces) { place in
                    NavigationLink {
                        PlaceDetailView(place: place)
                    } label: {
                        PlaceRow(place: place)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .id(place.id) // Use place.id instead of including rapidly changing duration
                }
                .onDelete { indexSet in
                    let placesToDelete = indexSet.map { viewModel.filteredPlaces[$0] }
                    for place in placesToDelete {
                        viewModel.deletePlace(place)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                viewModel.loadPlaces()
                refreshID = UUID() // Force the entire list to re-render
            }
            .id(refreshID) // Use refreshID to force refresh
            .environmentObject(viewModel.mapViewModel)
            .environmentObject(viewModel)
        }
    }
}

// Filter chip component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                ? Color.accentColor
                : Color.gray.opacity(0.2)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// Place row component
struct PlaceRow: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var placesViewModel: PlacesViewModel
    
    let place: Place
    @State private var refreshTrigger = UUID()
    @State private var timer: Timer? = nil
    @State private var localStayDuration: TimeInterval = 0
    @State private var observers: [NSObjectProtocol] = []
    @State private var displayDuration: String = "0s"
    
    // Helper function to format a duration in a human-readable format
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    // Check if current row represents the current location
    private var isCurrentLocation: Bool {
        return place.id == mapViewModel.currentLocationID
    }
    
    // Simplified method to calculate current duration
    private func calculateCurrentDuration() -> TimeInterval {
        // Read data directly from CoreData, no more real-time calculation
        return place.stayDuration ?? 0
    }
    
    // Update displayed duration
    private func updateDisplayDuration() {
        // Get latest data directly from place
        let duration = place.stayDuration ?? 0
        localStayDuration = duration
        displayDuration = formattedDuration(duration)
        
        // Generate new refresh trigger to force view update
        refreshTrigger = UUID()
        
        let isCurrent = isCurrentLocation
        print("🔄 Update \(place.name) display time: \(displayDuration), current location: \(isCurrent)")
    }
    
    // Force refresh place data
    private func refreshPlaceData() {
        // Refresh data source first
        placesViewModel.loadPlaces()
        
        // Get the latest place object from the refreshed data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Try to find the corresponding latest place object from the data source
            if let updatedPlace = self.placesViewModel.places.first(where: { $0.id == self.place.id }) {
                // We can't directly update self.place since it's a constant
                // But we can update display data
                self.localStayDuration = updatedPlace.stayDuration ?? 0
                self.displayDuration = self.formattedDuration(updatedPlace.stayDuration ?? 0)
                
                // Force UI refresh
                self.refreshTrigger = UUID()
                
                print("✅ Got latest data for \(updatedPlace.name): \(self.displayDuration)")
            } else {
                print("❌ Could not find latest data for \(self.place.id)")
                // Fallback to updating display with existing data
                self.updateDisplayDuration()
            }
        }
    }
    
    // Set up notification listeners
    private func setupNotifications() {
        print("🔄 Setting up notification listeners for \(place.name)")
        
        // Ensure previous observers are removed
        removeNotifications()
        
        // Listen for location update notifications - this is the main update source
        let placeUpdatedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlaceUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            print("📣 \(self.place.name) received location update notification")
            // Force get latest data and refresh display when notification received
            self.refreshPlaceData()
        }
        
        // Listen for app foreground resume notification
        let appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 App returned to foreground, refreshing \(self.place.name)")
            // Immediately refresh data display when app resumes
            self.refreshPlaceData()
        }
        
        // Save observers
        observers = [placeUpdatedObserver, appActiveObserver]
    }
    
    // Set up timer - no longer needed, rely on notification updates instead
    private func setupTimer() {
        // Stop existing timer
        timer?.invalidate()
        timer = nil
        
        // No longer need timer, all updates triggered by notifications
        print("🔄 \(place.name) will update via notifications, timer no longer used")
    }
    
    // Remove notification observers
    private func removeNotifications() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
    }
    
    // Return different icons based on place type
    private var iconImage: Image {
        if place.photoAssetIdentifier != nil {
            return Image(systemName: "photo")
        } else if place.placeType == "location" && place.name.contains("Auto") {
            return Image(systemName: "location.fill")
        } else if place.placeType == "location" {
            return Image(systemName: "pin.fill")
        } else {
            return Image(systemName: "mappin.circle.fill")
        }
    }
    
    // Return different background colors based on place type
    private var iconBackgroundColor: Color {
        if place.photoAssetIdentifier != nil {
            return Color.purple
        } else if place.placeType == "location" && place.name.contains("Auto") {
            return Color.blue
        } else if place.placeType == "location" {
            return Color.orange
        } else if localStayDuration >= (placesViewModel.minimumStayMinutes * 60) {
            return Color.green
        } else {
            return Color.gray
        }
    }
    
    var body: some View {
        HStack {
            // Place icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 50, height: 50)
                
                iconImage
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
            
            // Place information
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    // Use pre-calculated text to display duration
                    Text("Duration: \(displayDuration)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Show current location update status
                    if isCurrentLocation {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // More prominently display current location status (green dot)
            if isCurrentLocation {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(.vertical, 8)
        .id(refreshTrigger) // Use UUID to force view refresh
        .onAppear {
            print("🔵 PlaceRow appeared for: \(place.name)")
            
            // Initialize display time immediately
            updateDisplayDuration()
            
            // Only set up notification listeners, timer no longer needed
            DispatchQueue.main.async {
                self.setupNotifications()
            }
        }
        .onDisappear {
            print("🔴 PlaceRow disappeared for: \(place.name)")
            timer?.invalidate()
            timer = nil
            removeNotifications()
        }
    }
}

#Preview {
    PlacesListView(mapViewModel: MapViewModel())
}



