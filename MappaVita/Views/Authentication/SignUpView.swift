import SwiftUI
import PhotosUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    
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
                        .frame(minWidth: geometry.size.width * 1.5, minHeight: geometry.size.height * 1.5)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.teal]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                
                // Content
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            
                            Text("Join the adventure")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        }
                            .padding(.top, 50)
                        
                        // Avatar Selection
                        VStack(spacing: 10) {
                            PhotosPicker(
                                selection: $selectedAvatar,
                                matching: .images,
                                photoLibrary: .shared()) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                        
                                        if let avatarImage {
                                            Image(uiImage: avatarImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.blue))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                            .offset(x: 30, y: 30)
                                    }
                                }
                            
                            Text("Choose Profile Picture")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom, 10)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Username Field
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                TextField("", text: $viewModel.username)
                                    .placeholder(when: viewModel.username.isEmpty) {
                                        Text("Username").foregroundColor(.white.opacity(0.7))
                                    }
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                                    .textContentType(.username)
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
                            
                            // Full Name Field
                            HStack {
                                Image(systemName: "person.text.rectangle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                TextField("", text: $viewModel.name)
                                    .placeholder(when: viewModel.name.isEmpty) {
                                        Text("Full Name").foregroundColor(.white.opacity(0.7))
                                    }
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                                    .textContentType(.name)
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
                            
                            // Gender Selection
                            HStack {
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                
                                Picker("Gender", selection: $viewModel.gender) {
                                    Text("Prefer not to say").tag("Undisclosed")
                                    Text("Male").tag("Male")
                                    Text("Female").tag("Female")
                                    Text("Non-binary").tag("Non-binary")
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 15)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            
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
                                    .keyboardType(.emailAddress)
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
                                    .textContentType(.newPassword)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 15)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            
                            // Password requirements
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Password must contain:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(viewModel.password.count >= 8 ? Color.green : Color.white.opacity(0.4))
                                    
                                    Text("At least 8 characters")
                                        .font(.system(size: 12))
                                        .foregroundColor(viewModel.password.count >= 8 ? Color.white.opacity(0.9) : Color.white.opacity(0.6))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 5)
                            .padding(.top, -5)
                            
                            // Error Message
                            if let error = viewModel.error {
                                Text(error.localizedDescription)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(#colorLiteral(red: 1, green: 0.5, blue: 0.5, alpha: 1)))
                                    .padding(.horizontal, 5)
                                    .padding(.top, 5)
                            }
                            
                            // Sign Up Button
                            Button(action: {
                                Task {
                                    await viewModel.signUp(avatarImage: avatarImage)
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(height: 54)
                                        .shadow(color: Color.purple.opacity(0.5), radius: 5, x: 0, y: 3)
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .disabled(viewModel.isLoading)
                            .padding(.top, 15)
                            
                            // Terms and conditions
                            Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.top, 10)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                        
                        // Back to login
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back to Login")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.bottom, 50)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onChange(of: selectedAvatar) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        avatarImage = uiImage
                    }
                }
            }
            .onAppear {
                // Update the viewModel with the environment's authManager
                viewModel.updateAuthManager(authManager)
            }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthManager())
}
