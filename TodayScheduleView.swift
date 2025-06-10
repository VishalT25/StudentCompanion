import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddSchedule = false
    @State private var selectedSchedule: ScheduleItem?
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Schedule")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink(value: AppRoute.schedule) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                        .background(Circle().fill(.white.opacity(0.2)).frame(width: 32, height: 32))
                }
            }
            
            let schedule = viewModel.todaysSchedule()
            let events = viewModel.todaysEvents()
            
            if schedule.isEmpty && events.isEmpty {
                Text("Nothing scheduled for today")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !schedule.isEmpty {
                        ForEach(schedule) { item in
                            CompactScheduleItemView(item: item)
                        }
                    }
                    
                    if !events.isEmpty {
                        if !schedule.isEmpty {
                            Divider()
                                .background(.white.opacity(0.3))
                                .padding(.vertical, 2)
                        }
                        
                        Text("Today's Events")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        ForEach(events) { event in
                            CompactEventItemView(event: event)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.9),
                    themeManager.currentTheme.primaryColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CompactScheduleItemView: View {
    @EnvironmentObject var viewModel: EventViewModel
    let item: ScheduleItem
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var scheduleDisplayText: String? {
        let allDays: Set<DayOfWeek> = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekends: Set<DayOfWeek> = [.saturday, .sunday]
        
        if item.daysOfWeek == allDays {
            return "Daily"
        } else if item.daysOfWeek == weekdays {
            return "Weekdays"
        } else if item.daysOfWeek == weekends {
            return "Weekends"
        } else if item.daysOfWeek.count > 4 {
            return "\(item.daysOfWeek.count) days"
        } else if item.daysOfWeek.count == 1 {
            return Array(item.daysOfWeek).first?.shortName ?? ""
        } else {
            let sortedDays = Array(item.daysOfWeek).sorted(by: { $0.rawValue < $1.rawValue })
            return sortedDays.map { $0.shortName }.joined(separator: ", ")
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(timeFormatter.string(from: item.startTime))
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout)
                    .foregroundColor(.white)
                
                if item.isSkippedForCurrentWeek() {
                    Text("SKIPPED THIS WEEK")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            
            Spacer()
            
            if let displayText = scheduleDisplayText {
                Text(displayText)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.15))
                    .cornerRadius(6)
            }
            
            RoundedRectangle(cornerRadius: 2)
                .fill(item.isSkippedForCurrentWeek() ? .white.opacity(0.3) : item.color)
                .frame(width: 3, height: 20)
        }
        .padding(.vertical, 4)
        .opacity(item.isSkippedForCurrentWeek() ? 0.6 : 1.0)
    }
}

struct CompactEventItemView: View {
    let event: Event
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(timeFormatter.string(from: event.date))
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
            
            Text(event.title)
                .font(.callout)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
