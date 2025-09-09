import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Logo/Header
                    VStack(spacing: 10) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Student Companion")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Authentication Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                            SecureField(isSignUp ? "Create a strong password" : "Enter your password", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Confirm Password Field (Sign Up only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.headline)
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Password Requirements (Sign Up only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password Requirements:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("• At least 8 characters")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("• Uppercase and lowercase letters")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("• Numbers and special characters")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        // Primary Action Button
                        Button(action: primaryAction) {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text(isSignUp ? "Creating Account..." : "Signing In...")
                                        .fontWeight(.medium)
                                }
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        
                        // Toggle Sign Up/Sign In
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp.toggle()
                                clearForm()
                            }
                        }) {
                            HStack {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    
                    // Additional Info
                    VStack(spacing: 8) {
                        Text("Your data is securely stored and synced across all your devices.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if isSignUp {
                            Text("By creating an account, you'll be able to sync your academic data across all devices.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !password.isEmpty
        
        if isSignUp {
            let confirmValid = password == confirmPassword && !confirmPassword.isEmpty
            return emailValid && passwordValid && confirmValid
        } else {
            return emailValid && passwordValid
        }
    }
    
    // MARK: - Actions
    
    private func primaryAction() {
        if isSignUp {
            signUp()
        } else {
            signIn()
        }
    }
    
    private func signUp() {
        guard password == confirmPassword else {
            showErrorMessage("Passwords do not match")
            return
        }
        
        isLoading = true
        Task {
            let result = await supabaseService.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            
            await MainActor.run {
                switch result {
                case .success:
                    // Success will be handled by the authentication state observer
                    break
                case .failure(let error):
                    showErrorMessage(error.localizedDescription)
                }
                isLoading = false
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        Task {
            let result = await supabaseService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            
            await MainActor.run {
                switch result {
                case .success:
                    // Success will be handled by the authentication state observer
                    break
                case .failure(let error):
                    showErrorMessage(error.localizedDescription)
                }
                isLoading = false
            }
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
        showError = false
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(SupabaseService.shared)
}