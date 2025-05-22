import SwiftUI
import MapKit
import Photos

// Define a protocol to avoid ambiguity
protocol PhotoAssetAccessible {
    var photoAssetIdentifier: String? { get }
}

// Ensure PlaceAnnotation conforms to this protocol
extension PlaceAnnotation: PhotoAssetAccessible {}

struct MapView: View {
    @EnvironmentObject var viewModel: MapViewModel
    @State private var mapAnnotations: [PlaceAnnotation] = []
    @State private var memoryTitle = ""
    @State private var memoryText = ""
    @State private var isStarred = false
    
    // Track which sheet is currently showing
    @State private var activeSheet: ActiveSheet? = nil
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Use UIViewRepresentable for custom annotation views
            MapViewWithCustomAnnotations(
                position: $viewModel.position,
                selectedPlace: $viewModel.selectedPlace,
                selectedMemory: $viewModel.selectedMemory,
                places: viewModel.visitedPlaces,
                showPhotoAnnotations: viewModel.showPhotoAnnotations
            )
            .mapStyle(viewModel.showOnlyVisitedPlaces ? .standard : .hybrid)
            .ignoresSafeArea(edges: [.top, .leading, .trailing]) // Make map fill screen except bottom tab
            .onAppear {
                viewModel.requestLocationPermission()
                
                // Start monitoring location changes
                viewModel.startLocationMonitoring()
                
                // Add notification observers
                setupNotifications()
            }
            .onDisappear {
                // Remove notification observers but don't stop location monitoring
                removeNotifications()
            }
            
            VStack(spacing: 10) {
                // First button: Center to current location
                Button(action: {
                    viewModel.centerUserLocation()
                }) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                
                // Second button: Save current location
                Button(action: {
                    viewModel.saveCurrentLocation()
                }) {
                    Image(systemName: "pin.fill")
                        .font(.title2)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .overlay(
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .padding(8)
                        .opacity(viewModel.locationViewModel.locationManager.isMonitoringLocation ? 1 : 0)
                )
                
                // Auto location tracking indicator
                Text("Auto Record Location")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.8))
                    )
                    .shadow(radius: 2)
                    .opacity(viewModel.locationViewModel.locationManager.isMonitoringLocation ? 1 : 0)
                
                // Third button: Import places from photo library
                Button(action: {
                    viewModel.fetchPlacesFromPhotos()
                }) {
                    Image(systemName: "photo.fill")
                        .font(.title2)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                
                // Fourth button: Toggle photo annotations
                Button(action: {
                    viewModel.togglePhotoAnnotations()
                }) {
                    Image(systemName: viewModel.showPhotoAnnotations ? "eye.fill" : "eye.slash.fill")
                        .font(.title2)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
            
            if viewModel.isLoadingPlaces {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            }
        }
        .alert("Location Services Disabled", isPresented: $viewModel.showingLocationOffAlert) {
            Button("Settings", action: viewModel.openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location services in your device settings to use this feature.")
        }
        .alert("Photo Library Access Required", isPresented: $viewModel.showingPhotoPermissionAlert) {
            Button("Settings", action: viewModel.openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo library access in your device settings to import photos.")
        }
        // Use separate sheets for clearer state management
        .sheet(isPresented: $viewModel.showPlaceDetail) {
            if let place = viewModel.selectedPlace {
                MapPlaceDetailView(place: place, onAddMemory: {
                    // First save the current place, then close this sheet, then show add memory sheet
                    viewModel.savedPlace = place
                    viewModel.showPlaceDetail = false
                    activeSheet = .addMemory
                })
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $viewModel.showMemoryDetail, onDismiss: {
            viewModel.dismissMemoryDetail()
        }) {
            if let memory = viewModel.selectedMemory {
                MemoryDetailView(memory: memory)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addMemory:
                addMemoryView
            }
        }
    }
    
    // View for adding a new memory
    private var addMemoryView: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Memory")) {
                    TextField("Title", text: $memoryTitle)
                    TextEditor(text: $memoryText)
                        .frame(height: 150)
                    
                    Toggle(isOn: $isStarred) {
                        Label("Star this memory", systemImage: "star")
                    }
                }
            }
            .navigationTitle("Add Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        memoryTitle = ""
                        memoryText = ""
                        isStarred = false
                        activeSheet = nil
                        
                        // If there's a saved place, reopen place details
                        if let savedPlace = viewModel.savedPlace {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.placeSelected(savedPlace)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let savedPlace = viewModel.savedPlace {
                            // Create the memory
                            viewModel.createMemory(
                                for: savedPlace,
                                title: memoryTitle,
                                text: memoryText,
                                isStarred: isStarred
                            )
                            
                            // Reset fields
                            memoryTitle = ""
                            memoryText = ""
                            isStarred = false
                            activeSheet = nil
                            
                            // Reopen place details
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.placeSelected(savedPlace)
                            }
                        }
                    }
                    .disabled(memoryTitle.isEmpty || memoryText.isEmpty)
                }
            }
        }
    }
    
    // Set up notification observers
    private func setupNotifications() {
        // Monitor detail button clicks
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SelectedPlaceChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let place = notification.object as? Place {
                Task { @MainActor in
                    viewModel.placeSelected(place)
                }
            }
        }
        
        // Monitor annotation selection events
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AnnotationSelected"),
            object: nil,
            queue: .main
        ) { notification in
            if let place = notification.object as? Place {
                // Only update camera position, don't show details
                Task { @MainActor in
                    viewModel.centerOnPlace(place)
                }
            }
        }
        
        // Listen for memory selection
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemorySelected"),
            object: nil,
            queue: .main
        ) { notification in
            if let memory = notification.object as? Memory {
                Task { @MainActor in
                    viewModel.memorySelected(memory)
                }
            }
        }
    }
    
    // Remove notification observers
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SelectedPlaceChanged"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("AnnotationSelected"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("MemorySelected"),
            object: nil
        )
    }
}

