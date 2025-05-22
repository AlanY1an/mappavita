import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var mapViewModel = MapViewModel()
    
    var body: some View {
        TabView {
            MapView()
                .environmentObject(mapViewModel)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            PlacesListView(mapViewModel: mapViewModel)
                .tabItem {
                    Label("Places", systemImage: "mappin.and.ellipse")
                }
            
            MemoriesListView()
                .tabItem {
                    Label("Memories", systemImage: "photo.on.rectangle")
                }
            
            AchievementsView()
                .tabItem {
                    Label("Achievements", systemImage: "trophy")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
} 