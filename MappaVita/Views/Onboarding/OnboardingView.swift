import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @Binding var hasSeenOnboarding: Bool
    
    // Absolute paths to the onboarding images
    private let imagePaths = [
        "/Users/alan/Project/MappaVita/MappaVita/Assets.xcassets/onboarding.imageset/1.png",
        "/Users/alan/Project/MappaVita/MappaVita/Assets.xcassets/onboarding.imageset/2.png",
        "/Users/alan/Project/MappaVita/MappaVita/Assets.xcassets/onboarding.imageset/3.png"
    ]
    
    // Background color
    private let backgroundColor = Color(red: 0.10, green: 0.79, blue: 0.52) // #1aca85
    
    var body: some View {
        ZStack {
            // Full screen background color
            backgroundColor.ignoresSafeArea()
            
            GeometryReader { geometry in
                TabView(selection: $currentPage) {
                    // First page
                    onboardingPage(imagePath: imagePaths[0], isLastPage: false)
                        .tag(0)
                    
                    // Second page
                    onboardingPage(imagePath: imagePaths[1], isLastPage: false)
                        .tag(1)
                    
                    // Third page
                    onboardingPage(imagePath: imagePaths[2], isLastPage: true)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func onboardingPage(imagePath: String, isLastPage: Bool) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Background image from absolute path
                if let uiImage = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    backgroundColor
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                VStack {
                    Spacer()
                    
                    Button {
                        if isLastPage {
                            hasSeenOnboarding = true
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    } label: {
                        Text(isLastPage ? "Get Started" : "Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(backgroundColor)
                            .frame(width: 200, height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
