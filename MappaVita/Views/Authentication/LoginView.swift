import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: AuthViewModel
    @State private var isShowingSignUp = false
    
    init() {
        // Initialize the StateObject with a temporary AuthManager
        // The real one will be injected via environmentObject
        _viewModel = StateObject(wrappedValue: AuthViewModel(authManager: AuthManager()))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
           
                Color.teal.edgesIgnoringSafeArea(.all)
                
                if let uiImage = UIImage(contentsOfFile: "/Users/alan/Project/MappaVita/MappaVita/ImageSet/Login.png") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaledToFill()
                        .frame(minWidth: geometry.size.width * 1.3, minHeight: geometry.size.height * 1.3)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        .edgesIgnoringSafeArea(.all)
                } else {
                 
                    LinearGradient(
                        gradient: Gradient(colors: [Color.teal, Color.green]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                
      
                VStack(spacing: 30) {
                    // Logo and Title
                    VStack(spacing: 12) {
                        Text("MappaVita")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        Text("Your Travel Journal")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    }
                    .padding(.top, 200)
                    
                    Spacer(minLength: 60)
                    
                    // Login Form
                    VStack(spacing: 20) {
                        Text("Welcome")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 5)
                        
                        // Email Field
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 20)
                            TextField("", text: $viewModel.email)
                                .placeholder(when: viewModel.email.isEmpty) {
                                    Text("Email").foregroundColor(.white.opacity(0.7))
                                }
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 15)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Password Field
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 20)
                            SecureField("", text: $viewModel.password)
                                .placeholder(when: viewModel.password.isEmpty) {
                                    Text("Password").foregroundColor(.white.opacity(0.7))
                                }
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                                .textContentType(.password)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 15)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Forgot Password
                        HStack {
                            Spacer()
                            Button(action: {
                                // Handle forgot password
                            }) {
                                Text("Forgot Password?")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.top, -5)
                        
                        // Error Message
                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .font(.system(size: 14))
                                .foregroundColor(Color(#colorLiteral(red: 1, green: 0.5, blue: 0.5, alpha: 1)))
                                .padding(.horizontal, 5)
                                .padding(.top, 5)
                        }
                        
                        // Sign In Button
                        Button(action: {
                            Task {
                                await viewModel.signIn()
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(height: 54)
                                    .shadow(color: Color.blue.opacity(0.5), radius: 5, x: 0, y: 3)
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // Sign Up Link
                    VStack(spacing: 8) {
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button(action: {
                            isShowingSignUp = true
                        }) {
                            Text("Create Account")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                    
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: $isShowingSignUp) {
                SignUpView()
            }
            .onAppear {
                // Update the viewModel with the environment's authManager
                viewModel.updateAuthManager(authManager)
            }
        }
    }
}

// Custom modifier for placeholder text in TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
