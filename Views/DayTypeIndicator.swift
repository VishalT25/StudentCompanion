import SwiftUI

struct DayTypeIndicator: View {
    let schedule: ScheduleCollection
    let date: Date
    @EnvironmentObject var themeManager: ThemeManager
    
    private var dayType: String? {
        guard schedule.scheduleType.supportsRotation,
              let pattern = schedule.rotationPattern else {
            return nil
        }
        
        // Check if it's a break day
        if let calendar = schedule.academicCalendar, calendar.isBreakDay(date) {
            return nil
        }
        
        return pattern.dayType(for: date)
    }
    
    private var breakInfo: AcademicBreak? {
        schedule.academicCalendar?.breakForDate(date)
    }
    
    var body: some View {
        Group {
            if let breakInfo = breakInfo {
                breakDayView(break: breakInfo)
            } else if let dayType = dayType {
                rotatingDayView(dayType: dayType)
            } else if schedule.scheduleType == .traditional {
                traditionalDayView
            } else {
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private func breakDayView(break: AcademicBreak) -> some View {
        HStack(spacing: 12) {
            Image(systemName: `break`.type.icon)
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(`break`.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(`break`.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("BREAK")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func rotatingDayView(dayType: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.primaryColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(String(dayType.prefix(1)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dayType)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(schedule.scheduleType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let nextDayType = getNextDayType() {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tomorrow")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(nextDayType)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.primaryColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var traditionalDayView: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(longDayName(from: date))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Traditional Schedule")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func longDayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func getNextDayType() -> String? {
        guard let pattern = schedule.rotationPattern else { return nil }
        
        let calendar = Calendar.current
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        // Skip weekends and breaks
        for _ in 0..<7 { // Max 7 iterations to avoid infinite loop
            if let academicCalendar = schedule.academicCalendar {
                if !academicCalendar.isBreakDay(nextDate) {
                    let weekday = calendar.component(.weekday, from: nextDate)
                    if weekday != 1 && weekday != 7 { // Not weekend
                        return pattern.dayType(for: nextDate)
                    }
                }
            } else {
                let weekday = calendar.component(.weekday, from: nextDate)
                if weekday != 1 && weekday != 7 { // Not weekend
                    return pattern.dayType(for: nextDate)
                }
            }
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        return nil
    }
}

// Compact version for smaller spaces
struct CompactDayTypeIndicator: View {
    let schedule: ScheduleCollection
    let date: Date
    @EnvironmentObject var themeManager: ThemeManager
    
    private var dayType: String? {
        guard schedule.scheduleType.supportsRotation,
              let pattern = schedule.rotationPattern,
              let calendar = schedule.academicCalendar,
              !calendar.isBreakDay(date) else {
            return nil
        }
        
        return pattern.dayType(for: date)
    }
    
    private var isBreakDay: Bool {
        schedule.academicCalendar?.isBreakDay(date) ?? false
    }
    
    var body: some View {
        Group {
            if isBreakDay {
                Label("Break", systemImage: "sun.max.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if let dayType = dayType {
                Label(dayType, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DayTypeIndicator(
            schedule: ScheduleCollection(
                name: "Test Schedule",
                semester: "Fall 2024",
                scheduleType: .rotatingDays
            ),
            date: Date()
        )
        .environmentObject(ThemeManager())
        
        CompactDayTypeIndicator(
            schedule: ScheduleCollection(
                name: "Test Schedule", 
                semester: "Fall 2024",
                scheduleType: .rotatingDays
            ),
            date: Date()
        )
        .environmentObject(ThemeManager())
    }
    .padding()
}