import Foundation
import SwiftUI
import Combine

// MARK: - Event Operations Manager
@MainActor
class EventOperationsManager: ObservableObject, RealtimeSyncDelegate {
    
    // MARK: - Published Properties
    @Published private(set) var events: [Event] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var operationStatistics = EventStatistics()
    
    // MARK: - Dependencies
    private let eventRepository: CachedRepository<DatabaseEvent, Event>
    private let categoryRepository: CachedRepository<DatabaseCategory, Category>
    private let supabaseService = SupabaseService.shared
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private let dataValidator = DataConsistencyValidator()
    private let authPromptHandler = AuthenticationPromptHandler.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize repositories with caching
        let baseEventRepo = BaseRepository<DatabaseEvent, Event>(tableName: "events")
        let baseCategoryRepo = BaseRepository<DatabaseCategory, Category>(tableName: "categories")
        
        eventRepository = CachedRepository<DatabaseEvent, Event>(
            repository: baseEventRepo,
            cache: CacheSystem.shared.eventCache,
            supabaseService: supabaseService
        )
        
        categoryRepository = CachedRepository<DatabaseCategory, Category>(
            repository: baseCategoryRepo,
            cache: CacheSystem.shared.categoryCache,
            supabaseService: supabaseService
        )
        
        setupRealtimeSync()
        setupAuthenticationObserver()
        
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        guard supabaseService.isAuthenticated else { return }
        
        isLoading = true
        
        do {
            await loadCategories()
            await loadEvents()
            lastSyncTime = Date()
        } catch {
            print("❌ EventOperationsManager: Initialization failed: \(error)")
        }
        
