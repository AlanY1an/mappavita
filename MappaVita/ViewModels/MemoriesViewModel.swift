import Foundation
import UIKit
import CoreData
import SwiftUI
import Photos

// Sort order
enum SortOrder {
    case newestFirst
    case oldestFirst
}

// Filter type
enum FilterType {
    case all
    case photosOnly
    case memoriesOnly
}

// Timeline item type
enum TimelineItemType {
    case photo
    case memory
}

// Timeline item model
class TimelineItem: Identifiable {
    var id: String
    var title: String
    var date: Date
    var place: Place?
    var memory: Memory?
    var image: UIImage?
    var type: TimelineItemType
    var isStarred: Bool = false
    var hasMemory: Bool = false
    
    init(id: String, title: String, date: Date, type: TimelineItemType, place: Place? = nil, memory: Memory? = nil, image: UIImage? = nil, isStarred: Bool = false, hasMemory: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.type = type
        self.place = place
        self.memory = memory
        self.image = image
        self.isStarred = isStarred
        self.hasMemory = hasMemory
    }
}

@MainActor
class MemoriesViewModel: ObservableObject {
    @Published var timelineItems: [TimelineItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var groupedByDate: [Date: [TimelineItem]] = [:]
    
    @Published var sortOrder: SortOrder = .newestFirst {
        didSet {
            sortTimelineItems()
        }
    }
    
    @Published var filter: FilterType = .all {
        didSet {
            applyFilter()
        }
    }
    
    private var allTimelineItems: [TimelineItem] = []
    private var filteredByTimeItems: [TimelineItem] = []
    private var currentTimeFilter: TimeFilter = .all
    private var showingStarredOnly: Bool = false
    private let placeStore = PlaceStore.shared
    private let memoryStore = MemoryStore.shared
    private let photoLocationManager = PhotoLocationManager.shared
    
    // Load all timeline data
    func loadTimelineData() async {
        isLoading = true
        allTimelineItems = []
        
        // 1. Load all places (extracted from photos)
        await loadPlacesData()
        
        // 2. Load all memories
        await loadMemoriesData()
        
        // 3. Check if each photo has associated memories
        checkPhotosWithMemories()
        
        // 4. Remove duplicates
        removeDuplicates()
        
        // 5. Apply filters and sorting
        filteredByTimeItems = allTimelineItems
        applyTimeFilter(currentTimeFilter)
        
        isLoading = false
    }
    
    // Load places data
    private func loadPlacesData() async {
        // Get all places
        let places = placeStore.visitedPlaces
        
        // Create timeline items for each place
        for place in places {
            // If this place has a photo, load it
            if let photoID = place.photoAssetIdentifier {
                let image = await loadImage(from: photoID)
                
                // Check if this place has memories
                let hasAssociatedMemories = memoryStore.memories.contains { $0.placeId == place.id }
                
                let item = TimelineItem(
                    id: place.id,
                    title: place.name,
                    date: place.visitDate,
                    type: .photo,
                    place: place,
                    image: image,
                    hasMemory: hasAssociatedMemories
                )
                
                if !allTimelineItems.contains(where: { $0.id == item.id }) {
                    allTimelineItems.append(item)
                }
            }
        }
    }
    
    // Load memories data
    private func loadMemoriesData() async {
        // Get all memories
        let memories = memoryStore.memories
        
        // Create timeline items for each memory
        for memory in memories {
            // Ensure memory has placeId
            guard let placeId = memory.placeId else { continue }
            
            // Find associated place
            let associatedPlace = placeStore.visitedPlaces.first(where: { $0.id == placeId })
            
            // Use place photo or default image
            var image: UIImage?
            if let place = associatedPlace, let photoID = place.photoAssetIdentifier {
                image = await loadImage(from: photoID)
            }
            
            let item = TimelineItem(
                id: memory.id ?? UUID().uuidString,
                title: memory.title,
                date: memory.dateCreated,
                type: .memory,
                place: associatedPlace,
                memory: memory,
                image: image,
                isStarred: memory.isStarred
            )
            
            if !allTimelineItems.contains(where: { $0.id == item.id }) {
                allTimelineItems.append(item)
            }
        }
    }
    
    // Check if photos have memories
    private func checkPhotosWithMemories() {
        let photosWithMemories = allTimelineItems.filter { item in
            if item.type == .photo, let place = item.place {
                return memoryStore.memories.contains { memory in
                    guard let memoryPlaceId = memory.placeId else { return false }
                    return memoryPlaceId == place.id
                }
            }
            return false
        }
        
        // Update hasMemory property
        for photoItem in photosWithMemories {
            if let index = allTimelineItems.firstIndex(where: { $0.id == photoItem.id }) {
                allTimelineItems[index].hasMemory = true
            }
        }
    }
    
    // Load photo image
    private func loadImage(from assetIdentifier: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            // Get PHAsset
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            
            // Request image
            photoLocationManager.getImage(from: asset, targetSize: CGSize(width: 400, height: 400)) { image in
                continuation.resume(returning: image)
            }
        }
    }
    
