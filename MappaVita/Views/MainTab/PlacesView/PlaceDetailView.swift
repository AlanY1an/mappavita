import SwiftUI
import MapKit
import CoreLocation

struct PlaceDetailView: View {
    @StateObject private var viewModel: PlaceDetailViewModel
    @State private var showMemories = false
    @State private var showAddMemorySheet = false
    @State private var memoryTitle = ""
    @State private var memoryText = ""
    @State private var isStarred = false
    @ObservedObject private var memoryStore = MemoryStore.shared
    @Environment(\.dismiss) private var dismiss
    
    init(place: Place) {
        _viewModel = StateObject(wrappedValue: PlaceDetailViewModel(place: place))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Top place info card
                VStack(alignment: .leading, spacing: 8) {
                    // Place photo or map
                    if viewModel.hasPhotoAsset, let image = viewModel.placeImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        // Show static map
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: viewModel.place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))))
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Image(systemName: placeTypeIcon)
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(placeTypeColor))
                                .shadow(radius: 3)
                        )
                    }
                    
                    // Place name and category
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.place.name)
                            .font(.title2)
                            .bold()
                        
                        if viewModel.hasCategory, let category = viewModel.place.category {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.secondary)
                                Text(category)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    if let description = viewModel.place.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 5)
                
                // Place details
                VStack(alignment: .leading, spacing: 20) {
                    // Visit information section
                    Section(header: headerView(title: "Visit Information", systemImage: "mappin.and.ellipse")) {
                        infoRow(
                            title: "Visit Time",
                            value: viewModel.formattedVisitDate,
                            systemImage: "calendar"
                        )
                        
                        if let duration = viewModel.place.stayDuration {
                            infoRow(
                                title: "Stay Duration",
                                value: formatDuration(duration),
                                systemImage: "clock.fill"
                            )
                        }
                        
                        infoRow(
                            title: "Coordinates",
                            value: viewModel.formattedCoordinates,
                            systemImage: "location.circle.fill"
                        )
                        
                        if viewModel.hasAddress, let address = viewModel.place.address {
                            infoRow(
                                title: "Address",
                                value: address,
                                systemImage: "building.2.fill"
                            )
                        }
                    }
                    
                    // Place type information
                    Section(header: headerView(title: "Place Type", systemImage: "info.circle")) {
                        if viewModel.place.photoAssetIdentifier != nil {
                            infoRow(
                                title: "Source",
                                value: "Imported from Photo Library",
                                systemImage: "photo.fill"
                            )
                        } else if let type = viewModel.place.placeType, type == "location" {
                            if viewModel.place.name.contains("Auto") {
                                infoRow(
                                    title: "Source",
                                    value: "Automatically recorded location",
                                    systemImage: "location.fill.viewfinder"
                                )
                            } else {
                                infoRow(
                                    title: "Source",
                                    value: "Manually marked location",
                                    systemImage: "pin.fill"
                                )
                            }
                        } else {
                            infoRow(
                                title: "Source",
                                value: "User created place",
                                systemImage: "person.fill"
                            )
                        }
                    }
                    
                    // Memories list section
                    let memories = memoryStore.getMemoriesForPlace(placeId: viewModel.place.id)
                    if !memories.isEmpty {
                        Section(header: 
                            HStack {
                                headerView(title: "Memories", systemImage: "brain")
                                Spacer()
                                Button(action: {
                                    showMemories.toggle()
                                }) {
                                    Text(showMemories ? "Collapse" : "Expand")
                                        .font(.subheadline)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        ) {
                            if showMemories {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(memories) { memory in
                                        MemoryRowView(memory: memory)
                                    }
                                }
                            } else {
                                Text("This place has \(memories.count) memories")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            showAddMemorySheet = true
                        }) {
                            Label("Add Memory", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            viewModel.openInMaps()
                        }) {
                            Label("Open in Maps", systemImage: "map")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top, 16)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 5)
            }
            .padding()
        }
        .navigationTitle("Place Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showAddMemorySheet) {
            addMemoryView
        }
    }
    
    // Custom header view
    private func headerView(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
        }
        .padding(.bottom, 8)
    }
    
    // Info row view
    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Add memory view
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
                        resetMemoryForm()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMemory()
                    }
                    .disabled(memoryTitle.isEmpty || memoryText.isEmpty)
                }
            }
        }
    }
    
    // Reset memory form
    private func resetMemoryForm() {
        memoryTitle = ""
        memoryText = ""
        isStarred = false
        showAddMemorySheet = false
    }
    
    // Save memory
    private func saveMemory() {
        // Create memory and get the return value
        let memory = memoryStore.createMemory(
            placeId: viewModel.place.id,
            title: memoryTitle,
            text: memoryText,
            isStarred: isStarred
        )
        
        // Send notification to update Memories view
        if memory != nil {
            NotificationCenter.default.post(
                name: NSNotification.Name("MemoriesUpdated"),
                object: nil
            )
        }
        
        resetMemoryForm()
    }
    
    // Format duration
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours) hours \(minutes) minutes"
        } else if minutes > 0 {
            return "\(minutes) minutes \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
    
    // Based on place type, return the appropriate icon
    private var placeTypeIcon: String {
        if viewModel.place.photoAssetIdentifier != nil {
            return "photo.fill"
        } else if viewModel.place.placeType == "location" {
            return viewModel.place.name.contains("Auto") ? "location.fill" : "pin.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
    
    // Based on place type, return the appropriate color
    private var placeTypeColor: Color {
        if viewModel.place.photoAssetIdentifier != nil {
            return .purple
        } else if viewModel.place.placeType == "location" {
            return viewModel.place.name.contains("Auto") ? .blue : .orange
        } else {
            return .red
        }
    }
}

// Memory row view
struct MemoryRowView: View {
    let memory: Memory
    @State private var showEditMemory = false
    @State private var showMemoryDetail = false
    @State private var showDeleteAlert = false
    @ObservedObject private var memoryStore = MemoryStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(memory.title)
                    .font(.headline)
                
                Spacer()
                
                if memory.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                
                Menu {
                    Button(action: {
                        showEditMemory = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
            
            if let description = memory.description {
                Text(description)
                    .font(.body)
                    .lineLimit(3)
            }
            
            Text(formatDate(memory.dateCreated))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            showMemoryDetail = true
        }
        .sheet(isPresented: $showEditMemory) {
            EditMemoryView(memory: memory, isPresented: $showEditMemory)
        }
        .sheet(isPresented: $showMemoryDetail) {
            MemoryDetailView(memory: memory)
        }
        .alert("Delete Memory", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                memoryStore.deleteMemory(memory)
            }
        } message: {
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// EditMemoryView component
struct EditMemoryView: View {
    let memory: Memory
    @Binding var isPresented: Bool
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var isStarred: Bool
    @ObservedObject private var memoryStore = MemoryStore.shared
    
    init(memory: Memory, isPresented: Binding<Bool>) {
        self.memory = memory
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: memory.title)
        self._editedDescription = State(initialValue: memory.description ?? "")
        self._isStarred = State(initialValue: memory.isStarred)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Memory")) {
                    TextField("Title", text: $editedTitle)
                    
                    TextEditor(text: $editedDescription)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if editedDescription.isEmpty {
                                    Text("Describe your experience...")
                                        .foregroundColor(.gray.opacity(0.7))
                                        .padding(.leading, 5)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                        
                    Toggle(isOn: $isStarred) {
                        Label("Star this memory", systemImage: "star")
                    }
                }
                
                if let placeId = memory.placeId {
                    Section(header: Text("Location")) {
                        let placeStore = PlaceStore.shared
                        if let place = placeStore.visitedPlaces.first(where: { $0.id == placeId }) {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                    .font(.headline)
                                
                                if let address = place.address {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMemory()
                    }
                    .disabled(editedTitle.isEmpty)
                }
            }
        }
    }
    
    private func saveMemory() {
        if let id = memory.id {
            let updatedMemory = Memory(
                id: id,
                title: editedTitle,
                description: editedDescription,
                dateCreated: memory.dateCreated,
                latitude: memory.latitude,
                longitude: memory.longitude,
                userId: memory.userId,
                placeId: memory.placeId,
                photoIds: memory.photoIds,
                tags: memory.tags,
                isStarred: isStarred
            )
            
            memoryStore.updateMemory(updatedMemory)
            isPresented = false
        }
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(place: Place(
            id: "test-id",
            name: "Test Place",
            latitude: 39.908823,
            longitude: 116.397470,
            visitDate: Date(),
            description: "This is a test place description",
            category: "Test Category",
            stayDuration: 3600
        ))
    }
}
