import SwiftUI

struct SignInPromptSheet: View {
    @Binding var isPresented: Bool
    let actionTitle: String
    let actionDescription: String
    
    @EnvironmentObject private var supabaseService: SupabaseService
    @State private var showFullAuth = false
    
    init(
        isPresented: Binding<Bool>,
        actionTitle: String = "Add Data",
        actionDescription: String = "add your data"
    ) {
        self._isPresented = isPresented
        self.actionTitle = actionTitle
        self.actionDescription = actionDescription
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Sign In Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("To \(actionDescription), please sign in to your account. This ensures your data is securely synced across all your devices.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Benefits
                VStack(spacing: 15) {
                    Text("Why sign in?")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        BenefitRow(icon: "icloud.and.arrow.up", title: "Cloud Sync", description: "Access your data on all devices")
                        BenefitRow(icon: "lock.shield.fill", title: "Secure Storage", description: "Your data is encrypted and protected")
                        BenefitRow(icon: "arrow.triangle.2.circlepath", title: "Real-time Updates", description: "Changes sync instantly everywhere")
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Sign In to Continue") {
                        showFullAuth = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .fontWeight(.medium)
                    
                    Button("Maybe Later") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showFullAuth) {
                AuthenticationView()
                    .onReceive(supabaseService.$isAuthenticated) { isAuthenticated in
                        if isAuthenticated {
                            showFullAuth = false
                            isPresented = false
                        }
                    }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SignInPromptSheet(
        isPresented: .constant(true),
        actionTitle: "Add Event",
        actionDescription: "add your event"
    )
    .environmentObject(SupabaseService.shared)
}