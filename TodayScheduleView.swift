import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager // NEW
    @StateObject private var scheduleManager = ScheduleManager()
    @State private var showingAddSchedule = false
    @State private var selectedSchedule: ScheduleItem?
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Schedule")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                NavigationLink(value: AppRoute.schedule) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.white)
                        .font(.forma(.title2))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .shadow(color: themeManager.currentTheme.darkModeAccentHue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
            }
            
            let schedule = todaysScheduleItems()
            let events = viewModel.todaysEvents()
            
            if schedule.isEmpty && events.isEmpty {
                VStack(spacing: 6) {
                    Text("Nothing scheduled for today")
                        .font(.forma(.subheadline))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if !schedule.isEmpty {
                        ForEach(schedule) { item in
                            CompactScheduleItemView(item: item, scheduleID: activeScheduleID())
                                .environmentObject(themeManager)
                                .environmentObject(scheduleManager)
                        }
                    }
                    
                    if !events.isEmpty {
                        if !schedule.isEmpty {
                            Divider()
                                .background(.white.opacity(0.4))
                                .padding(.vertical, 4)
                        }
                        
                        Text("Today's Events")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        ForEach(events) { event in
                            CompactEventItemView(event: event)
                                .environmentObject(viewModel)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.95),
                    themeManager.currentTheme.primaryColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // ADAPTIVE DARK MODE EFFECTS WITH INTENSITY CONTROL
        .adaptiveWidgetDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
    }
    
    // Helper method to get today's schedule items from ScheduleManager
    private func todaysScheduleItems() -> [ScheduleItem] {
        guard let activeSchedule = scheduleManager.activeSchedule else {
            return []
        }
        let academicCalendar = scheduleManager.getAcademicCalendar(for: activeSchedule, from: academicCalendarManager) // NEW
        return activeSchedule.getScheduleItems(for: Date(), usingCalendar: academicCalendar) // UPDATED
    }
    
    // Helper method to get active schedule ID
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
        HStack(alignment: .center, spacing: 12) {
            Text(timeFormatter.string(from: item.startTime))
                .font(.forma(.callout, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.forma(.callout, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                    
                    if item.reminderTime != .none {
                        Image(systemName: "bell.fill")
                            .font(.forma(.caption))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }
                
                if item.isSkipped(onDate: Date()) {
                    Text("SKIPPED TODAY")
                        .font(.forma(.caption2, weight: .bold))
                        .foregroundColor(.orange)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
            
            Spacer()
            
            if let displayText = scheduleDisplayText {
                Text(displayText)
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            
            RoundedRectangle(cornerRadius: 3)
                .fill(item.isSkipped(onDate: Date()) ? .white.opacity(0.4) : item.color)
                .frame(width: 4, height: 24)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .padding(.vertical, 6)
        .opacity(item.isSkipped(onDate: Date()) ? 0.7 : 1.0)
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
        HStack(alignment: .center, spacing: 8) {
            Text(timeFormatter.string(from: event.date))
                .font(.forma(.callout))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(spacing: 6) {
                Text(event.title)
                    .font(.forma(.callout))
                    .foregroundColor(.white)
                
                if event.reminderTime != .none {
                    Image(systemName: "bell.fill")
                        .font(.forma(.caption))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.markEventCompleted(event)
            }) {
                Image(systemName: "checkmark.circle")
                    .font(.forma(.title2))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
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