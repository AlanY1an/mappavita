import SwiftUI
import CoreData

struct CoreDataDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var memories: [MemoryEntity] = []
    @State private var places: [PlaceEntity] = []
    @State private var selectedTab = 0
    private let coreDataManager = CoreDataManager.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Entity", selection: $selectedTab) {
                    Text("Memories").tag(0)
                    Text("Places").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    memoryList
                } else {
                    placesList
                }
            }
            .navigationTitle("Data Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Data", action: fetchData)
                        Button("Delete All Memories", role: .destructive, action: deleteAllMemories)
                        Button("Delete All Places", role: .destructive, action: deleteAllPlaces)
                        Button("Delete All Data", role: .destructive, action: deleteAllData)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear(perform: fetchData)
        }
    }
    
    private var memoryList: some View {
        List {
            ForEach(memories) { memory in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(memory.title ?? "No Title")
                            .font(.headline)
                        
                        Spacer()
                        
                        if memory.isStarred {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    if let text = memory.text {
                        Text(text)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let date = memory.dateCreated {
                        Text("\(date, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("ID: \(memory.id ?? "No ID")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 5)
            }
            .onDelete(perform: deleteMemories)
        }
    }
    
    private var placesList: some View {
        List {
            ForEach(places) { place in
                VStack(alignment: .leading, spacing: 5) {
                    Text(place.name ?? "No Name")
                        .font(.headline)
                    
                    if let address = place.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let date = place.visitDate {
                        Text("Visit Date: \(date, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Coordinates: \(place.latitude), \(place.longitude)")
                        .font(.caption)
                    
                    Text("ID: \(place.id ?? "No ID")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 5)
            }
            .onDelete(perform: deletePlaces)
        }
    }
    
    private func fetchData() {
        let context = coreDataManager.viewContext
        

        let memoryRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
        memoryRequest.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
        
    
        let placeRequest: NSFetchRequest<PlaceEntity> = PlaceEntity.fetchRequest()
        placeRequest.sortDescriptors = [NSSortDescriptor(key: "visitDate", ascending: false)]
        
        do {
            self.memories = try context.fetch(memoryRequest)
            self.places = try context.fetch(placeRequest)
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }
    
    private func deleteMemories(at offsets: IndexSet) {
        let context = coreDataManager.viewContext
        
        for index in offsets {
            let memory = memories[index]
            context.delete(memory)
        }
        
        do {
            try context.save()
            fetchData()
        } catch {
            print("Failed to delete memory: \(error)")
        }
    }
    
    private func deletePlaces(at offsets: IndexSet) {
        let context = coreDataManager.viewContext
        
        for index in offsets {
            let place = places[index]
            context.delete(place)
        }
        
        do {
            try context.save()
            fetchData()
        } catch {
            print("Failed to delete place: \(error)")
        }
    }
    
    private func deleteAllMemories() {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MemoryEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            fetchData()
        } catch {
            print("Failed to delete all memories: \(error)")
        }
    }
    
    private func deleteAllPlaces() {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PlaceEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            fetchData()
        } catch {
            print("Failed to delete all places: \(error)")
        }
    }
    
    private func deleteAllData() {
        deleteAllMemories()
        deleteAllPlaces()
    }
} 