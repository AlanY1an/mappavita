//
//  MappaVitaApp.swift
//  MappaVita
//
//  Created by Yian Ge on 4/22/25.
//

import SwiftUI
import FirebaseCore
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("📱 Firebase已初始化")
        
        // Initialize CoreData
        _ = PlaceStore.shared
        
        return true
    }
}

@main
struct MappaVitaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager()
    @State private var isCheckingAuth = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    // Test Mode
    private let alwaysShowOnboarding = false  // Set to true to always show onboarding
    
    // Test Mode: Set to true to reset onboarding state on each launch
    private let resetOnboardingOnLaunch = true  // Set to true for development testing, false for release

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    ZStack {
                        Color.teal.edgesIgnoringSafeArea(.all)
                        VStack {
                            Text("MappaVita")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .padding(.top, 20)
                        }
                    }
                    .onAppear {
    hasSeenOnboarding
                        if resetOnboardingOnLaunch {
                            hasSeenOnboarding = false
                        }
                        
                        // Give Firebase time to verify authentication
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            isCheckingAuth = false
                        }
                    }
                } else if alwaysShowOnboarding {
            
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                } else if authManager.isAuthenticated {
              
                    MainTabView()
                        .environmentObject(authManager)
                } else if !hasSeenOnboarding {
                 
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                } else {
           
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}