        isLoading = false
    }
    
    private func setupRealtimeSync() {
        realtimeSyncManager.eventDelegate = self
    }
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { 
                        // Add delay to ensure authentication is fully complete
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        await self?.initialize()
                    }
                } else {
                    self?.clearData()
                }
            }
            .store(in: &cancellables)
        
        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 EventOperationsManager: Received post sign-in data refresh notification")
            Task { await self?.refreshData() }
        }
        
        // Listen for data sync completed notification
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 EventOperationsManager: Received data sync completed notification")
            Task { await self?.reloadFromCache() }
        }
    }
    
    // MARK: - Cache Reload
    
    private func reloadFromCache() async {
        print("🔄 EventOperationsManager: Reloading data from cache")
        
        // Load events from cache
        let cachedEvents = await CacheSystem.shared.eventCache.retrieve()
        events = cachedEvents.sorted { $0.date < $1.date }
        
        // Load categories from cache
        let cachedCategories = await CacheSystem.shared.categoryCache.retrieve()
        categories = cachedCategories.sorted { $0.name < $1.name }
        
        operationStatistics.updateEventsLoaded(events.count)
        operationStatistics.updateCategoriesLoaded(categories.count)
        lastSyncTime = Date()
        
        print("🔄 EventOperationsManager: Reloaded \(events.count) events and \(categories.count) categories from cache")
    }
    
    // MARK: - Data Loading
    
    func loadEvents() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        do {
            let loadedEvents = try await eventRepository.readAll(userId: userId)
            events = loadedEvents.sorted { $0.date < $1.date }
            
            operationStatistics.updateEventsLoaded(loadedEvents.count)
            print("📅 EventOperationsManager: Loaded \(loadedEvents.count) events")
        } catch {
            print("❌ EventOperationsManager: Failed to load events: \(error)")
        }
    }
    
    func loadCategories() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        do {
            let loadedCategories = try await categoryRepository.readAll(userId: userId)
            categories = loadedCategories.sorted { $0.name < $1.name }
            
            operationStatistics.updateCategoriesLoaded(loadedCategories.count)
            print("🏷️ EventOperationsManager: Loaded \(loadedCategories.count) categories")
        } catch {
            print("❌ EventOperationsManager: Failed to load categories: \(error)")
        }
    }
    
    // MARK: - Event Operations
    
    func addEvent(_ event: Event) {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Add Event", 
                description: "add your event"
            ) { [weak self] in
                self?.addEvent(event)
            }
            return
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        // Validate event
        let validationResult = dataValidator.validateEvent(event)
        guard validationResult.isValid else {
            print("❌ EventOperationsManager: Event validation failed")
            return
        }
        
        // Add locally for immediate UI update
        events.append(event)
        events.sort { $0.date < $1.date }
        operationStatistics.incrementEventsCreated()
        
        // Sync to backend
        Task {
            do {
                let savedEvent = try await eventRepository.create(event, userId: userId)
                
                // Update local copy with server data
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = savedEvent
                }
                
                print("✅ EventOperationsManager: Event '\(event.title)' added successfully")
            } catch {
                // Remove from local array if sync failed
                events.removeAll { $0.id == event.id }
                operationStatistics.incrementErrors()
                print("❌ EventOperationsManager: Failed to add event: \(error)")
            }
        }
    }
    
    func updateEvent(_ event: Event) {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        
        // Validate event
        let validationResult = dataValidator.validateEvent(event)
        guard validationResult.isValid else {
            print("❌ EventOperationsManager: Event validation failed")
            return
        }
        
        // Update locally for immediate UI update
        events[index] = event
        events.sort { $0.date < $1.date }
        operationStatistics.incrementEventsUpdated()
        
        // Sync to backend
        Task {
            do {
                let updatedEvent = try await eventRepository.update(event, userId: userId)
                
                // Update local copy with server data
                if let currentIndex = events.firstIndex(where: { $0.id == event.id }) {
                    events[currentIndex] = updatedEvent
                    events.sort { $0.date < $1.date }
                }
                
                print("✅ EventOperationsManager: Event '\(event.title)' updated successfully")
            } catch {
                // Revert local changes if sync failed
                await loadEvents()
                operationStatistics.incrementErrors()
                print("❌ EventOperationsManager: Failed to update event: \(error)")
            }
        }
    }
    
    func deleteEvent(_ event: Event) {
        // Remove locally for immediate UI update
        events.removeAll { $0.id == event.id }
        operationStatistics.incrementEventsDeleted()
        
        // Sync to backend
        Task {
            do {
                try await eventRepository.delete(id: event.id.uuidString)
                
                print("✅ EventOperationsManager: Event '\(event.title)' deleted successfully")
            } catch {
                // Restore data if sync failed
                events.append(event)
                events.sort { $0.date < $1.date }
                operationStatistics.incrementErrors()
                print("❌ EventOperationsManager: Failed to delete event: \(error)")
            }
        }
    }
    
    func completeEvent(_ event: Event) {
        var completedEvent = event
        completedEvent.isCompleted = true
        updateEvent(completedEvent)
    }
    
    func uncompleteEvent(_ event: Event) {
        var uncompletedEvent = event
        uncompletedEvent.isCompleted = false
        updateEvent(uncompletedEvent)
    }
    
    // MARK: - Category Operations
    
    func addCategory(_ category: Category) {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Add Category",
                description: "add your category"
            ) { [weak self] in
                self?.addCategory(category)
            }
            return
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        // Validate category
        let validationResult = dataValidator.validateCategory(category)
        guard validationResult.isValid else {
            print("❌ EventOperationsManager: Category validation failed")
            return
        }
        
        // Add locally for immediate UI update
        categories.append(category)
        categories.sort { $0.name < $1.name }
        operationStatistics.incrementCategoriesCreated()
        
        // Sync to backend
        Task {
            do {
                let savedCategory = try await categoryRepository.create(category, userId: userId)
                
                // Update local copy with server data
                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[index] = savedCategory
                }
                
                print("✅ EventOperationsManager: Category '\(category.name)' added successfully")
            } catch {
                // Remove from local array if sync failed
                categories.removeAll { $0.id == category.id }
                operationStatistics.incrementErrors()
                print("❌ EventOperationsManager: Failed to add category: \(error)")
            }
        }
    }
    
    func updateCategory(_ category: Category) {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        
        // Validate category
        let validationResult = dataValidator.validateCategory(category)
        guard validationResult.isValid else {
            print("❌ EventOperationsManager: Category validation failed")
            return
        }
        
        // Update locally for immediate UI update
        categories[index] = category
        categories.sort { $0.name < $1.name }
        operationStatistics.incrementCategoriesUpdated()
        
        // Sync to backend
        Task {
            do {
                let updatedCategory = try await categoryRepository.update(category, userId: userId)
                
                // Update local copy with server data
                if let currentIndex = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[currentIndex] = updatedCategory
                    categories.sort { $0.name < $1.name }
                }
                
                print("✅ EventOperationsManager: Category '\(category.name)' updated successfully")
            } catch {
                // Revert local changes if sync failed
                await loadCategories()
                operationStatistics.incrementErrors()
                print("❌ EventOperationsManager: Failed to update category: \(error)")
            }
        }
    }
    
    func deleteCategory(_ category: Category) {
        // Remove category references from events
        let affectedEvents = events.filter { $0.categoryId == category.id }
        for var event in affectedEvents {
            event.categoryId = nil
            updateEvent(event)
        }
        
        // Remove locally for immediate UI update
        categories.removeAll { $0.id == category.id }
        operationStatistics.incrementCategoriesDeleted()
        
        // Sync to backend
        Task {
            do {
                try await categoryRepository.delete(id: category.id.uuidString)
                
                print("✅ EventOperationsManager: Category '\(category.name)' deleted successfully")
            } catch {
                // Restore data if sync failed
                categories.append(category)
                categories.sort { $0.name < $1.name }
                operationStatistics.incrementErrors()
                print("❌ EventOperationsManager: Failed to delete category: \(error)")
            }
        }
    }
    
    // MARK: - Query Operations
    
    func getEvent(by id: UUID) -> Event? {
        return events.first { $0.id == id }
    }
    
    func getEvents(for date: Date) -> [Event] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func getEvents(from startDate: Date, to endDate: Date) -> [Event] {
        return events.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    func getEvents(for courseId: UUID) -> [Event] {
        return events.filter { $0.courseId == courseId }
    }
    
    func getEventsForCategory(_ categoryId: UUID) -> [Event] {
        return events.filter { $0.categoryId == categoryId }
    }
    
    func getIncompleteEvents() -> [Event] {
        return events.filter { !$0.isCompleted }
    }
    
    func getOverdueEvents() -> [Event] {
        let now = Date()
        return events.filter { !$0.isCompleted && $0.date < now }
    }
    
    func getUpcomingEvents(limit: Int = 10) -> [Event] {
        let now = Date()
        return events
            .filter { !$0.isCompleted && $0.date >= now }
            .prefix(limit)
            .sorted { $0.date < $1.date }
    }
    
    func getCategory(by id: UUID) -> Category? {
        return categories.first { $0.id == id }
    }
    
    // MARK: - Bulk Operations
    
    func importEvents(_ eventsToImport: [Event]) async {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Import Events",
                description: "import your events"
            ) { [weak self] in
                Task { await self?.importEvents(eventsToImport) }
            }
            return
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        isLoading = true
        var successCount = 0
        
        for event in eventsToImport {
            do {
                let savedEvent = try await eventRepository.create(event, userId: userId)
                events.append(savedEvent)
                successCount += 1
                operationStatistics.incrementEventsCreated()
            } catch {
                print("❌ EventOperationsManager: Failed to import event '\(event.title)': \(error)")
                operationStatistics.incrementErrors()
            }
        }
        
        events.sort { $0.date < $1.date }
        isLoading = false
        
        print("📅 EventOperationsManager: Imported \(successCount)/\(eventsToImport.count) events")
    }
    
    func exportEvents() -> [Event] {
        return events
    }
    
    // MARK: - Analytics
    
    func getEventAnalytics() -> EventAnalytics {
        let totalEvents = events.count
        let completedEvents = events.filter { $0.isCompleted }.count
        let overdueEvents = getOverdueEvents().count
        let upcomingEvents = getUpcomingEvents().count
        
        var categoryBreakdown: [String: Int] = [:]
        var typeBreakdown: [String: Int] = [:]
        
        for event in events {
            // Category breakdown
            if let categoryId = event.categoryId,
               let category = getCategory(by: categoryId) {
                categoryBreakdown[category.name, default: 0] += 1
            } else {
                categoryBreakdown["Uncategorized", default: 0] += 1
            }
            
            // Type breakdown
            typeBreakdown[event.eventType.rawValue, default: 0] += 1
        }
        
        return EventAnalytics(
            totalEvents: totalEvents,
            completedEvents: completedEvents,
            overdueEvents: overdueEvents,
            upcomingEvents: upcomingEvents,
            categoryBreakdown: categoryBreakdown,
            typeBreakdown: typeBreakdown,
            completionRate: totalEvents > 0 ? Double(completedEvents) / Double(totalEvents) : 0
        )
    }
    
    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        Task { @MainActor in
            switch (table, action) {
            case ("events", "SYNC"):
                if let eventsData = data["events"] as? [DatabaseEvent] {
                    await handleEventSync(eventsData)
                }
            case ("events", "INSERT"), ("events", "UPDATE"):
                await handleEventUpdate(data)
            case ("events", "DELETE"):
                await handleEventDelete(data)
            case ("categories", "SYNC"):
                if let categoriesData = data["categories"] as? [DatabaseCategory] {
                    await handleCategorySync(categoriesData)
                }
            case ("categories", "INSERT"), ("categories", "UPDATE"):
                await handleCategoryUpdate(data)
            case ("categories", "DELETE"):
                await handleCategoryDelete(data)
            default:
                break
            }
            
            lastSyncTime = Date()
        }
    }
    
    private func handleEventSync(_ dbEvents: [DatabaseEvent]) async {
        let syncedEvents = dbEvents.map { $0.toLocal() }
        events = syncedEvents.sorted { $0.date < $1.date }
        operationStatistics.updateEventsLoaded(syncedEvents.count)
        
        print("🔄 EventOperationsManager: Synced \(syncedEvents.count) events from database")
    }
    
    private func handleCategorySync(_ dbCategories: [DatabaseCategory]) async {
        let syncedCategories = dbCategories.map { $0.toLocal() }
        categories = syncedCategories.sorted { $0.name < $1.name }
        operationStatistics.updateCategoriesLoaded(syncedCategories.count)
        
        print("🔄 EventOperationsManager: Synced \(syncedCategories.count) categories from database")
    }
    
    private func handleEventUpdate(_ data: [String: Any]) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let dbEvent = try JSONDecoder().decode(DatabaseEvent.self, from: jsonData)
            let event = dbEvent.toLocal()
            
            if let existingIndex = events.firstIndex(where: { $0.id == event.id }) {
                // Update existing event
                events[existingIndex] = event
            } else {
                // Add new event
                events.append(event)
            }
            
            events.sort { $0.date < $1.date }
            
            print("🔄 EventOperationsManager: Event '\(event.title)' synced from realtime")
        } catch {
            print("❌ EventOperationsManager: Failed to handle event update: \(error)")
        }
    }
    
    private func handleEventDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let eventId = UUID(uuidString: idString) else { return }
        
        events.removeAll { $0.id == eventId }
        
        print("🔄 EventOperationsManager: Event deleted from realtime")
    }
    
    private func handleCategoryUpdate(_ data: [String: Any]) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let dbCategory = try JSONDecoder().decode(DatabaseCategory.self, from: jsonData)
            let category = dbCategory.toLocal()
            
            if let existingIndex = categories.firstIndex(where: { $0.id == category.id }) {
                // Update existing category
                categories[existingIndex] = category
            } else {
                // Add new category
                categories.append(category)
            }
            
            categories.sort { $0.name < $1.name }
            
            print("🔄 EventOperationsManager: Category '\(category.name)' synced from realtime")
        } catch {
            print("❌ EventOperationsManager: Failed to handle category update: \(error)")
        }
    }
    
    private func handleCategoryDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let categoryId = UUID(uuidString: idString) else { return }
        
        categories.removeAll { $0.id == categoryId }
        
        print("🔄 EventOperationsManager: Category deleted from realtime")
    }
    
    // MARK: - Cleanup
    
    private func clearData() {
        events.removeAll()
        categories.removeAll()
        operationStatistics.reset()
        lastSyncTime = nil
    }
    
    func refreshData() async {
        await initialize()
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        events.isEmpty
    }
    
    var eventCount: Int {
        events.count
    }
    
    var categoryCount: Int {
        categories.count
    }
}

