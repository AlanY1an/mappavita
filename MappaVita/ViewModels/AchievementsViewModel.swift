import Foundation
import CoreLocation
import SwiftUI
import CoreData

// Achievement tiers
enum AchievementTier: Int, CaseIterable {
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4
    case diamond = 5
    
    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return Color(#colorLiteral(red: 0.7, green: 0.5, blue: 0.3, alpha: 1))
        case .silver: return Color(#colorLiteral(red: 0.7, green: 0.7, blue: 0.7, alpha: 1))
        case .gold: return Color(#colorLiteral(red: 1, green: 0.84, blue: 0, alpha: 1))
        case .platinum: return Color(#colorLiteral(red: 0.6, green: 0.8, blue: 0.9, alpha: 1))
        case .diamond: return Color(#colorLiteral(red: 0.6, green: 0.9, blue: 0.9, alpha: 1))
        }
    }
    
    var requiredCount: Int {
        switch self {
        case .bronze: return 5
        case .silver: return 10
        case .gold: return 25
        case .platinum: return 50
        case .diamond: return 100
        }
    }
}

// Helper extension to add functionality to Achievement
extension Achievement {
    var progress: Double {
        return min(Double(currentCount) / Double(requiredCount), 1.0)
    }
    
    var isCompleted: Bool {
        return isUnlocked || currentCount >= requiredCount
    }
    
    // Get color for the achievement based on progress
    func getColor() -> Color {
        if isCompleted {
            if let tier = AchievementTier(rawValue: min(5, requiredCount / 10 + 1)) {
                return tier.color
            }
            return .green
        }
        return .gray
    }
}

@MainActor
class AchievementsViewModel: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var totalAchievements: Int = 0
    @Published var completedAchievements: Int = 0
    @Published var totalPoints: Int = 0
    @Published var level: Int = 1
    @Published var isLoading: Bool = false
    
    // Public properties to expose country and city data
    @Published var countriesVisited: Set<String> = []
    @Published var citiesVisited: Set<String> = []
    @Published var countriesCount: Int = 0
    
    // Calculated stats from places data
    private var visitedPlacesCount: Int = 0
    private var visitedCountriesCount: Int = 0
    private var visitedStatesCount: Int = 0
    private var visitedCitiesCount: Int = 0
    private var totalTravelDistance: Double = 0
    private var totalStayDuration: TimeInterval = 0
    private var visitedCategoriesCount: Int = 0
    private var visitedPhotosCount: Int = 0
    private var memoriesCount: Int = 0
    
    // Set of unique places
    private var uniqueCountries = Set<String>()
    private var uniqueStates = Set<String>()
    private var uniqueCities = Set<String>()
    private var uniqueCategories = Set<String>()
    
    private let placeStore = PlaceStore.shared
    private let memoryStore = MemoryStore.shared
    private let geocoder = CLGeocoder()
    private let userId = UserDefaults.standard.string(forKey: "userId") ?? "default"
    private let coreDataManager = CoreDataManager.shared
    
    // Track when we last updated achievements to prevent constant recalculation
    private var lastUpdateTime: Date?
    private let updateInterval: TimeInterval = 300 // Update at most every 5 minutes
    
    init() {
        // Listen for updates to places
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlacesUpdated),
            name: NSNotification.Name("PlacesUpdated"),
            object: nil
        )
        
        // Listen for updates to memories
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoriesUpdated),
            name: NSNotification.Name("MemoriesUpdated"),
            object: nil
        )
        
        // Initial load
        Task {
            await loadAchievements()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePlacesUpdated() {
        Task {
            await loadAchievements()
        }
    }
    
    @objc private func handleMemoriesUpdated() {
        Task {
            await loadAchievements()
        }
    }
    
    func loadAchievements() async {
        isLoading = true
        
        // Check if we need to recalculate based on time interval
        if let lastUpdate = lastUpdateTime, 
           Date().timeIntervalSince(lastUpdate) < updateInterval {
            // Just load cached achievements from CoreData
            loadCachedAchievements()
            isLoading = false
            return
        }
        
        // Process places data to extract achievements information
        await processPlacesData()
        
        // Generate achievements based on processed data
        generateAchievements()
        
        // Calculate total achievements metrics
        calculateAchievementMetrics()
        
        // Save achievements to CoreData
        saveAchievementsToCoreData()
        
        // Update last update time
        lastUpdateTime = Date()
        
        isLoading = false
    }
    
    private func loadCachedAchievements() {
        // Implement loading achievements from CoreData
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "AchievementEntity")
        request.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            guard let achievementEntities = try coreDataManager.viewContext.fetch(request) as? [NSManagedObject] else {
                return
            }
            
            achievements = achievementEntities.compactMap { entity in
                guard let id = entity.value(forKey: "id") as? String,
                      let title = entity.value(forKey: "title") as? String,
                      let description = entity.value(forKey: "achievementDescription") as? String,
                      let icon = entity.value(forKey: "icon") as? String,
                      let requiredCount = entity.value(forKey: "requiredCount") as? Int,
                      let currentCount = entity.value(forKey: "currentCount") as? Int,
                      let typeString = entity.value(forKey: "type") as? String,
                      let type = AchievementType(rawValue: typeString),
                      let isUnlocked = entity.value(forKey: "isUnlocked") as? Bool else {
                    return nil
                }
                
                return Achievement(
                    id: id,
                    title: title,
                    description: description,
                    icon: icon,
                    dateUnlocked: entity.value(forKey: "dateUnlocked") as? Date,
                    isUnlocked: isUnlocked,
                    requiredCount: requiredCount,
                    currentCount: currentCount,
                    type: type,
                    userId: userId
                )
            }
            
            // Load metrics as well
            totalAchievements = achievements.count
            completedAchievements = achievements.filter { $0.isCompleted }.count
            totalPoints = calculateTotalPoints()
            level = max(1, totalPoints / 100 + 1)
            
        } catch {
            print("Failed to fetch cached achievements: \(error.localizedDescription)")
            
            // If loading fails, recalculate
            Task {
                await processPlacesData()
                generateAchievements()
                calculateAchievementMetrics()
            }
        }
    }
    
    private func saveAchievementsToCoreData() {
        // First delete existing achievements
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AchievementEntity")
        deleteRequest.predicate = NSPredicate(format: "userId == %@", userId)
        let deleteAll = NSBatchDeleteRequest(fetchRequest: deleteRequest)
        
        do {
            try coreDataManager.viewContext.execute(deleteAll)
            
            // Then save new achievements
            for achievement in achievements {
                let entity = NSEntityDescription.insertNewObject(
                    forEntityName: "AchievementEntity",
                    into: coreDataManager.viewContext
                )
                
                entity.setValue(achievement.id, forKey: "id")
                entity.setValue(achievement.title, forKey: "title")
                entity.setValue(achievement.description, forKey: "achievementDescription")
                entity.setValue(achievement.icon, forKey: "icon")
                entity.setValue(achievement.dateUnlocked, forKey: "dateUnlocked")
                entity.setValue(achievement.isUnlocked, forKey: "isUnlocked")
                entity.setValue(achievement.requiredCount, forKey: "requiredCount")
                entity.setValue(achievement.currentCount, forKey: "currentCount")
                entity.setValue(achievement.type.rawValue, forKey: "type")
                entity.setValue(userId, forKey: "userId")
            }
            
            coreDataManager.saveContext()
        } catch {
            print("Failed to save achievements to CoreData: \(error.localizedDescription)")
        }
    }
    
    private func calculateTotalPoints() -> Int {
        return achievements.reduce(0) { sum, achievement in
            if achievement.isCompleted {
                // Points formula: base points multiplied by requirement divided by 5
                return sum + (achievement.requiredCount / 5) * 10
            }
            return sum
        }
    }
    
    private func processPlacesData() async {
        // Reset counters and sets
        visitedPlacesCount = 0
        totalTravelDistance = 0
        totalStayDuration = 0
        visitedPhotosCount = 0
        uniqueCountries.removeAll()
        uniqueStates.removeAll()
        uniqueCities.removeAll()
        uniqueCategories.removeAll()
        
        let places = placeStore.visitedPlaces
        
        // Count total places
        visitedPlacesCount = places.count
        
        // Count places with photos
        visitedPhotosCount = places.filter { $0.photoAssetIdentifier != nil }.count
        
        // Count memories
        memoriesCount = memoryStore.memories.count
        
        // Process each place to extract location information
        for place in places {
            // Add category if available
            if let category = place.category, !category.isEmpty {
                uniqueCategories.insert(category)
            }
            
            // Add duration
            if let duration = place.stayDuration {
                totalStayDuration += duration
            }
            
            // If the place has an address, parse it to extract country, state, and city
            if let address = place.address {
                await parseAddressComponents(address)
            } else {
                // If address is not available, use reverse geocoding to get location info
                await reverseGeocode(latitude: place.latitude, longitude: place.longitude)
            }
            
            // Calculate distance between consecutive places (if applicable)
            // This is a simplified version; a more accurate implementation would order places by visit date
            if places.count > 1 {
                let index = places.firstIndex { $0.id == place.id } ?? 0
                if index > 0 {
                    let previousPlace = places[index - 1]
                    let distance = calculateDistance(
                        from: CLLocation(latitude: previousPlace.latitude, longitude: previousPlace.longitude),
                        to: CLLocation(latitude: place.latitude, longitude: place.longitude)
                    )
                    totalTravelDistance += distance
                }
            }
        }
        
        // Set counts from unique sets
        visitedCountriesCount = uniqueCountries.count
        visitedStatesCount = uniqueStates.count
        visitedCitiesCount = uniqueCities.count
        visitedCategoriesCount = uniqueCategories.count
        
        // Update the public properties
        print("Raw country list: \(uniqueCountries)")
        
        // Standardize country names
        var standardizedCountries = Set<String>()
        for country in uniqueCountries {
            let standardName = standardizeCountryName(country)
            print("Standardizing country name: \(country) -> \(standardName)")
            standardizedCountries.insert(standardName)
        }
        
        countriesVisited = standardizedCountries
        citiesVisited = uniqueCities
        countriesCount = standardizedCountries.count
        
        print("Processed country list: \(countriesVisited)")
    }
    
    private func parseAddressComponents(_ address: String) async {
        // Simple parsing by comma separation (for more accuracy, consider using MapKit or a geocoding service)
        let components = address.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        print("Parsing address: \(address), components: \(components)")
        
        if components.count >= 3 {
            // Typical address format: "Street, City, State Country"
            let city = components[components.count - 3]
            let state = components[components.count - 2]
            let country = components.last ?? ""
            
            if !city.isEmpty { uniqueCities.insert(city) }
            if !state.isEmpty { uniqueStates.insert(state) }
            if !country.isEmpty { 
                print("Found country (address parsing): \(country)")
                uniqueCountries.insert(country) 
            }
        } else if components.count == 2 {
            // "City, Country" format
            let city = components.first ?? ""
            let country = components.last ?? ""
            
            if !city.isEmpty { uniqueCities.insert(city) }
            if !country.isEmpty { 
                print("Found country (address parsing): \(country)")
                uniqueCountries.insert(country) 
            }
        } else if components.count == 1 && !components[0].isEmpty {
            // Just one component, assume it's a country
            print("Found country (address parsing single item): \(components[0])")
            uniqueCountries.insert(components[0])
        }
    }
    
    private func reverseGeocode(latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                if let country = placemark.country, !country.isEmpty {
                    print("Found country (geocoding): \(country)")
                    uniqueCountries.insert(country)
                }
                
                if let state = placemark.administrativeArea, !state.isEmpty {
                    uniqueStates.insert(state)
                }
                
                if let city = placemark.locality, !city.isEmpty {
                    uniqueCities.insert(city)
                }
            }
        } catch {
            print("Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
    
    private func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to) / 1000 // Convert to kilometers
    }
    
    private func generateAchievements() {
        var newAchievements: [Achievement] = []
        
        // Generate place count achievements
        for tier in AchievementTier.allCases {
            let achievement = Achievement(
                id: "places_\(tier.rawValue)",
                title: "\(tier.name) Explorer",
                description: "Visit \(tier.requiredCount) different places",
                icon: "map",
                dateUnlocked: nil,
                isUnlocked: visitedPlacesCount >= tier.requiredCount,
                requiredCount: tier.requiredCount,
                currentCount: visitedPlacesCount,
                type: .places,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Generate photos achievements
        for tier in AchievementTier.allCases {
            let requiredCount = max(2, tier.requiredCount / 3) // Scale down the requirement for photos
            let achievement = Achievement(
                id: "photos_\(tier.rawValue)",
                title: "\(tier.name) Photographer",
                description: "Collect \(requiredCount) place photos",
                icon: "photo",
                dateUnlocked: nil,
                isUnlocked: visitedPhotosCount >= requiredCount,
                requiredCount: requiredCount,
                currentCount: visitedPhotosCount,
                type: .photos,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Generate memories achievements
        for tier in AchievementTier.allCases {
            let requiredCount = max(1, tier.requiredCount / 4) // Scale down the requirement for memories
            let achievement = Achievement(
                id: "memories_\(tier.rawValue)",
                title: "\(tier.name) Storyteller",
                description: "Create \(requiredCount) memories",
                icon: "book",
                dateUnlocked: nil,
                isUnlocked: memoriesCount >= requiredCount,
                requiredCount: requiredCount,
                currentCount: memoriesCount,
                type: .memories,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Generate country achievements
        for tier in AchievementTier.allCases {
            let requiredCount = max(1, tier.requiredCount / 5) // Scale down the requirement for countries
            let achievement = Achievement(
                id: "countries_\(tier.rawValue)",
                title: "\(tier.name) Globetrotter",
                description: "Visit \(requiredCount) different countries",
                icon: "globe",
                dateUnlocked: nil,
                isUnlocked: visitedCountriesCount >= requiredCount,
                requiredCount: requiredCount,
                currentCount: visitedCountriesCount,
                type: .countries,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Generate city achievements
        for tier in AchievementTier.allCases {
            let requiredCount = max(2, tier.requiredCount / 2) // Scale down the requirement for cities
            let achievement = Achievement(
                id: "cities_\(tier.rawValue)",
                title: "\(tier.name) Urban Explorer",
                description: "Visit \(requiredCount) different cities",
                icon: "building",
                dateUnlocked: nil,
                isUnlocked: visitedCitiesCount >= requiredCount,
                requiredCount: requiredCount,
                currentCount: visitedCitiesCount,
                type: .cities,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Generate distance achievements
        let distanceThresholds = [100, 500, 1000, 5000, 10000] // in kilometers
        let distanceTitles = ["Local Traveler", "Road Tripper", "Continental Explorer", "Global Adventurer", "World Circumnavigator"]
        
        for (index, threshold) in distanceThresholds.enumerated() {
            let tierIndex = min(index, AchievementTier.allCases.count - 1)
            let tier = AchievementTier.allCases[tierIndex]
            
            let achievement = Achievement(
                id: "distance_\(tier.rawValue)",
                title: distanceTitles[index],
                description: "Travel over \(threshold) kilometers",
                icon: "figure.walk",
                dateUnlocked: nil,
                isUnlocked: Int(totalTravelDistance) >= threshold,
                requiredCount: threshold,
                currentCount: Int(totalTravelDistance),
                type: .distance,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Generate streak achievements (placeholder)
        for tier in AchievementTier.allCases where tier.rawValue <= 3 {
            let requiredCount = tier.rawValue * 5 // 5, 10, 15 day streaks
            let achievement = Achievement(
                id: "streak_\(tier.rawValue)",
                title: "\(tier.name) Streaker",
                description: "Use the app for \(requiredCount) consecutive days",
                icon: "flame",
                dateUnlocked: nil,
                isUnlocked: false, // Will be implemented later
                requiredCount: requiredCount,
                currentCount: 0, // Will be implemented later
                type: .streak,
                userId: userId
            )
            newAchievements.append(achievement)
        }
        
        // Sort achievements by progress (completed first), then by type
        achievements = newAchievements.sorted { (a, b) -> Bool in
            if a.isCompleted != b.isCompleted {
                return a.isCompleted
            }
            if a.type != b.type {
                return a.type.rawValue < b.type.rawValue
            }
            return a.requiredCount < b.requiredCount
        }
    }
    
    private func calculateAchievementMetrics() {
        totalAchievements = achievements.count
        completedAchievements = achievements.filter { $0.isCompleted }.count
        
        // Calculate total points (more points for higher difficulty achievements)
        totalPoints = calculateTotalPoints()
        
        // Calculate level based on points
        level = max(1, totalPoints / 100 + 1)
    }
    
    // Helper method to format duration as a readable string
    func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") \(hours % 24) hr"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    // Helper method to format distance as a readable string
    func formatDistance(_ kilometers: Double) -> String {
        if kilometers >= 1000 {
            return String(format: "%.1f", kilometers / 1000) + " thousand km"
        } else {
            return String(format: "%.1f", kilometers) + " km"
        }
    }
    
    // Standardize country name
    private func standardizeCountryName(_ name: String) -> String {
        // Common country name mapping
        let countryNameMap: [String: String] = [
            "United States of America": "USA",
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
}
