import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @State private var showingAddSchedule = false
    @State private var selectedSchedule: ScheduleItem?
    var onNavigateToSchedule: (() -> Void)? = nil
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Schedule")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Group {
                    if let onNavigateToSchedule {
                        Button(action: onNavigateToSchedule) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.white)
                                .font(.forma(.title3))
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: AppRoute.schedule) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.white)
                                .font(.forma(.title3))
                        }
                    }
                }
            }
            
            let schedule = todaysScheduleItems()
            
            if schedule.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Nothing scheduled for today")
                        .font(.forma(.body))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Enjoy your free day!")
                        .font(.forma(.caption))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(schedule) { item in
                        CompactScheduleItemView(item: item, scheduleID: activeScheduleID())
                            .environmentObject(themeManager)
                            .environmentObject(scheduleManager)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.primaryColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func todaysScheduleItems() -> [ScheduleItem] {
        guard let activeSchedule = scheduleManager.activeSchedule else {
            return []
        }
        
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)
        
        // Skip weekends
        if weekday == 1 || weekday == 7 {
            return []
        }
        
        // Check semester bounds
        if let start = activeSchedule.semesterStartDate,
           let end = activeSchedule.semesterEndDate {
            let d = cal.startOfDay(for: today)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if d < s || d > e {
                return []
            }
        }
        
        let academicCalendar = scheduleManager.getAcademicCalendar(for: activeSchedule, from: academicCalendarManager)
        
        // Check if today is a break day
        if let calendar = academicCalendar, calendar.isBreakDay(today) {
            return []
        }
        
        // Get schedule items ONLY from course meetings - NO MORE LEGACY SCHEDULE ITEMS
        var allItems: [ScheduleItem] = []
        let coursesInSchedule = courseManager.courses.filter { $0.scheduleId == activeSchedule.id }
        
        print("🔍 TodaySchedule DEBUG: Found \(coursesInSchedule.count) courses for schedule \(activeSchedule.id)")
        
        for course in coursesInSchedule {
            print("🔍 TodaySchedule DEBUG: Course '\(course.name)' has \(course.meetings.count) meetings")
            
            for meeting in course.meetings {
                if meeting.shouldAppear(on: today, in: activeSchedule, calendar: academicCalendar) {
                    let item = ScheduleItem(
                        id: meeting.id,
                        title: "\(course.name) - \(meeting.displayName)",
                        startTime: meeting.startTime,
                        endTime: meeting.endTime,
                        daysOfWeek: meeting.daysOfWeek.compactMap { DayOfWeek(rawValue: $0) },
                        location: meeting.location.isEmpty ? course.location : meeting.location,
                        instructor: meeting.instructor.isEmpty ? course.instructor : meeting.instructor,
                        color: course.color,
                        skippedInstanceIdentifiers: meeting.skippedInstanceIdentifiers,
                        isLiveActivityEnabled: meeting.isLiveActivityEnabled,
                        reminderTime: meeting.reminderTime
                    )
                    allItems.append(item)
                    print("🔍 TodaySchedule DEBUG: Added meeting '\(meeting.displayName)' for today")
                } else {
                    print("🔍 TodaySchedule DEBUG: Meeting '\(meeting.displayName)' should NOT appear today")
                }
            }
        }
        
        print("🔍 TodaySchedule DEBUG: Total items for today: \(allItems.count)")
        
        // Filter out invalid items and sort by start time
        return allItems
            .filter { $0.endTime > $0.startTime }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private func activeScheduleID() -> UUID? {
        return scheduleManager.activeScheduleID
    }
}

struct CompactScheduleItemView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let scheduleID: UUID?
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var scheduleDisplayText: String? {
        let allDays: Set<DayOfWeek> = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekends: Set<DayOfWeek> = [.saturday, .sunday]
        
        let daysSet = Set(item.daysOfWeek)
        
        if daysSet == allDays {
            return "Daily"
        } else if daysSet == weekdays {
            return "Weekdays"
        } else if daysSet == weekends {
            return "Weekends"
        } else if daysSet.count > 4 {
            return "\(daysSet.count) days"
        } else if daysSet.count == 1 {
            return Array(daysSet).first?.short ?? ""
        } else {
            let sortedDays = Array(daysSet).sorted(by: { $0.rawValue < $1.rawValue })
            return sortedDays.map { $0.short }.joined(separator: ", ")
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                
                if let endTime = timeFormatter.string(from: item.endTime) != timeFormatter.string(from: item.startTime) ? timeFormatter.string(from: item.endTime) : nil {
                    Text(endTime)
                        .font(.forma(.caption))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 60, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.forma(.body, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if item.reminderTime != .none {
                        Image(systemName: "bell.fill")
                            .font(.forma(.caption2))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                if !item.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.forma(.caption2))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(item.location)
                            .font(.forma(.caption))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                if item.isSkipped(onDate: Date()) {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                            .font(.forma(.caption2))
                            .foregroundColor(.orange)
                        
                        Text("SKIPPED")
                            .font(.forma(.caption2, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if let displayText = scheduleDisplayText {
                Text(displayText)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.2))
                    )
            }
        }
        .padding(.vertical, 8)
        .opacity(item.isSkipped(onDate: Date()) ? 0.6 : 1.0)
        .contextMenu {
            Button {
                if let scheduleID = scheduleID {
                    scheduleManager.toggleSkip(forItem: item, onDate: Date(), in: scheduleID)
                }
            } label: {
                Label(item.isSkipped(onDate: Date()) ? "Unskip for Today" : "Skip for Today",
                      systemImage: item.isSkipped(onDate: Date()) ? "arrow.clockwise" : "xmark.circle.fill")
            }
        }
    }
}

struct CompactEventItemView: View {
    @EnvironmentObject var viewModel: EventViewModel
    let event: Event
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(timeFormatter.string(from: event.date))
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 60, alignment: .leading)
            
            HStack(spacing: 8) {
                Text(event.title)
                    .font(.forma(.body))
                    .foregroundColor(.white)
                
                if event.reminderTime != .none {
                    Image(systemName: "bell.fill")
                        .font(.forma(.caption2))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.markEventCompleted(event)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.forma(.title3))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

extension ScheduleItem {
    private func daysString(for item: ScheduleItem) -> String {
        let sortedDays = Array(item.daysOfWeek).sorted { $0.rawValue < $1.rawValue }
        
        switch sortedDays.count {
        case 0:
            return "No days"
        case 1:
            return Array(item.daysOfWeek).first?.full ?? ""
        case 2...4:
            return sortedDays.map { $0.short }.joined(separator: ", ")
        default:
            return "Multiple days"
        }
    }
}