import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
class RealtimeSyncManager: ObservableObject {
    static let shared = RealtimeSyncManager()
    
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var isConnected = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var pendingSyncCount = 0
    
    private let supabaseService = SupabaseService.shared
    private var realtimeChannels: [String: RealtimeChannel] = [:]
    private var syncQueue = SyncQueue()
    private var cancellables = Set<AnyCancellable>()

    private var realtimeSubscriptions: [Any] = []

    weak var eventsDelegate: RealtimeSyncDelegate?
    weak var schedulesDelegate: RealtimeSyncDelegate?
    weak var coursesDelegate: RealtimeSyncDelegate?
    
    private init() {
        setupAuthenticationObserver()
    }
    
    func initialize() async {
        guard supabaseService.isAuthenticated else {
            print("🔄 RealtimeSyncManager: Not authenticated, skipping initialization")
            return
        }
        
        print("🔄 RealtimeSyncManager: Initializing real-time sync...")
        syncStatus = .initializing
        
        await performInitialSync()
        await setupRealtimeSubscriptions()
        await processSyncQueue()
        
        syncStatus = .ready
        lastSyncTime = Date()
        print("🔄 RealtimeSyncManager: Initialization complete")
    }
    
    func cleanup() async {
        print("🔄 RealtimeSyncManager: Cleaning up real-time connections...")
        syncStatus = .disconnected
        isConnected = false

        // cancel subscriptions callbacks
        realtimeSubscriptions.removeAll()

        for (_, channel) in realtimeChannels {
            await channel.unsubscribe()
        }
        realtimeChannels.removeAll()
        
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    func queueSyncOperation(_ operation: SyncOperation) {
        syncQueue.enqueue(operation)
        pendingSyncCount = syncQueue.pendingCount
        
        if isConnected, case .ready = syncStatus {
            Task {
                await processSyncQueue()
            }
        }
    }
    
    func refreshAllData() async {
        guard supabaseService.isAuthenticated else { return }
        
        syncStatus = .syncing
        await performInitialSync()
        syncStatus = .ready
        lastSyncTime = Date()
    }
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                Task {
                    if isAuthenticated {
                        await self?.initialize()
                    } else {
                        await self?.cleanup()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performInitialSync() async {
        print("🔄 RealtimeSyncManager: Performing initial sync...")
        
        async let eventsSync = syncEvents()
        async let categoriesSync = syncCategories()
        async let schedulesSync = syncSchedules()
        async let coursesSync = syncCourses()
        async let assignmentsSync = syncAssignments()
        async let academicCalendarsSync = syncAcademicCalendars()
        
        let results = await [
            eventsSync, categoriesSync, schedulesSync,
            coursesSync, assignmentsSync, academicCalendarsSync
        ]
        
        let successCount = results.filter { $0 }.count
        print("🔄 RealtimeSyncManager: Initial sync completed. \(successCount)/\(results.count) successful")
    }
    
    private func setupRealtimeSubscriptions() async {
        print("🔄 RealtimeSyncManager: Setting up real-time subscriptions...")
        
        guard supabaseService.isAuthenticated, let userId = supabaseService.currentUser?.id else {
            print("🔄 RealtimeSyncManager: Cannot setup subscriptions - not authenticated")
            return
        }
        
        let userIdString = userId.uuidString
        
        await setupSubscription(tableName: "events", userId: userIdString)
        await setupSubscription(tableName: "categories", userId: userIdString)
        await setupSubscription(tableName: "schedule_items", userId: userIdString)
        await setupSubscription(tableName: "courses", userId: userIdString)
        await setupSubscription(tableName: "assignments", userId: userIdString)
        await setupSubscription(tableName: "academic_calendars", userId: userIdString)
        
        isConnected = true
        print("🔄 RealtimeSyncManager: Real-time subscriptions active")
    }
    
    private func processSyncQueue() async {
        guard isConnected, case .ready = syncStatus else { return }
        
        while let operation = syncQueue.dequeue() {
            await executeSyncOperation(operation)
            pendingSyncCount = syncQueue.pendingCount
        }
    }
    
    private func executeSyncOperation(_ operation: SyncOperation) async {
        print("🔄 RealtimeSyncManager: Executing sync operation: \(operation.type) - \(operation.action)")
        do {
            switch operation.type {
            case .events: try await executeCRUD(operation, model: DatabaseEvent.self)
            case .categories: try await executeCRUD(operation, model: DatabaseCategory.self)
            case .scheduleItems: try await executeCRUD(operation, model: DatabaseScheduleItem.self)
            case .courses: try await executeCRUD(operation, model: DatabaseCourse.self)
            case .assignments: try await executeCRUD(operation, model: DatabaseAssignment.self)
            case .academicCalendars: try await executeCRUD(operation, model: DatabaseAcademicCalendar.self)
            }
        } catch {
            print("🔄 RealtimeSyncManager: Sync operation failed: \(error). Re-queuing.")
            syncQueue.enqueue(operation) // Re-queue on failure
            pendingSyncCount = syncQueue.pendingCount
        }
    }

    private func toDictionary<T: Codable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            print("🔄 RealtimeSyncManager: Error converting model to dictionary")
            return [:]
        }
        return dictionary
    }
}

// MARK: - Real-Time Subscriptions
extension RealtimeSyncManager {
    private func setupSubscription(tableName: String, userId: String) async {
        let channelId = "table-db-changes"
        let channel = supabaseService.database.realtime.channel(channelId)

        // Use a simpler approach for now - just establish the connection
        // TODO: Implement proper postgres change subscription once we have the correct API
        await channel.subscribe { [weak self] status, error in
            guard let self else { return }
            print("🔄 RealtimeSyncManager: Channel subscription status for \(tableName): \(status)")
            
            if let error = error {
                print("🔄 RealtimeSyncManager: Subscription error: \(error)")
            }
            
            // Handle subscription status
            Task { @MainActor in
                switch status {
                case .subscribed:
                    self.isConnected = true
                    print("🔄 RealtimeSyncManager: \(tableName.capitalized) subscription active")
                case .timedOut, .channelError:
                    self.isConnected = false
                default:
                    break
                }
            }
        }

        realtimeChannels[tableName] = channel
        realtimeSubscriptions.append(channel)
    }
}

// MARK: - Database Sync Operations
extension RealtimeSyncManager {
    private func syncData<T: Decodable>(tableName: String, orderBy: String, ascending: Bool = true) async -> [T]? {
        guard supabaseService.isAuthenticated else { return nil }
        do {
            await supabaseService.ensureValidToken()
            let response: [T] = try await supabaseService.database
                .from(tableName)
                .select()
                .order(orderBy, ascending: ascending)
                .execute()
                .value
            return response
        } catch {
            print("🔄 RealtimeSyncManager: Failed to sync \(tableName): \(error)")
            return nil
        }
    }