// Define possible sheet types
enum ActiveSheet: Identifiable {
    case addMemory
    
    var id: Int {
        switch self {
        case .addMemory: return 2
        }
    }
}

// UIViewRepresentable to use custom MKMapView with photo annotations
// Moved to MapViewWithCustomAnnotations.swift

struct MapPlaceDetailView: View {
    @StateObject private var viewModel: PlaceDetailViewModel
    @State private var showMemories = false
    @ObservedObject private var memoryStore = MemoryStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var onAddMemory: () -> Void
    
    init(place: Place, onAddMemory: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PlaceDetailViewModel(place: place))
        self.onAddMemory = onAddMemory
    }
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.hasPhotoAsset, let image = viewModel.placeImage {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.place.name)
                            .font(.title2)
                            .bold()
                        
                        if viewModel.hasAddress, let address = viewModel.place.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if viewModel.hasCategory, let category = viewModel.place.category {
                            Label(category, systemImage: "tag.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Visit Information") {
                    Label("Visited on \(viewModel.formattedVisitDate)", systemImage: "calendar")
                    
                    Label("Location: \(viewModel.formattedCoordinates)", systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                    
                    Button("Open in Maps") {
                        viewModel.openInMaps()
                    }
                }
                
                // Show memories for this place
                let memories = memoryStore.getMemoriesForPlace(placeId: viewModel.place.id)
                if !memories.isEmpty {
                    Section("Memories") {
                        ForEach(memories) { memory in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(memory.title)
                                        .font(.headline)
                                    
                                    Text(memory.dateCreated, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if memory.isStarred {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Show memory detail
                                viewModel.memorySelected(memory)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        // First record the current selectedPlace to avoid it being cleared by dismiss()
                        onAddMemory()
                        dismiss()
                    }) {
                        Label("Add Memory", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(MapViewModel())
}

