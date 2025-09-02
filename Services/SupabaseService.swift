import Foundation
import Supabase
import SwiftUI

/// Secure Supabase service with comprehensive security measures
/// Implements zero-trust architecture and defense-in-depth
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // MARK: - Security Configuration
    private let supabaseURL: URL
    private let supabaseAnonKey: String
    private let client: SupabaseClient
    private let keychainService = SecureKeychainService.shared
    
    // Authentication state
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var userSubscription: UserSubscription?
    
    // Security monitoring
    private var lastTokenRefresh: Date = Date()
    private let tokenRefreshInterval: TimeInterval = 900 // 15 minutes
    
    private init() {
        // 🔒 SECURITY: Load configuration from secure source
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let supabaseURL = URL(string: url) else {
            fatalError("🔒 SECURITY CRITICAL: Supabase configuration not found in Info.plist")
        }
        
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = key
        
        // Initialize client with security configuration
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey
        )
        
        // Initialize authentication state
        Task {
            await initializeAuthenticationState()
        }
    }
    
    // MARK: - Secure Authentication
    
    /// Initialize authentication state from secure storage
    func initializeAuthenticationState() async {
        // Retrieve stored session securely
        if let accessToken = keychainService.retrieveToken(forKey: "supabase_access_token"),
           let refreshToken = keychainService.retrieveToken(forKey: "supabase_refresh_token") {
            
            // Validate token structure
            guard keychainService.validateJWTStructure(accessToken) else {
                print("🔒 SECURITY WARNING: Invalid token structure detected")
                await signOut()
                return
            }
            
            // Check if token is expired
            if keychainService.isTokenExpired(accessToken) {
                print("🔒 Token expired, attempting refresh...")
                await refreshAuthenticationToken(refreshToken: refreshToken)
            } else {
                // Restore session
                do {
                    try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                    
                    // Get current user after setting session
                    let user = try await client.auth.user()
                    
                    await MainActor.run {
                        self.isAuthenticated = true
                        self.currentUser = user
                    }
                    
                    // Load user profile and subscription data
                    await loadUserProfile()
                    await loadUserSubscription()
                    
                    print("🔒 Session restored successfully")
                } catch {
                    print("🔒 SECURITY ERROR: Failed to restore session: \(error)")
                    await signOut()
                }
            }
        }
    }
    
    /// Secure sign in with email and password
    /// - Parameters:
    ///   - email: User email (validated)
    ///   - password: User password (will be securely transmitted)
    /// - Returns: Authentication result
    func signIn(email: String, password: String) async -> Result<User, AuthError> {
        // 🔒 SECURITY: Input validation
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }
        
        guard isValidPassword(password) else {
            return .failure(AuthError.weakPassword)
        }
        
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            
            // 🔒 SECURITY: Secure token storage
            let success = storeAuthenticationTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            
            guard success else {
                print("🔒 SECURITY CRITICAL: Failed to store authentication tokens")
                return .failure(AuthError.storageError)
            }
            
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = response.user
                self.lastTokenRefresh = Date()
            }
            
            // Load user profile and subscription data
            await loadUserProfile()
            await loadUserSubscription()
            
            print("🔒 User authenticated successfully")
            return .success(response.user)
        } catch {
            print("🔒 SECURITY: Authentication failed: \(error)")
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    /// Secure sign up with email and password
    /// - Parameters:
    ///   - email: User email (validated)
    ///   - password: User password (validated for strength)
    /// - Returns: Authentication result
    func signUp(email: String, password: String) async -> Result<User, AuthError> {
        // 🔒 SECURITY: Input validation
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }
        
        guard isStrongPassword(password) else {
            return .failure(AuthError.weakPassword)
        }
        
        do {
            // Add redirectTo parameter to specify where users should be redirected after email verification
            // This should match the custom URL scheme registered in Info.plist
            let redirectToURL = URL(string: "stuco://auth.callback")!
            
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: redirectToURL
            )
            
            if let session = response.session {
                // Store tokens securely
                let success = storeAuthenticationTokens(
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken
                )
                
                guard success else {
                    return .failure(AuthError.storageError)
                }
                
                await MainActor.run {
                    self.isAuthenticated = true
                    self.currentUser = response.user
                    self.lastTokenRefresh = Date()
                }
                
                // Create default profile and subscriber entries
                await createDefaultProfile(for: response.user)
                await createDefaultSubscriber(for: response.user)
                
                // Load user profile and subscription data
                await loadUserProfile()
                await loadUserSubscription()
            }
            
            print("🔒 User registered successfully")
            return .success(response.user)
        } catch {
            print("🔒 SECURITY: Registration failed: \(error)")
            return .failure(AuthError.registrationFailed)
        }
    }
    
    /// Secure sign out with complete cleanup
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("🔒 SECURITY WARNING: Server sign out failed: \(error)")
        }
        
        // 🔒 SECURITY: Always clear local tokens regardless of server response
        _ = keychainService.clearAllTokens()
        
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.userProfile = nil
            self.userSubscription = nil
        }
        
        print("🔒 User signed out and tokens cleared")
    }
    
    // MARK: - Profile Management
    
    /// Load user profile data
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            await ensureValidToken()
            
            let response = try await client
                .from("profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(UserProfile.self, from: response.data)
            
            await MainActor.run {
                self.userProfile = profile
            }
        } catch {
            print("Failed to load user profile: \(error)")
            // Create default profile if none exists
            if let user = currentUser {
                await createDefaultProfile(for: user)
            }
        }
    }
    
    /// Create default profile entry
    private func createDefaultProfile(for user: User) async {
        let defaultProfile = DefaultProfile(
            user_id: user.id.uuidString,
            display_name: user.email?.components(separatedBy: "@").first ?? "User",
            avatar_url: nil,
            bio: nil
        )
        
        do {
            _ = try await client
                .from("profiles")
                .upsert(defaultProfile)
                .execute()
            
            // Reload profile data
            await loadUserProfile()
        } catch {
            print("Failed to create default profile: \(error)")
        }
    }
    
    /// Update user profile
    func updateProfile(displayName: String?, bio: String? = nil) async -> Result<Void, AuthError> {
        guard let userId = currentUser?.id else {
            return .failure(AuthError.authenticationFailed)
        }
        
        do {
            await ensureValidToken()
            
            let updateData = ProfileUpdate(
                display_name: displayName,
                bio: bio,
                updated_at: Date().toISOString()
            )
            
            _ = try await client
                .from("profiles")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            // Reload profile
            await loadUserProfile()
            
            return .success(())
        } catch {
            print("Failed to update profile: \(error)")
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    /// Refresh profile data
    func refreshProfile() async {
        await loadUserProfile()
    }
    
    // MARK: - Subscription Management
    
    /// Load user subscription data
    private func loadUserSubscription() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            await ensureValidToken()
            
            let response = try await client
                .from("subscribers")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            let subscription = try JSONDecoder().decode(UserSubscription.self, from: response.data)
            
            await MainActor.run {
                self.userSubscription = subscription
            }
        } catch {
            print("Failed to load user subscription: \(error)")
            // Create default subscription if none exists
            await createDefaultSubscriber(for: currentUser!)
        }
    }
    
    /// Create default subscriber entry
    private func createDefaultSubscriber(for user: User) async {
        struct DefaultSubscriber: Codable {
            let user_id: String
            let email: String
            let subscribed: Bool
            let subscription_tier: String
            let role: String
        }
        
        let defaultSubscriber = DefaultSubscriber(
            user_id: user.id.uuidString,
            email: user.email ?? "",
            subscribed: false,
            subscription_tier: "free",
            role: "free"
        )
        
        do {
            _ = try await client
                .from("subscribers")
                .upsert(defaultSubscriber)
                .execute()
            
            // Reload subscription data
            await loadUserSubscription()
        } catch {
            print("Failed to create default subscriber: \(error)")
        }
    }
    
    /// Refresh subscription data
    func refreshSubscription() async {
        await loadUserSubscription()
    }
    
    /// Update user password
    func updatePassword(_ newPassword: String) async -> Result<Void, AuthError> {
        guard isStrongPassword(newPassword) else {
            return .failure(AuthError.weakPassword)
        }
        
        do {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
            return .success(())
        } catch {
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    /// Update user email
    func updateEmail(_ newEmail: String) async -> Result<Void, AuthError> {
        guard isValidEmail(newEmail) else {
            return .failure(AuthError.invalidEmail)
        }
        
        do {
            _ = try await client.auth.update(user: UserAttributes(email: newEmail))
            return .success(())
        } catch {
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    // MARK: - Token Management
    
    /// Securely store authentication tokens
    private func storeAuthenticationTokens(accessToken: String, refreshToken: String) -> Bool {
        let accessSuccess = keychainService.storeToken(accessToken, forKey: "supabase_access_token")
        let refreshSuccess = keychainService.storeToken(refreshToken, forKey: "supabase_refresh_token")
        
        return accessSuccess && refreshSuccess
    }
    
    /// Refresh authentication token
    private func refreshAuthenticationToken(refreshToken: String) async {
        do {
            let response = try await client.auth.refreshSession(refreshToken: refreshToken)
            
            let success = storeAuthenticationTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            
            if success {
                await MainActor.run {
                    self.lastTokenRefresh = Date()
                }
                print("🔒 Token refreshed successfully")
            } else {
                print("🔒 SECURITY CRITICAL: Failed to store refreshed tokens")
                await signOut()
            }
        } catch {
            print("🔒 SECURITY ERROR: Token refresh failed: \(error)")
            await signOut()
        }
    }
    
    /// Check if token needs refresh and refresh if necessary
    func ensureValidToken() async {
        guard isAuthenticated else { return }
        
        let timeSinceLastRefresh = Date().timeIntervalSince(lastTokenRefresh)
        if timeSinceLastRefresh >= tokenRefreshInterval {
            if let refreshToken = keychainService.retrieveToken(forKey: "supabase_refresh_token") {
                await refreshAuthenticationToken(refreshToken: refreshToken)
            } else {
                await signOut()
            }
        }
    }
    
    // MARK: - Input Validation & Security
    
    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    /// Basic password validation
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6 // Minimum requirement
    }
    
    /// Strong password validation
    private func isStrongPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChar = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasNumbers && hasSpecialChar
    }
    
    // MARK: - Database Access (with RLS)
    
    /// Get authenticated database client
    /// This client will automatically include authentication headers
    /// and work with Row Level Security policies
    var database: SupabaseClient {
        return client
    }
    
    // MARK: - Sync Status Methods
    
    /// Check database connection
    func checkDatabaseConnection() async -> Bool {
        guard isAuthenticated else { return false }
        
        do {
            _ = try await client
                .from("schedules")
                .select("id")
                .limit(1)
                .execute()
            return true
        } catch {
            print("🔒 Database connection check failed: \(error)")
            return false
        }
    }
    
    /// Get sync statistics
    func getSyncStats() async -> SyncStats? {
        guard isAuthenticated else { return nil }
        
        do {
            await ensureValidToken()
            
            let schedulesResponse = try await client
                .from("schedules")
                .select("id")
                .execute()
            
            let coursesResponse = try await client
                .from("courses")
                .select("id")
                .execute()
            
            let eventsResponse = try await client
                .from("events")
                .select("id")
                .execute()
            
            let categoriesResponse = try await client
                .from("categories")
                .select("id")
                .execute()
            
            let assignmentsResponse = try await client
                .from("assignments")
                .select("id")
                .execute()
            
            // Decode counts
            let schedulesData = schedulesResponse.data
            let coursesData = coursesResponse.data
            let eventsData = eventsResponse.data
            let categoriesData = categoriesResponse.data
            let assignmentsData = assignmentsResponse.data
            
            let schedulesCount = try JSONSerialization.jsonObject(with: schedulesData) as? [Any]
            let coursesCount = try JSONSerialization.jsonObject(with: coursesData) as? [Any]
            let eventsCount = try JSONSerialization.jsonObject(with: eventsData) as? [Any]
            let categoriesCount = try JSONSerialization.jsonObject(with: categoriesData) as? [Any]
            let assignmentsCount = try JSONSerialization.jsonObject(with: assignmentsData) as? [Any]
            
            return SyncStats(
                schedulesCount: schedulesCount?.count ?? 0,
                coursesCount: coursesCount?.count ?? 0,
                assignmentsCount: assignmentsCount?.count ?? 0,
                eventsCount: eventsCount?.count ?? 0,
                categoriesCount: categoriesCount?.count ?? 0
            )
        } catch {
            print("🔒 Failed to get sync stats: \(error)")
            return nil
        }
    }
}

// MARK: - Profile Models

struct UserProfile: Codable {
    let id: String
    let user_id: String
    let display_name: String?
    let avatar_url: String?
    let bio: String?
    let created_at: String
    let updated_at: String
    
    var displayName: String {
        display_name ?? "User"
    }
    
    var createdDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
    
    var updatedDate: Date? {
        ISO8601DateFormatter().date(from: updated_at)
    }
}

struct DefaultProfile: Codable {
    let user_id: String
    let display_name: String?
    let avatar_url: String?
    let bio: String?
}

struct ProfileUpdate: Codable {
    let display_name: String?
    let bio: String?
    let updated_at: String
}

// MARK: - Subscription Models

struct UserSubscription: Codable {
    let id: String
    let user_id: String
    let email: String
    let stripe_customer_id: String?
    let subscribed: Bool
    let subscription_tier: String
    let role: String
    let subscription_end: String?
    let updated_at: String
    let created_at: String
    
    var subscriptionTier: SubscriptionTier {
        SubscriptionTier(rawValue: subscription_tier) ?? .free
    }
    
    var userRole: UserRole {
        UserRole(rawValue: role) ?? .free
    }
    
    var isActive: Bool {
        guard subscribed else { return false }
        
        if let endDateString = subscription_end,
           let endDate = ISO8601DateFormatter().date(from: endDateString) {
            return Date() < endDate
        }
        
        return subscribed
    }
    
    var subscriptionEndDate: Date? {
        guard let endDateString = subscription_end else { return nil }
        return ISO8601DateFormatter().date(from: endDateString)
    }
}

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    case founder = "founder"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        case .founder:
            return "Founder"
        }
    }
    
    var color: Color {
        switch self {
        case .free:
            return .gray
        case .premium:
            return .blue
        case .founder:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .free:
            return "person"
        case .premium:
            return "star.circle.fill"
        case .founder:
            return "crown.fill"
        }
    }
    
    var benefits: [String] {
        switch self {
        case .free:
            return ["Basic scheduling", "Manual data entry", "Cloud sync"]
        case .premium:
            return ["All Free features", "AI schedule import", "Priority support", "Advanced analytics"]
        case .founder:
            return ["All Premium features", "Lifetime access", "Early feature access", "Founder badge"]
        }
    }
}

enum UserRole: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    case founder = "founder"
    
    var subscriptionTier: SubscriptionTier {
        switch self {
        case .free:
            return .free
        case .premium:
            return .premium
        case .founder:
            return .founder
        }
    }
}

// MARK: - Custom Error Types

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case weakPassword
    case authenticationFailed
    case registrationFailed
    case storageError
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, numbers, and special characters"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials"
        case .registrationFailed:
            return "Registration failed. Please try again"
        case .storageError:
            return "Failed to store authentication data securely"
        }
    }
}

// MARK: - Sync Statistics

struct SyncStats {
    let schedulesCount: Int
    let coursesCount: Int
    let assignmentsCount: Int
    let eventsCount: Int
    let categoriesCount: Int
    
    var totalItems: Int {
        schedulesCount + coursesCount + assignmentsCount + eventsCount + categoriesCount
    }
}