    func syncEvents() async -> Bool {
        guard let response: [DatabaseEvent] = await syncData(tableName: "events", orderBy: "created_at", ascending: false) else { return false }
        eventsDelegate?.didReceiveRealtimeUpdate(["events": response], action: "SYNC", table: "events")
        return true
    }
    
    func syncCategories() async -> Bool {
        guard let response: [DatabaseCategory] = await syncData(tableName: "categories", orderBy: "name") else { return false }
        eventsDelegate?.didReceiveRealtimeUpdate(["categories": response], action: "SYNC", table: "categories")
        return true
    }

    func syncSchedules() async -> Bool {
        guard let response: [DatabaseScheduleItem] = await syncData(tableName: "schedule_items", orderBy: "start_time") else { return false }
        schedulesDelegate?.didReceiveRealtimeUpdate(["schedule_items": response], action: "SYNC", table: "schedule_items")
        return true
    }
    
    func syncCourses() async -> Bool {
        guard let response: [DatabaseCourse] = await syncData(tableName: "courses", orderBy: "name") else { return false }
        coursesDelegate?.didReceiveRealtimeUpdate(["courses": response], action: "SYNC", table: "courses")
        return true
    }
    
    func syncAssignments() async -> Bool {
        guard let response: [DatabaseAssignment] = await syncData(tableName: "assignments", orderBy: "due_date") else { return false }
        coursesDelegate?.didReceiveRealtimeUpdate(["assignments": response], action: "SYNC", table: "assignments")
        return true
    }