// MARK: - Supporting Types

struct EventAnalytics {
    let totalEvents: Int
    let completedEvents: Int
    let overdueEvents: Int
    let upcomingEvents: Int
    let categoryBreakdown: [String: Int]
    let typeBreakdown: [String: Int]
    let completionRate: Double
    
    var formattedCompletionRate: String {
        String(format: "%.1f%%", completionRate * 100)
    }
}

class EventStatistics: ObservableObject {
    @Published private(set) var eventsLoaded = 0
    @Published private(set) var categoriesLoaded = 0
    @Published private(set) var eventsCreated = 0
    @Published private(set) var eventsUpdated = 0
    @Published private(set) var eventsDeleted = 0
    @Published private(set) var categoriesCreated = 0
    @Published private(set) var categoriesUpdated = 0
    @Published private(set) var categoriesDeleted = 0
    @Published private(set) var errors = 0
    @Published private(set) var lastReset = Date()
    
    func updateEventsLoaded(_ count: Int) {
        eventsLoaded = count
    }
    
    func updateCategoriesLoaded(_ count: Int) {
        categoriesLoaded = count
    }
    
    func incrementEventsCreated() {
        eventsCreated += 1
    }
    
    func incrementEventsUpdated() {
        eventsUpdated += 1
    }
    
    func incrementEventsDeleted() {
        eventsDeleted += 1
    }
    
    func incrementCategoriesCreated() {
        categoriesCreated += 1
    }
    
    func incrementCategoriesUpdated() {
        categoriesUpdated += 1
    }
    
    func incrementCategoriesDeleted() {
        categoriesDeleted += 1
    }
    
    func incrementErrors() {
        errors += 1
    }
    
    func reset() {
        eventsLoaded = 0
        categoriesLoaded = 0
        eventsCreated = 0
        eventsUpdated = 0
        eventsDeleted = 0
        categoriesCreated = 0
        categoriesUpdated = 0
        categoriesDeleted = 0
        errors = 0
        lastReset = Date()
    }
    
    var totalOperations: Int {
        eventsCreated + eventsUpdated + eventsDeleted + 
        categoriesCreated + categoriesUpdated + categoriesDeleted
    }
    
    var successRate: Double {
        let total = totalOperations + errors
        guard total > 0 else { return 1.0 }
        return Double(totalOperations) / Double(total)
    }
}