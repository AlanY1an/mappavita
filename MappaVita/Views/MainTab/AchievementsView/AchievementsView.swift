import SwiftUI

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @State private var selectedFilter: AchievementType? = nil
    @State private var showCompletedOnly = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Level and stats card
                        LevelCard(
                            level: viewModel.level,
                            totalPoints: viewModel.totalPoints,
                            completedCount: viewModel.completedAchievements,
                            totalCount: viewModel.totalAchievements
                        )
                        .padding(.horizontal)
                        
                        // Filters section
                        filterSection
                        
                        // Achievement cards
                        LazyVStack(spacing: 16) {
                            ForEach(filteredAchievements) { achievement in
                                AchievementCard(achievement: achievement)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.top)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .frame(width: 100, height: 100)
                                .shadow(radius: 5)
                        )
                }
            }
            .navigationTitle("Achievements")
        }
    }
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterButton(
                        title: "All",
                        isSelected: selectedFilter == nil,
                        action: { selectedFilter = nil }
                    )
                    
                    ForEach(AchievementType.allCases, id: \.self) { type in
                        FilterButton(
                            title: type.rawValue,
                            isSelected: selectedFilter == type,
                            action: { selectedFilter = type }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Toggle("Show completed only", isOn: $showCompletedOnly)
                .padding(.horizontal)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
    
    private var filteredAchievements: [Achievement] {
        viewModel.achievements.filter { achievement in
            // Apply type filter if selected
            let typeMatches = selectedFilter == nil || achievement.type == selectedFilter
            
            // Apply completed filter if enabled
            let completionMatches = !showCompletedOnly || achievement.isCompleted
            
            return typeMatches && completionMatches
        }
    }
}

// MARK: - Supporting Views

struct LevelCard: View {
    let level: Int
    let totalPoints: Int
    let completedCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Level and progress
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Text("\(level)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getRankTitle(for: level))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(totalPoints) points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(completedCount)/\(totalCount) achievements")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatView(
                    title: "Completed",
                    value: "\(completedCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatView(
                    title: "Progress",
                    value: String(format: "%.0f%%", min(Double(completedCount) / Double(max(1, totalCount)) * 100, 100)),
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func getRankTitle(for level: Int) -> String {
        switch level {
        case 1...3:
            return "Novice Explorer"
        case 4...7:
            return "Seasoned Traveler"
        case 8...12:
            return "Adventure Master"
        case 13...18:
            return "Journey Expert"
        case 19...25:
            return "World Wanderer"
        default:
            return "Legendary Explorer"
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and icon
            HStack {
                Image(systemName: achievement.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(achievement.getColor())
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.title)
                        .font(.headline)
                    
                    Text(achievement.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if achievement.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                }
            }
            
            // Description
            Text(achievement.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress bar
            ProgressView(value: achievement.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: achievement.getColor()))
            
            // Progress text
            HStack {
                Text("\(achievement.currentCount)/\(achievement.requiredCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", achievement.progress * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
}