    func syncAcademicCalendars() async -> Bool {
        guard let response: [DatabaseAcademicCalendar] = await syncData(tableName: "academic_calendars", orderBy: "name") else { return false }
        schedulesDelegate?.didReceiveRealtimeUpdate(["academic_calendars": response], action: "SYNC", table: "academic_calendars")
        return true
    }
    
    private func executeCRUD<T: Codable>(_ operation: SyncOperation, model: T.Type) async throws {
        let tableName = operation.type.rawValue
        
        let data = operation.data
        guard let modelData = try? JSONSerialization.data(withJSONObject: data),
              let modelInstance = try? JSONDecoder().decode(T.self, from: modelData) else {
            print("🔄 RealtimeSyncManager: Failed to decode model for operation \(operation.action) on \(tableName)")
            return
        }
        
        switch operation.action {
        case .create:
            try await supabaseService.database
                .from(tableName)
                .insert(modelInstance)
                .execute()
        case .update:
            guard let id = data["id"] as? UUID else { throw SyncError.missingID }
            try await supabaseService.database
                .from(tableName)
                .update(modelInstance)
                .eq("id", value: id)
                .execute()
        case .delete:
            guard let id = data["id"] as? UUID else { throw SyncError.missingID }
            try await supabaseService.database
                .from(tableName)
                .delete()
                .eq("id", value: id)
                .execute()
        }
        print("🔄 RealtimeSyncManager: Successfully executed \(operation.action) on \(tableName)")
    }
}

enum SyncError: Error {
    case missingID
    case modelDecodingFailed
}

enum SyncStatus: Equatable {
    case idle
    case initializing
    case syncing
    case ready
    case disconnected
    case error(Error)
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .initializing: return "Initializing..."
        case .syncing: return "Syncing..."
        case .ready: return "Ready"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .initializing, .syncing:
            return true
        default:
            return false
        }
    }
    
    // Equatable conformance
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.initializing, .initializing),
             (.syncing, .syncing),
             (.ready, .ready),
             (.disconnected, .disconnected):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

protocol RealtimeSyncDelegate: AnyObject {
    @MainActor
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String)
}

class SyncQueue {
    private var operations: [SyncOperation] = []
    private let queue = DispatchQueue(label: "com.studentcompanion.syncqueue")
    
    var pendingCount: Int {
        queue.sync { operations.count }
    }
    
    func enqueue(_ operation: SyncOperation) {
        queue.async {
            self.operations.append(operation)
        }
    }
    
    func dequeue() -> SyncOperation? {
        queue.sync {
            guard !operations.isEmpty else { return nil }
            return operations.removeFirst()
        }
    }
}

struct SyncOperation: Identifiable {
    let id: UUID
    let type: SyncDataType
    let action: SyncAction
    let data: [String: Any]
    let timestamp: Date
    var retryCount: Int
    
    init(type: SyncDataType, action: SyncAction, data: [String: Any], retryCount: Int = 0) {
        self.id = (data["id"] as? UUID) ?? UUID()
        self.type = type
        self.action = action
        self.data = data
        self.timestamp = Date()
        self.retryCount = retryCount
    }
}

enum SyncDataType: String, CaseIterable {
    case events
    case categories
    case scheduleItems = "schedule_items"
    case courses
    case assignments
    case academicCalendars = "academic_calendars"
}

enum SyncAction: String {
    case create = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
}