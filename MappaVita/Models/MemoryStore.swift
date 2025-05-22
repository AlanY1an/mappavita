import Foundation
import SwiftUI
import Combine

class MemoryStore: ObservableObject {
    static let shared = MemoryStore()
    
    @Published private(set) var memories: [Memory] = []
    private let coreDataManager = CoreDataManager.shared
    
    private init() {
        fetchMemories()
        
        // Listen for data update notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoriesUpdated),
            name: NSNotification.Name("MemoriesUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleMemoriesUpdated() {
        fetchMemories()
    }
    
    func fetchMemories() {
        memories = coreDataManager.fetchAllMemories()
    }
    
    func createMemory(placeId: String, title: String, text: String, isStarred: Bool = false) -> Memory? {
        if let newMemory = coreDataManager.createMemory(placeId: placeId, title: title, text: text, isStarred: isStarred) {
            memories.append(newMemory)
            return newMemory
        }
        return nil
    }
    
    func updateMemory(_ memory: Memory) {
        if coreDataManager.updateMemory(memory) {
            // Update memory cache
            if let index = memories.firstIndex(where: { $0.id == memory.id }) {
                memories[index] = memory
            }
        }
    }
    
    func toggleStarred(_ memory: Memory) {
        if let updatedMemory = coreDataManager.toggleStarred(memory) {
            // Update memory cache
            if let index = memories.firstIndex(where: { $0.id == memory.id }) {
                memories[index] = updatedMemory
            }
        }
    }
    
    func deleteMemory(_ memory: Memory) {
        if coreDataManager.deleteMemory(memory) {
       
            if let index = memories.firstIndex(where: { $0.id == memory.id }) {
                memories.remove(at: index)
            }
        }
    }
    
    func getMemoriesForPlace(placeId: String) -> [Memory] {
        return memories.filter { $0.placeId == placeId }
    }
    
    func getStarredMemories() -> [Memory] {
        return memories.filter { $0.isStarred }
    }
} 