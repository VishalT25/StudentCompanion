import SwiftUI

enum ScheduleViewType: String, CaseIterable {
    case cards = "Cards"
    case timeline = "Timeline"
    case overview = "Overview"
    
    var icon: String {
        switch self {
        case .cards: return "rectangle.stack"
        case .timeline: return "timeline.selection"
        case .overview: return "calendar"
        }
    }
}

struct ScheduleView: View {
    @StateObject private var scheduleManager = ScheduleManager()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingScheduleManager = false
    @State private var showingAddClass = false
    @State private var selectedDay: DayOfWeek = DayOfWeek(rawValue: Calendar.current.component(.weekday, from: Date())) ?? .monday
    @State private var showingDayPicker = false
    @State private var viewType: ScheduleViewType = .cards
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    
                    if let activeSchedule = scheduleManager.activeSchedule {
                        switch viewType {
                        case .cards:
                            scheduleOverviewCard(activeSchedule)
                            dayScheduleView(activeSchedule)
                        case .timeline:
                            timelineView(activeSchedule)
                        case .overview:
                            fullWeekOverviewView(activeSchedule)
                        }
                    } else {
                        emptyStateView
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                // Refresh live activities or other schedule-related data
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                // Schedule Manager Button
                Button(action: { showingScheduleManager = true }) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline.bold())
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(14)
                        .background(Circle().fill(themeManager.currentTheme.secondaryColor.opacity(0.2)))
                        .overlay(Circle().stroke(themeManager.currentTheme.secondaryColor.opacity(0.4), lineWidth: 1))
                        .shadow(color: themeManager.currentTheme.secondaryColor.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                
                // Add Class Button
                Button(action: { showingAddClass = true }) {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Circle().fill(themeManager.currentTheme.primaryColor))
                        .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingScheduleManager) {
            ScheduleManagerView()
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddClass) {
            if let activeSchedule = scheduleManager.activeSchedule {
                EnhancedScheduleEditView(scheduleItem: nil, scheduleID: activeSchedule.id)
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
            }
        }
        .onAppear {
            print("🔍 ScheduleView appeared")
            print("🔍 Schedule collections count: \(scheduleManager.scheduleCollections.count)")
            print("🔍 Active schedule ID: \(scheduleManager.activeScheduleID?.uuidString ?? "nil")")
            if let activeSchedule = scheduleManager.activeSchedule {
                print("🔍 Active schedule: \(activeSchedule.displayName)")
                print("🔍 Schedule items count: \(activeSchedule.scheduleItems.count)")
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    
                    if let activeSchedule = scheduleManager.activeSchedule {
                        Text(activeSchedule.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // View Type Selector
            HStack(spacing: 8) {
                ForEach(ScheduleViewType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewType = type
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.caption.weight(.semibold))
                            Text(type.rawValue)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(viewType == type ? .white : themeManager.currentTheme.primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(viewType == type ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.primaryColor.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Timeline View
    private func timelineView(_ schedule: ScheduleCollection) -> some View {
        VStack(spacing: 16) {
            // Day selector for timeline view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        let dayClasses = schedule.scheduleItems.filter { $0.daysOfWeek.contains(day) }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDay = day
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(day.shortName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(selectedDay == day ? .white : .primary)
                                
                                Text("\(dayClasses.count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(selectedDay == day ? .white : themeManager.currentTheme.primaryColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDay == day ? themeManager.currentTheme.primaryColor : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Timeline for selected day
            TimelineScheduleView(schedule: schedule, selectedDay: selectedDay)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Full Week Overview
    private func fullWeekOverviewView(_ schedule: ScheduleCollection) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Week Overview")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Fall Session")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.currentTheme.tertiaryColor.opacity(0.5))
                    .cornerRadius(8)
            }
            
            WeeklyCalendarView(schedule: schedule)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func scheduleOverviewCard(_ schedule: ScheduleCollection) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(schedule.totalClasses)")
                        .font(.title.bold())
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    Text("Classes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f hrs", schedule.weeklyHours))
                        .font(.title.bold())
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    Text("Per Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Week overview
            weekOverviewGrid(schedule)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.currentTheme.quaternaryColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.1), radius: 12, x: 0, y: 6)
        )
    }
    
    private func weekOverviewGrid(_ schedule: ScheduleCollection) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                let dayClasses = schedule.scheduleItems.filter { $0.daysOfWeek.contains(day) }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDay = day
                    }
                }) {
                    VStack(spacing: 6) {
                        Text(day.shortName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selectedDay == day ? .white : .primary)
                        
                        Text("\(dayClasses.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(selectedDay == day ? .white : themeManager.currentTheme.primaryColor)
                    }
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedDay == day ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.tertiaryColor.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedDay == day ? themeManager.currentTheme.primaryColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func dayScheduleView(_ schedule: ScheduleCollection) -> some View {
        let dayClasses = schedule.scheduleItems
            .filter { $0.daysOfWeek.contains(selectedDay) }
            .sorted { $0.startTime < $1.startTime }
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(selectedDay.shortName) Schedule")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !dayClasses.isEmpty {
                    Text("\(dayClasses.count) class\(dayClasses.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.currentTheme.tertiaryColor.opacity(0.5))
                        .cornerRadius(8)
                }
            }
            
            if dayClasses.isEmpty {
                EmptyDayView(day: selectedDay.shortName)
                    .environmentObject(themeManager)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dayClasses) { item in
                        BeautifulScheduleRow(
                            item: item,
                            selectedDay: selectedDay,
                            scheduleID: schedule.id
                        )
                        .environmentObject(scheduleManager)
                        .environmentObject(themeManager)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Schedule Found")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Create your first schedule to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingScheduleManager = true }) {
                Text("Create Schedule")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Timeline Schedule View
struct TimelineScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let schedule: ScheduleCollection
    let selectedDay: DayOfWeek
    
    private let timeSlots: [String] = {
        var slots: [String] = []
        for hour in 7...22 {
            let time = String(format: "%02d:00", hour)
            slots.append(time)
        }
        return slots
    }()
    
    var body: some View {
        let dayClasses = schedule.scheduleItems
            .filter { $0.daysOfWeek.contains(selectedDay) }
            .sorted { $0.startTime < $1.startTime }
        
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(selectedDay.displayName) Timeline")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !dayClasses.isEmpty {
                    Text("\(dayClasses.count) class\(dayClasses.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            if dayClasses.isEmpty {
                EmptyDayView(day: selectedDay.shortName)
                    .environmentObject(themeManager)
                    .padding(.horizontal, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(timeSlots, id: \.self) { timeSlot in
                            TimeSlotRow(
                                timeSlot: timeSlot,
                                classes: dayClasses,
                                scheduleID: schedule.id,
                                selectedDay: selectedDay
                            )
                            .environmentObject(scheduleManager)
                            .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 600)
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Time Slot Row
struct TimeSlotRow: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let timeSlot: String
    let classes: [ScheduleItem]
    let scheduleID: UUID
    let selectedDay: DayOfWeek
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var hour: Int {
        Int(timeSlot.prefix(2)) ?? 0
    }
    
    private var classesInThisHour: [ScheduleItem] {
        classes.filter { item in
            let startHour = Calendar.current.component(.hour, from: item.startTime)
            let endHour = Calendar.current.component(.hour, from: item.endTime)
            return hour >= startHour && hour < endHour
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time label
            VStack(spacing: 2) {
                Text(timeSlot)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                
                if hour < 22 {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 1, height: 40)
                }
            }
            
            // Classes content
            VStack(spacing: 8) {
                if classesInThisHour.isEmpty {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                } else {
                    ForEach(classesInThisHour) { item in
                        TimelineClassCard(
                            item: item,
                            scheduleID: scheduleID,
                            selectedDay: selectedDay
                        )
                        .environmentObject(scheduleManager)
                        .environmentObject(themeManager)
                    }
                }
                
                if hour < 22 {
                    Divider()
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Timeline Class Card
struct TimelineClassCard: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let scheduleID: UUID
    let selectedDay: DayOfWeek
    @State private var showingEditSheet = false
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var instanceDateForSelectedDay: Date {
        let calendar = Calendar.current
        let today = Date()
        
        if selectedDay.rawValue == Calendar.current.component(.weekday, from: Date()) {
            return Calendar.current.startOfDay(for: Date())
        }
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = selectedDay.rawValue
        return calendar.date(from: components) ?? today
    }
    
    private var isSkipped: Bool {
        item.isSkipped(onDate: instanceDateForSelectedDay)
    }
    
    private var timeRange: String {
        let startTime = timeFormatter.string(from: item.startTime)
        let endTime = timeFormatter.string(from: item.endTime)
        return "\(startTime) - \(endTime)"
    }
    
    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack(spacing: 12) {
                // Color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSkipped ? Color.secondary.opacity(0.4) : item.color)
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isSkipped ? .secondary : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isSkipped {
                            Text("SKIPPED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(timeRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scheduleManager.toggleSkip(forItem: item, onDate: instanceDateForSelectedDay, in: scheduleID)
                    }
                }) {
                    Image(systemName: isSkipped ? "arrow.clockwise" : "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(isSkipped ? .green : .orange)
                        .padding(8)
                        .background(
                            Circle()
                                .fill((isSkipped ? Color.green : Color.orange).opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSkipped ? Color(.systemGray6).opacity(0.5) : item.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((isSkipped ? Color.secondary : item.color).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            EnhancedScheduleEditView(scheduleItem: item, scheduleID: scheduleID)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Weekly Calendar View
struct WeeklyCalendarView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let schedule: ScheduleCollection
    
    private let timeSlots: [String] = {
        var slots: [String] = []
        for hour in 7...22 {
            slots.append(String(format: "%d:00 %@", hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour), hour >= 12 ? "PM" : "AM"))
        }
        return slots
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with days
            HStack(spacing: 0) {
                Text("Time")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                ForEach(DayOfWeek.weekdays, id: \.self) { day in
                    Text(day.shortName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(timeSlots.enumerated()), id: \.offset) { index, timeSlot in
                        CalendarTimeRow(
                            timeSlot: timeSlot,
                            hour: index + 7,
                            schedule: schedule
                        )
                        .environmentObject(scheduleManager)
                        .environmentObject(themeManager)
                    }
                }
            }
            .frame(maxHeight: 500)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - Calendar Time Row
struct CalendarTimeRow: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let timeSlot: String
    let hour: Int
    let schedule: ScheduleCollection
    
    var body: some View {
        HStack(spacing: 0) {
            // Time label
            Text(timeSlot)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Days
            ForEach(DayOfWeek.weekdays, id: \.self) { day in
                let classesInThisSlot = schedule.scheduleItems.filter { item in
                    item.daysOfWeek.contains(day) &&
                    Calendar.current.component(.hour, from: item.startTime) <= hour &&
                    Calendar.current.component(.hour, from: item.endTime) > hour
                }
                
                VStack(spacing: 2) {
                    if classesInThisSlot.isEmpty {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 30)
                    } else {
                        ForEach(classesInThisSlot.prefix(1)) { item in
                            CalendarClassBlock(item: item, scheduleID: schedule.id)
                                .environmentObject(scheduleManager)
                                .environmentObject(themeManager)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                )
            }
        }
        .frame(height: 30)
    }
}

// MARK: - Calendar Class Block
struct CalendarClassBlock: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let scheduleID: UUID
    @State private var showingEditSheet = false
    
    var body: some View {
        Button(action: { showingEditSheet = true }) {
            VStack(spacing: 1) {
                Text(item.title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text("LEC 001")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(item.color)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            EnhancedScheduleEditView(scheduleItem: item, scheduleID: scheduleID)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Extensions
extension DayOfWeek {
    static let weekdays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    
    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct BeautifulScheduleRow: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let selectedDay: DayOfWeek
    let scheduleID: UUID
    @State private var showingEditSheet = false
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var instanceDateForSelectedDay: Date {
        let calendar = Calendar.current
        let today = Date()
        
        if selectedDay.rawValue == Calendar.current.component(.weekday, from: Date()) {
            return Calendar.current.startOfDay(for: Date())
        }
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = selectedDay.rawValue
        return calendar.date(from: components) ?? today
    }
    
    private var isSkipped: Bool {
        item.isSkipped(onDate: instanceDateForSelectedDay)
    }
    
    private var duration: String {
        let interval = item.endTime.timeIntervalSince(item.startTime)
        let hours = Int(interval) / 3600
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var timeRange: String {
        let startTime = timeFormatter.string(from: item.startTime)
        let endTime = timeFormatter.string(from: item.endTime)
        return "\(startTime) - \(endTime)"
    }
    
    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack(spacing: 16) {
                // Color indicator bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSkipped ? Color.secondary.opacity(0.4) : item.color)
                    .frame(width: 4, height: 50)
                
                // Main content
                VStack(alignment: .leading, spacing: 6) {
                    // Title and skip indicator
                    HStack {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(isSkipped ? .secondary : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isSkipped {
                            Text("SKIPPED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    // Time and duration info
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeRange)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Days indicator
                        Text(daysText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(item.color.opacity(0.15))
                            .foregroundColor(item.color)
                            .cornerRadius(6)
                    }
                }
                
                // Action button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scheduleManager.toggleSkip(forItem: item, onDate: instanceDateForSelectedDay, in: scheduleID)
                    }
                }) {
                    Image(systemName: isSkipped ? "arrow.clockwise" : "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(isSkipped ? .green : .orange)
                        .padding(10)
                        .background(
                            Circle()
                                .fill((isSkipped ? Color.green : Color.orange).opacity(0.15))
                                .overlay(
                                    Circle()
                                        .stroke((isSkipped ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSkipped ? Color(.systemGray6).opacity(0.5) : themeManager.currentTheme.quaternaryColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke((isSkipped ? Color.secondary : item.color).opacity(0.2), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
            .opacity(isSkipped ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            EnhancedScheduleEditView(scheduleItem: item, scheduleID: scheduleID)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
    
    private var daysText: String {
        let allDays: Set<DayOfWeek> = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekends: Set<DayOfWeek> = [.saturday, .sunday]
        
        if item.daysOfWeek == allDays {
            return "Daily"
        } else if item.daysOfWeek == weekdays {
            return "Weekdays"
        } else if item.daysOfWeek == weekends {
            return "Weekends"
        } else if item.daysOfWeek.count > 3 {
            return "\(item.daysOfWeek.count) days"
        } else {
            return Array(item.daysOfWeek).sorted(by: { $0.rawValue < $1.rawValue }).map { $0.shortName }.joined(separator: ", ")
        }
    }
}

struct EmptyDayView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let day: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Free Day!")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("No classes scheduled for \(day)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.tertiaryColor.opacity(0.3))
        )
    }
}

struct DayButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Day abbreviation with better styling
                Text(day.shortName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Active indicator with animation
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.9) : themeColor.opacity(0.4))
                    .frame(width: 5, height: 5)
                    .scaleEffect(isSelected ? 1.2 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? 
                          LinearGradient(
                            colors: [themeColor, themeColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ) : 
                          LinearGradient(
                            colors: [Color(.systemGray6), Color(.systemGray5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? 
                                themeColor.opacity(0.6) : 
                                Color(.systemGray4).opacity(0.5), 
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? 
                        themeColor.opacity(0.3) : 
                        Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 2,
                        x: 0,
                        y: isSelected ? 4 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}