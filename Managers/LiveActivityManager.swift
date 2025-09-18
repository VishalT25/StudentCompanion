import ActivityKit
import SwiftUI 

class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {
        // Observe activities if needed (e.g. for dismissal)
        Task {
            for await activityState in Activity<ClassActivityAttributes>.activityUpdates {
                  ("Live Activity \(activityState.id) changed state: \(activityState.activityState)")
            }
        }
    }

    private var currentActivities: [String: Activity<ClassActivityAttributes>] = [:]
    
    
    func getActiveActivities() -> [LiveActivityInfo] {
        return Activity<ClassActivityAttributes>.activities.map { activity in
            let state = activity.content.state
            let components = state.eventColorComponents
            let color: Color
            if components.count == 4 {
                color = Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
            } else {
                color = .gray // Fallback color
            }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            
            return LiveActivityInfo(
                id: activity.id,
                title: state.eventName,
                subtitle: "Class in session",
                timeRange: timeFormatter.string(from: state.endTime),
                location: nil,
                color: color
            )
        }
    }

    // Helper to get today's specific date instance for a schedule item's time
    func getAbsoluteTime(for itemTime: Date, on targetDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: itemTime)
        
        guard let hour = timeComponents.hour,
              let minute = timeComponents.minute,
              let second = timeComponents.second else {
            return targetDate // fallback
        }
        
        return calendar.date(bySettingHour: hour, minute: minute, second: second, of: targetDate) ?? targetDate
    }

    @MainActor
    func startActivity(for item: ScheduleItem, themeManager: ThemeManager) {
        guard item.isLiveActivityEnabled else {
             ("Live Activity is disabled for item \(item.title).")
            return
        }

        // Ensure no duplicate activity for the same item
        guard currentActivities[item.id.uuidString] == nil else {
             ("Activity for item \(item.title) already exists.")
            // Optionally, update it here if needed
            // updateActivity(for: item, themeManager: themeManager)
            return
        }
        
        // Make sure the event is actually current or upcoming shortly
        let now = Date()
        let itemStartTimeToday = getAbsoluteTime(for: item.startTime, on: now)
        let itemEndTimeToday = getAbsoluteTime(for: item.endTime, on: now)

        guard now < itemEndTimeToday else {
             ("Cannot start activity for \(item.title) as it has already ended for today.")
            return
        }

        let attributes = ClassActivityAttributes(creationDate: Date()) // Static attributes
        let initialState = ClassActivityAttributes.ContentState(
            eventName: item.title,
            endTime: itemEndTimeToday,
            eventColorComponents: item.color.toCGFloatComponents(),
            themePrimaryColorComponents: themeManager.currentTheme.primaryColor.toCGFloatComponents()
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: itemEndTimeToday.addingTimeInterval(5*60)), // Stale after 5 mins past end
                pushType: nil // No remote push updates for now
            )
            currentActivities[item.id.uuidString] = activity
             ("Live Activity started for \(item.title) with ID: \(activity.id)")
            
            // Observe state changes for this specific activity
            Task {
                for await stateUpdate in activity.contentUpdates {
                     ("Activity \(activity.id) for \(stateUpdate.state.eventName) updated its content.")
                }
            }

        } catch {
             ("Error requesting Live Activity for \(item.title): \(error.localizedDescription)")
        }
    }

    @MainActor
    func updateActivity(for item: ScheduleItem, themeManager: ThemeManager) {
        guard let activity = currentActivities[item.id.uuidString] else {
             ("No activity found to update for item \(item.title).")
            return
        }
        
        let itemEndTimeToday = getAbsoluteTime(for: item.endTime, on: Date())

        let updatedState = ClassActivityAttributes.ContentState(
            eventName: item.title,
            endTime: itemEndTimeToday,
            eventColorComponents: item.color.toCGFloatComponents(),
            themePrimaryColorComponents: themeManager.currentTheme.primaryColor.toCGFloatComponents()
        )
        
        Task {
            await activity.update(using: updatedState, alertConfiguration: nil)
             ("Live Activity updated for \(item.title)")
        }
    }

    @MainActor
    func endActivity(for itemID: String) {
        guard let activity = currentActivities[itemID] else {
             ("No activity found to end for item ID \(itemID).")
            return
        }
        Task {
            await activity.end(nil, dismissalPolicy: .default) // Dismiss immediately or after a short period
            currentActivities.removeValue(forKey: itemID)
             ("Live Activity ended for item ID \(itemID)")
        }
    }
    
    @MainActor
    func endAllActivities() {
        for (id, activity) in currentActivities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
                 ("Ended activity: \(id)")
            }
        }
        currentActivities.removeAll()
    }

    // You might want a method to check and update activities based on current time
    @MainActor
    func cleanupEndedActivities(scheduleItems: [ScheduleItem]) {
        let now = Date()
        for (id, activity) in currentActivities {
            // Find the original schedule item
            guard let item = scheduleItems.first(where: { $0.id.uuidString == id }) else {
                // Item might have been deleted, end its activity
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                currentActivities.removeValue(forKey: id)
                continue
            }
            
            let itemEndTimeToday = getAbsoluteTime(for: item.endTime, on: now)
            if now >= itemEndTimeToday {
                 ("Cleaning up ended activity for \(item.title)")
                Task { await activity.end(nil, dismissalPolicy: .default) }
                currentActivities.removeValue(forKey: id)
            } else if activity.activityState == .ended || activity.activityState == .dismissed {
                 currentActivities.removeValue(forKey: id) // remove if system ended it
            }
        }
    }
}
