import ActivityKit
import SwiftUI

// Helper to convert Color to [CGFloat] for Codable ContentState
extension Color {
    func toCGFloatComponents() -> [CGFloat] {
        // Default to black if components are not available (shouldn't happen for solid colors)
        return UIColor(self).cgColor.components ?? [0.0, 0.0, 0.0, 1.0]
    }
}

struct ClassActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state
        var eventName: String
        var endTime: Date
        var eventColorComponents: [CGFloat] // From ScheduleItem.color
        var themePrimaryColorComponents: [CGFloat] // From ThemeManager
        
        // Helper to get Color back
        func eventColor() -> Color {
            guard eventColorComponents.count == 4 else { return .black }
            return Color(UIColor(red: eventColorComponents[0], green: eventColorComponents[1], blue: eventColorComponents[2], alpha: eventColorComponents[3]))
        }
        
        func themePrimaryColor() -> Color {
            guard themePrimaryColorComponents.count == 4 else { return .blue } // Default theme color
            return Color(UIColor(red: themePrimaryColorComponents[0], green: themePrimaryColorComponents[1], blue: themePrimaryColorComponents[2], alpha: themePrimaryColorComponents[3]))
        }
    }

    // Static attributes (can be empty if not needed for initial setup)
    // For example, you could put scheduleItemID here if it never changes for an activity instance.
    var creationDate: Date
}
