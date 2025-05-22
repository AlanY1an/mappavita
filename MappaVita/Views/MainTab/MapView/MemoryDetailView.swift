import SwiftUI

struct MemoryDetailView: View {
    let memory: Memory
    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var isStarred: Bool
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var memoryStore = MemoryStore.shared
    
    init(memory: Memory) {
        self.memory = memory
        _editedTitle = State(initialValue: memory.title)
        _editedDescription = State(initialValue: memory.description ?? "")
        _isStarred = State(initialValue: memory.isStarred)
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if isEditing {
                    TextField("Title", text: $editedTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editedDescription)
                        .frame(minHeight: 200)
                        .padding(.horizontal)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                        
                    Toggle(isOn: $isStarred) {
                        Label("Star this memory", systemImage: "star")
                    }
                    .padding(.horizontal)
                } else {
                    HStack {
                        Text(memory.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button {
                            memoryStore.toggleStarred(memory)
                            isStarred.toggle()
                        } label: {
                            Image(systemName: isStarred ? "star.fill" : "star")
                                .foregroundColor(isStarred ? .yellow : .gray)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                    
                    Text(memory.description ?? "")
                        .padding(.horizontal)
                }
                
                if !isEditing {
                    if let placeId = memory.placeId {
                        let placeStore = PlaceStore.shared
                        if let place = placeStore.visitedPlaces.first(where: { $0.id == placeId }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.body)
                                    
                                    Text(place.name)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top)
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    Text("Created on: \(formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Label(isEditing ? "Cancel Edit" : "Edit", systemImage: "pencil")
                        }
                        
                        if !isEditing {
                            Button(role: .destructive, action: {
                                showDeleteAlert = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        if isEditing {
                            Button(action: {
                                saveMemory()
                                isEditing = false
                            }) {
                                Label("Save", systemImage: "checkmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Memory", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    memoryStore.deleteMemory(memory)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this memory? This action cannot be undone.")
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: memory.dateCreated)
    }
    
    private func saveMemory() {
        // Update memory using the MemoryStore
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
        }
    }
}

#Preview {
    // Create a sample memory for preview
    let memory = Memory(
        id: UUID().uuidString,
        title: "Sample Memory",
        description: "This is a sample memory text for preview purposes.",
        dateCreated: Date(),
        latitude: 37.7749,
        longitude: -122.4194,
        userId: "user123",
        placeId: UUID().uuidString,
        isStarred: false
    )
    
    return MemoryDetailView(memory: memory)
} 
