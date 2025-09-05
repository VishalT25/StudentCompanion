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
    private var cancellables = Set<AnyCancellable>()
    
    weak var eventsDelegate: RealtimeSyncDelegate?
    weak var schedulesDelegate: RealtimeSyncDelegate?
    weak var coursesDelegate: RealtimeSyncDelegate?
    
    private init() {
        setupAuthenticationObserver()
    }
    
    func ensureStarted() async {
        if supabaseService.isAuthenticated {
            syncStatus = .ready
            isConnected = false
        } else {
            syncStatus = .disconnected
            isConnected = false
        }
    }
    
    func initialize() async {
        if supabaseService.isAuthenticated {
            syncStatus = .ready
            isConnected = false
            lastSyncTime = nil
            pendingSyncCount = 0
        } else {
            syncStatus = .disconnected
            isConnected = false
        }
    }
    
    func cleanup() async {
        syncStatus = .disconnected
        isConnected = false
        lastSyncTime = nil
        pendingSyncCount = 0
        
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    func queueSyncOperation(_ operation: SyncOperation) {
        pendingSyncCount = 0
    }
    
    func refreshAllData() async {
    }
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                Task { @MainActor in
                    if isAuthenticated {
                        self?.syncStatus = .ready
                        self?.isConnected = false
                    } else {
                        self?.syncStatus = .disconnected
                        self?.isConnected = false
                        self?.lastSyncTime = nil
                        self?.pendingSyncCount = 0
                    }
                }
            }
            .store(in: &cancellables)
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
    case schedules
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