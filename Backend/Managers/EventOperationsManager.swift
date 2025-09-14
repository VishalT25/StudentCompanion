import Foundation
import SwiftUI
import Combine

// MARK: - Event Operations Manager
@MainActor
class EventOperationsManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var events: [Event] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var operationStatistics = EventStatistics()
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let dataValidator = DataConsistencyValidator()
    private let authPromptHandler = AuthenticationPromptHandler.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("📅 EventOperationsManager: Initializing with simple approach...")
        setupAuthenticationObserver()
    }
    
    // MARK: - Simple Authentication Observer
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                print("📅 EventOperationsManager: Auth state changed: \(isAuthenticated)")
                if isAuthenticated {
                    Task {
                        // Simple: just wait a moment for auth to settle, then load data
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await self?.loadDataDirectly()
                    }
                } else {
                    self?.clearData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Direct Data Loading
    
    /// Simple, direct data loading from database
    private func loadDataDirectly() async {
        print("📅 EventOperationsManager: 🚀 Loading data directly from database...")
        
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            print("📅 EventOperationsManager: ❌ No user ID available")
            return
        }
        
        isLoading = true
        
        do {
            // Load categories directly from database using basic repository
            print("📅 EventOperationsManager: Loading categories...")
            let categoryResponse = try await supabaseService.client
                .from("categories")
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            let dbCategories = try JSONDecoder().decode([DatabaseCategory].self, from: categoryResponse.data)
            let loadedCategories = dbCategories.map { $0.toLocal() }.sorted { $0.name < $1.name }
            
            print("📅 EventOperationsManager: ✅ Loaded \(loadedCategories.count) categories from database")
            
            // Load events directly from database
            print("📅 EventOperationsManager: Loading events...")
            let eventResponse = try await supabaseService.client
                .from("events")
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            let dbEvents = try JSONDecoder().decode([DatabaseEvent].self, from: eventResponse.data)
            let loadedEvents = dbEvents.map { $0.toLocal() }.sorted { $0.date < $1.date }
            
            print("📅 EventOperationsManager: ✅ Loaded \(loadedEvents.count) events from database")
            
            // Update UI directly
            self.categories = loadedCategories
            self.events = loadedEvents
            self.operationStatistics.updateCategoriesLoaded(loadedCategories.count)
            self.operationStatistics.updateEventsLoaded(loadedEvents.count)
            self.lastSyncTime = Date()
            
            // Also update cache for other components
            await CacheSystem.shared.categoryCache.store(loadedCategories)
            await CacheSystem.shared.eventCache.store(loadedEvents)
            
            print("📅 EventOperationsManager: ✅ Data loading complete - \(loadedEvents.count) events, \(loadedCategories.count) categories displayed")
            
        } catch {
            print("📅 EventOperationsManager: ❌ Failed to load data: \(error)")
            
            // Fallback to cache if database fails
            print("📅 EventOperationsManager: Trying cache as fallback...")
            let cachedCategories = await CacheSystem.shared.categoryCache.retrieve()
            let cachedEvents = await CacheSystem.shared.eventCache.retrieve()
            
            self.categories = cachedCategories.sorted { $0.name < $1.name }
            self.events = cachedEvents.sorted { $0.date < $1.date }
            self.operationStatistics.updateCategoriesLoaded(cachedCategories.count)
            self.operationStatistics.updateEventsLoaded(cachedEvents.count)
            
            print("📅 EventOperationsManager: ✅ Fallback complete - \(cachedEvents.count) events, \(cachedCategories.count) categories from cache")
        }
        
        isLoading = false
    }
    
    // MARK: - Public Methods for Manual Refresh
    
    func refreshData() async {
        print("📅 EventOperationsManager: 🔄 Manual refresh requested")
        await loadDataDirectly()
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
                let dbModel = DatabaseEvent(from: event, userId: userId)
                let response = try await supabaseService.client
                    .from("events")
                    .insert(dbModel)
                    .select()
                    .single()
                    .execute()
                
                let savedDbEvent = try JSONDecoder().decode(DatabaseEvent.self, from: response.data)
                let savedEvent = savedDbEvent.toLocal()
                
                // Update local copy with server data
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = savedEvent
                }
                
                // Update cache
                await CacheSystem.shared.eventCache.store(savedEvent)
                
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
                let dbModel = DatabaseEvent(from: event, userId: userId)
                let response = try await supabaseService.client
                    .from("events")
                    .update(dbModel)
                    .eq("id", value: event.id.uuidString)
                    .select()
                    .single()
                    .execute()
                
                let updatedDbEvent = try JSONDecoder().decode(DatabaseEvent.self, from: response.data)
                let updatedEvent = updatedDbEvent.toLocal()
                
                // Update local copy with server data
                if let currentIndex = events.firstIndex(where: { $0.id == event.id }) {
                    events[currentIndex] = updatedEvent
                    events.sort { $0.date < $1.date }
                }
                
                // Update cache
                await CacheSystem.shared.eventCache.update(updatedEvent)
                
                print("✅ EventOperationsManager: Event '\(event.title)' updated successfully")
            } catch {
                // Revert local changes if sync failed
                await loadDataDirectly()
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
                _ = try await supabaseService.client
                    .from("events")
                    .delete()
                    .eq("id", value: event.id.uuidString)
                    .execute()
                
                // Remove from cache
                await CacheSystem.shared.eventCache.delete(id: event.id.uuidString)
                
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
                let dbModel = DatabaseCategory(from: category, userId: userId)
                let response = try await supabaseService.client
                    .from("categories")
                    .insert(dbModel)
                    .select()
                    .single()
                    .execute()
                
                let savedDbCategory = try JSONDecoder().decode(DatabaseCategory.self, from: response.data)
                let savedCategory = savedDbCategory.toLocal()
                
                // Update local copy with server data
                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[index] = savedCategory
                }
                
                // Update cache
                await CacheSystem.shared.categoryCache.store(savedCategory)
                
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
                let dbModel = DatabaseCategory(from: category, userId: userId)
                let response = try await supabaseService.client
                    .from("categories")
                    .update(dbModel)
                    .eq("id", value: category.id.uuidString)
                    .select()
                    .single()
                    .execute()
                
                let updatedDbCategory = try JSONDecoder().decode(DatabaseCategory.self, from: response.data)
                let updatedCategory = updatedDbCategory.toLocal()
                
                // Update local copy with server data
                if let currentIndex = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[currentIndex] = updatedCategory
                    categories.sort { $0.name < $1.name }
                }
                
                // Update cache
                await CacheSystem.shared.categoryCache.update(updatedCategory)
                
                print("✅ EventOperationsManager: Category '\(category.name)' updated successfully")
            } catch {
                // Revert local changes if sync failed
                await loadDataDirectly()
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
                _ = try await supabaseService.client
                    .from("categories")
                    .delete()
                    .eq("id", value: category.id.uuidString)
                    .execute()
                
                // Remove from cache
                await CacheSystem.shared.categoryCache.delete(id: category.id.uuidString)
                
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
                let dbModel = DatabaseEvent(from: event, userId: userId)
                let response = try await supabaseService.client
                    .from("events")
                    .insert(dbModel)
                    .select()
                    .single()
                    .execute()
                
                let savedDbEvent = try JSONDecoder().decode(DatabaseEvent.self, from: response.data)
                let savedEvent = savedDbEvent.toLocal()
                
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
    
    // MARK: - Cleanup
    
    private func clearData() {
        print("📅 EventOperationsManager: 🧹 Clearing all data")
        events.removeAll()
        categories.removeAll()
        operationStatistics.reset()
        lastSyncTime = nil
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