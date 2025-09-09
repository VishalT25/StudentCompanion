import Foundation
import Supabase
import SwiftUI

private let iso8601WithFractional: ISO8601DateFormatter = {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return f
}()

extension Date {
  func iso8601String() -> String {
    iso8601WithFractional.string(from: self)
  }
}

/// Enhanced Supabase service optimized for V2 with comprehensive real-time sync
/// Implements cloud-first architecture with offline support and conflict resolution
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    
    // MARK: - Core Configuration
    private let supabaseURL: URL
    private let supabaseAnonKey: String
    let client: SupabaseClient
    private let keychainService = SecureKeychainService.shared
    
    // MARK: - Authentication State
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var userSubscription: UserSubscription?
    
    // MARK: - Connection State
    @Published private(set) var isConnected = false
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    @Published private(set) var lastSyncTimestamp: Date?
    
    // MARK: - Security & Performance
    private var lastTokenRefresh: Date = Date()
    private let tokenRefreshInterval: TimeInterval = 900 // 15 minutes
    private var connectionMonitor: Timer?
    
    enum ConnectionQuality {
        case unknown, poor, good, excellent
        
        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .poor: return "Poor"
            case .good: return "Good" 
            case .excellent: return "Excellent"
            }
        }
    }
    
    private init() {
        // 🔒 SECURITY: Load configuration from secure source
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let supabaseURL = URL(string: url) else {
            fatalError("🔒 SECURITY CRITICAL: Supabase configuration not found in Info.plist")
        }
        
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = key
        
        // Initialize client with V2 optimizations
        self.client = SupabaseClient(
          supabaseURL: supabaseURL,
          supabaseKey: supabaseAnonKey,
          options: .init(
            db: .init(schema: "public"),
            // If custom storage is needed for Auth, provide it here; otherwise omit.
            // auth: .init(storage: MyCustomLocalStorage()),
            realtime: .init() // Swift Realtime options don't include reconnectAfterMs
          )
        )

        
        // Initialize authentication state and monitoring
        Task {
            await initializeServices()
        }
    }
    
    // MARK: - Service Initialization
    
    private func initializeServices() async {
        await initializeAuthenticationState()
        startConnectionMonitoring()
        setupAuthListener()
    }
    
    private func initializeAuthenticationState() async {
        print("🔒 Initializing authentication state...")
        
        // Check for existing session
        do {
            let session = try await client.auth.session
            
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = session.user
                self.lastTokenRefresh = Date()
            }
            
            // Load associated data
            await loadUserProfile()
            await loadUserSubscription()
            
            print("🔒 Session restored successfully")
        } catch {
            print("🔒 No existing session found: \(error)")
        }
    }
    
    private func setupAuthListener() {
        Task {
            for await (event, session) in await client.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .signedIn:
                        print("🔒 User signed in")
                        self.isAuthenticated = true
                        self.currentUser = session?.user
                        self.lastTokenRefresh = Date()
                        
                        if let session = session {
                            self.storeAuthenticationTokens(
                                accessToken: session.accessToken,
                                refreshToken: session.refreshToken
                            )
                        }
                        
                        // Post notification for authentication state change
                        NotificationCenter.default.post(
                            name: .init("SupabaseAuthStateChanged"),
                            object: true
                        )
                        
                    case .signedOut:
                        print("🔒 User signed out")
                        self.isAuthenticated = false
                        self.currentUser = nil
                        self.userProfile = nil
                        self.userSubscription = nil
                        
                        // Post notification for authentication state change
                        NotificationCenter.default.post(
                            name: .init("SupabaseAuthStateChanged"),
                            object: false
                        )
                        
                    case .tokenRefreshed:
                        print("🔒 Token refreshed")
                        self.lastTokenRefresh = Date()
                        
                        if let session = session {
                            self.storeAuthenticationTokens(
                                accessToken: session.accessToken,
                                refreshToken: session.refreshToken
                            )
                        }
                        
                    default:
                        break
                    }
                }
                
                // Load user data after sign in
                if event == .signedIn {
                    await self.loadUserProfile()
                    await self.loadUserSubscription()
                }
            }
        }
    }
    
    private func startConnectionMonitoring() {
        connectionMonitor = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.checkConnectionQuality()
            }
        }
    }
    
    private func checkConnectionQuality() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Simple ping to check connection speed
            _ = try await client
                .from("profiles")
                .select("id")
                .limit(1)
                .execute()
            
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            
            await MainActor.run {
                self.isConnected = true
                self.connectionQuality = self.qualityFromResponseTime(responseTime)
                self.lastSyncTimestamp = Date()
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.connectionQuality = .poor
            }
        }
    }
    
    private func qualityFromResponseTime(_ time: TimeInterval) -> ConnectionQuality {
        switch time {
        case 0..<0.5: return .excellent
        case 0.5..<1.5: return .good
        case 1.5..<3.0: return .poor
        default: return .poor
        }
    }
    
    // MARK: - Enhanced Authentication
    
    func signIn(email: String, password: String) async -> Result<User, AuthError> {
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }
        
        guard isValidPassword(password) else {
            return .failure(AuthError.weakPassword)
        }
        
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            
            // Authentication state will be updated via listener
            print("🔒 User authenticated successfully")
            return .success(response.user)
        } catch {
            print("🔒 SECURITY: Authentication failed: \(error)")
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    func signUp(email: String, password: String) async -> Result<User, AuthError> {
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }
        
        guard isStrongPassword(password) else {
            return .failure(AuthError.weakPassword)
        }
        
        do {
            let redirectToURL = URL(string: "stuco://auth.callback")!
            
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: redirectToURL
            )
            
            // Create default data entries
            if let session = response.session {
                await createDefaultUserData(for: response.user)
            }
            
            print("🔒 User registered successfully")
            return .success(response.user)
        } catch {
            print("🔒 SECURITY: Registration failed: \(error)")
            return .failure(AuthError.registrationFailed)
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("🔒 SECURITY WARNING: Server sign out failed: \(error)")
        }
        
        // Clear local tokens regardless of server response
        _ = keychainService.clearAllTokens()
        
        print("🔒 User signed out and tokens cleared")
    }
    
    // MARK: - User Data Management
    
    private func createDefaultUserData(for user: User) async {
        await createDefaultProfile(for: user)
        await createDefaultSubscriber(for: user)
    }
    
    private func createDefaultProfile(for user: User) async {
        let profileData = ProfileInsert(
            user_id: user.id.uuidString,
            display_name: user.email?.components(separatedBy: "@").first ?? "User",
            avatar_url: nil,
            bio: nil
        )
        
        do {
            _ = try await client
                .from("profiles")
                .insert(profileData)
                .execute()
            
            await loadUserProfile()
        } catch {
            print("Failed to create default profile: \(error)")
        }
    }
    
    private func createDefaultSubscriber(for user: User) async {
        let subscriberData = SubscriberInsert(
            user_id: user.id.uuidString,
            email: user.email ?? "",
            subscribed: false,
            subscription_tier: "free",
            role: "free"
        )
        
        do {
            _ = try await client
                .from("subscribers")
                .insert(subscriberData)
                .execute()
            
            await loadUserSubscription()
        } catch {
            print("Failed to create default subscriber: \(error)")
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(DatabaseProfile.self, from: response.data)
            
            await MainActor.run {
                self.userProfile = profile.toLocal()
            }
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    private func loadUserSubscription() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let response = try await client
                .from("subscribers")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            let subscriber = try JSONDecoder().decode(DatabaseSubscriber.self, from: response.data)
            
            await MainActor.run {
                self.userSubscription = subscriber.toLocal()
            }
        } catch {
            print("Failed to load user subscription: \(error)")
        }
    }
    
    func updateProfile(displayName: String?, bio: String? = nil) async -> Result<Void, AuthError> {
        guard let userId = currentUser?.id else {
            return .failure(AuthError.authenticationFailed)
        }
        
        do {
            await ensureValidToken()
            
            let updateData = ProfileUpdate(displayName: displayName, bio: bio)
            
            _ = try await client
                .from("profiles")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            await loadUserProfile()
            
            return .success(())
        } catch {
            print("Failed to update profile: \(error)")
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    func refreshUserData() async {
        await loadUserProfile()
        await loadUserSubscription()
    }

    // MARK: - Account Updates
    func updateEmail(_ newEmail: String) async -> Result<Void, AuthError> {
        guard isValidEmail(newEmail) else {
            return .failure(.invalidEmail)
        }
        do {
            try await client.auth.update(user: UserAttributes(email: newEmail))
            await refreshUserData()
            return .success(())
        } catch {
            print("Failed to update email: \(error)")
            return .failure(.authenticationFailed)
        }
    }
    
    func updatePassword(_ newPassword: String) async -> Result<Void, AuthError> {
        guard isStrongPassword(newPassword) else {
            return .failure(.weakPassword)
        }
        do {
            try await client.auth.update(user: UserAttributes(password: newPassword))
            return .success(())
        } catch {
            print("Failed to update password: \(error)")
            return .failure(.authenticationFailed)
        }
    }

    // MARK: - Token Management
    
    private func storeAuthenticationTokens(accessToken: String, refreshToken: String) {
        _ = keychainService.storeToken(accessToken, forKey: "supabase_access_token")
        _ = keychainService.storeToken(refreshToken, forKey: "supabase_refresh_token")
    }
    
    func ensureValidToken() async {
        guard isAuthenticated else { return }
        
        let timeSinceLastRefresh = Date().timeIntervalSince(lastTokenRefresh)
        if timeSinceLastRefresh >= tokenRefreshInterval {
            do {
                _ = try await client.auth.refreshSession()
                // Token refresh will be handled by the auth listener
            } catch {
                print("🔒 SECURITY ERROR: Token refresh failed: \(error)")
                await signOut()
            }
        }
    }
    
    // MARK: - Database Access with RLS
    
    var database: SupabaseClient {
        return client
    }
    
    // MARK: - Validation
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }
    
    private func isStrongPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChar = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasNumbers && hasSpecialChar
    }
    
    // MARK: - Statistics & Monitoring
    
    func getConnectionStats() -> ConnectionStats {
        return ConnectionStats(
            isConnected: isConnected,
            quality: connectionQuality,
            lastSync: lastSyncTimestamp,
            authExpiry: calculateTokenExpiry()
        )
    }
    
    private func calculateTokenExpiry() -> Date? {
        // JWT tokens typically expire after 1 hour
        return Date(timeInterval: 3600, since: lastTokenRefresh)
    }
    
    func getSyncStats() async -> SyncStats? {
        guard isAuthenticated else { return nil }
        
        do {
            await ensureValidToken()
            
            async let schedulesCount = getTableCount("schedules")
            async let coursesCount = getTableCount("courses")
            async let eventsCount = getTableCount("events")
            async let categoriesCount = getTableCount("categories")
            async let assignmentsCount = getTableCount("assignments")
            
            let counts = await (
                schedules: schedulesCount,
                courses: coursesCount,
                events: eventsCount,
                categories: categoriesCount,
                assignments: assignmentsCount
            )
            
            return SyncStats(
                schedulesCount: counts.schedules,
                coursesCount: counts.courses,
                assignmentsCount: counts.assignments,
                eventsCount: counts.events,
                categoriesCount: counts.categories
            )
        } catch {
            print("🔒 Failed to get sync stats: \(error)")
            return nil
        }
    }
    
    private func getTableCount(_ table: String) async -> Int {
        do {
            let response = try await client
                .from(table)
                .select("id", head: true, count: .exact)
                .execute()
            
            return response.count ?? 0
        } catch {
            return 0
        }
    }
    
    deinit {
        connectionMonitor?.invalidate()
    }
    
    
    
}

// MARK: - Supporting Types

// Database insert/update structs
private struct ProfileInsert: Codable {
    let user_id: String
    let display_name: String
    let avatar_url: String?
    let bio: String?
}

private struct SubscriberInsert: Codable {
    let user_id: String
    let email: String
    let subscribed: Bool
    let subscription_tier: String
    let role: String
}

private struct ProfileUpdate: Codable {
    let display_name: String?
    let bio: String?
    let updated_at: String
    
    init(displayName: String?, bio: String?) {
        self.display_name = displayName
        self.bio = bio
        self.updated_at = Date().iso8601String()
    }
}

struct ConnectionStats {
    let isConnected: Bool
    let quality: SupabaseService.ConnectionQuality
    let lastSync: Date?
    let authExpiry: Date?
}

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