    // Apply time filter
    func applyTimeFilter(_ filter: TimeFilter) {
        currentTimeFilter = filter
        
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .all:
            filteredByTimeItems = allTimelineItems
        case .lastWeek:
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            filteredByTimeItems = allTimelineItems.filter { $0.date >= oneWeekAgo }
        case .lastMonth:
            let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            filteredByTimeItems = allTimelineItems.filter { $0.date >= oneMonthAgo }
        case .lastSixMonths:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
            filteredByTimeItems = allTimelineItems.filter { $0.date >= sixMonthsAgo }
        case .lastYear:
            let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            filteredByTimeItems = allTimelineItems.filter { $0.date >= oneYearAgo }
        }
        
        // Reapply starred and type filters
        applyFilter()
    }
    
    // Filter starred items only
    func filterStarredOnly(_ starred: Bool) {
        showingStarredOnly = starred
        applyFilter()
    }
    
    // Toggle starred status
    func toggleStarred(_ item: TimelineItem) {
        if item.hasMemory, let memory = item.memory {
            // Ensure memory has a valid id
            guard let memoryId = memory.id else { return }
            
            // Update Memory object
            memoryStore.toggleStarred(memory)
            
            // Update TimelineItem
            if let index = allTimelineItems.firstIndex(where: { $0.id == item.id }) {
                allTimelineItems[index].isStarred.toggle()
            }
            
            if let index = timelineItems.firstIndex(where: { $0.id == item.id }) {
                timelineItems[index].isStarred.toggle()
            }
            
            // If currently showing starred items, need to reapply filter
            if showingStarredOnly {
                applyFilter()
            } else {
                // Regroup
                groupItemsByDate()
            }
        }
    }
    
    // Apply filter
    private func applyFilter() {
        // First apply type filter
        switch filter {
        case .all:
            timelineItems = filteredByTimeItems
        case .photosOnly:
            timelineItems = filteredByTimeItems.filter { $0.type == .photo }
        case .memoriesOnly:
            // Include standalone memory items and photos with memories
            timelineItems = filteredByTimeItems.filter { 
                $0.type == .memory || ($0.type == .photo && $0.hasMemory) 
            }
        }
        
        // Then apply starred filter
        if showingStarredOnly {
            timelineItems = timelineItems.filter { 
                // If it's a photo with memory, filter by memory's starred status
                if $0.type == .photo && $0.hasMemory, let memory = $0.memory {
                    return memory.isStarred
                }
                // If it's a standalone memory, use its starred status directly
                else if $0.type == .memory {
                    return $0.isStarred
                }
                return false
            }
        }
        
        sortTimelineItems()
    }
    
    // Sort timeline items
    private func sortTimelineItems() {
        switch sortOrder {
        case .newestFirst:
            timelineItems.sort { $0.date > $1.date }
        case .oldestFirst:
            timelineItems.sort { $0.date < $1.date }
        }
        
        groupItemsByDate()
    }
    
    // Group items by date
    private func groupItemsByDate() {
        // Group by date (without time), but maintain order within groups
        groupedByDate = Dictionary(grouping: timelineItems) { item in
            // Remove time part, keep only date
            Calendar.current.startOfDay(for: item.date)
        }
    }
    
    // Create new memory
    func createMemory(for place: Place, title: String, text: String, isStarred: Bool = false) {
        // Use MemoryStore to create memory
        let memory = memoryStore.createMemory(placeId: place.id, title: title, text: text, isStarred: isStarred)
        
        // If memory was successfully created, update current model directly without reloading all data
        if let memory = memory {
            // Create a new TimelineItem
            let newItem = TimelineItem(
                id: memory.id ?? UUID().uuidString,
                title: memory.title,
                date: memory.dateCreated,
                type: .memory,
                place: place,
                memory: memory,
                image: nil,  // Can load asynchronously later
                isStarred: isStarred,
                hasMemory: true
            )
            
            // If there's a photo, try to associate an image
            if let photoID = place.photoAssetIdentifier {
                Task {
                    // Load image asynchronously
                    let image = await loadImage(from: photoID)
                    // Update image
                    if let index = allTimelineItems.firstIndex(where: { $0.id == newItem.id }) {
                        allTimelineItems[index].image = image
                    }
                    // If this memory is in current display list, update it too
                    if let index = timelineItems.firstIndex(where: { $0.id == newItem.id }) {
                        timelineItems[index].image = image
                    }
                }
            }
            
            // Update internal data model
            allTimelineItems.append(newItem)
            
            // Update photo item related to this place
            if let existingPhotoIndex = allTimelineItems.firstIndex(where: { 
                $0.type == .photo && $0.place?.id == place.id 
            }) {
                allTimelineItems[existingPhotoIndex].hasMemory = true
                // Associate first memory (if this is the first memory)
                if allTimelineItems[existingPhotoIndex].memory == nil {
                    allTimelineItems[existingPhotoIndex].memory = memory
                }
            }
            
            // Reapply filters and sorting
            filteredByTimeItems = allTimelineItems
            applyTimeFilter(currentTimeFilter)
        } else {
            // If creation failed, completely reload data
            Task {
                await loadTimelineData()
            }
        }
    }
    
    // Delete timeline item
    func deleteItem(_ item: TimelineItem) {
        switch item.type {
        case .memory:
            if let memory = item.memory, let memoryId = memory.id {
                memoryStore.deleteMemory(memory)
            }
        case .photo:
            // If photo deletion functionality is needed, add it here
            break
        }
        
        // Refresh data
        Task {
            await loadTimelineData()
        }
    }
    
    // Remove duplicates (resolve issue of photos and memories showing simultaneously)
    private func removeDuplicates() {
        // Collect all place IDs with memories
        var placeIdsWithMemories = Set<String>()
        var placeToMemoriesMap: [String: [Memory]] = [:]
        
        // 1. Find all place IDs with memories and related memories
        for memory in memoryStore.memories {
            // Ensure placeId exists
            guard let placeId = memory.placeId else { continue }
            
            placeIdsWithMemories.insert(placeId)
            
            // Collect all memories for each place
            if placeToMemoriesMap[placeId] == nil {
                placeToMemoriesMap[placeId] = []
            }
            placeToMemoriesMap[placeId]?.append(memory)
        }
        
        // 2. Update photo items with memories
        for i in 0..<allTimelineItems.count {
            if allTimelineItems[i].type == .photo, 
               let placeId = allTimelineItems[i].place?.id,
               placeIdsWithMemories.contains(placeId) {
                // Mark photo as having associated memories
                allTimelineItems[i].hasMemory = true
                
                // If there are associated memories, use memory's title
                if let memories = placeToMemoriesMap[placeId], !memories.isEmpty {
                    let firstMemory = memories[0]  // Use first memory
                    allTimelineItems[i].memory = firstMemory
                    // Still retain original photo title, but mark as having memory
                }
            }
        }
        
        // 3. Process allTimelineItems to ensure all memories are included
        // Create a temporary array to store all items
        var processedItems: [TimelineItem] = []
        
        // First add all photo items
        for item in allTimelineItems where item.type == .photo {
            processedItems.append(item)
        }
        
        // Add all memory items (ensure we don't duplicate memories already associated with photos)
        let addedMemoryIds = Set(processedItems.compactMap { $0.memory?.id })
        
        for memory in memoryStore.memories {
            // Skip if this memory is already associated with a photo
            if let memoryId = memory.id, addedMemoryIds.contains(memoryId) {
                continue
            }
            
            // Find associated place
            let placeId = memory.placeId
            let associatedPlace = placeId != nil ? placeStore.visitedPlaces.first(where: { $0.id == placeId }) : nil
            
            // Use place's photo or default image
            var image: UIImage?
            if let place = associatedPlace, let photoID = place.photoAssetIdentifier {
                // Not using await here because we're no longer in an async context
                // Can use already loaded image or leave empty
                image = allTimelineItems.first(where: { $0.place?.id == placeId })?.image
            }
            
            // Create memory item
            let memoryItem = TimelineItem(
                id: memory.id ?? UUID().uuidString,
                title: memory.title,
                date: memory.dateCreated,
                type: .memory,
                place: associatedPlace,
                memory: memory,
                image: image,
                isStarred: memory.isStarred,
                hasMemory: true
            )
            
            processedItems.append(memoryItem)
        }
        
        // Apply filter logic
        if filter == .memoriesOnly {
            // If filter condition is memories only, only keep memory type and photos with memories
            allTimelineItems = processedItems.filter { $0.type == .memory || (
                $0.type == .photo && $0.hasMemory) }
        } else if filter == .photosOnly {
            // If filter condition is photos only, keep all photos
            allTimelineItems = processedItems.filter { $0.type == .photo }
        } else {
            // By default, keep all items
            allTimelineItems = processedItems
        }
    }
    
    // Apply sorting
    func applySorting() {
        sortTimelineItems()
    }
}
