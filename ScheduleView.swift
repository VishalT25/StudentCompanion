import SwiftUI

enum ScheduleViewType: String, CaseIterable {
    case cards = "Cards"
    case timeline = "Timeline"
    
    var icon: String {
        switch self {
        case .cards: return "rectangle.stack"
        case .timeline: return "timeline.selection"
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
            ZStack {
                // Main scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        
                        if let activeSchedule = scheduleManager.activeSchedule {
                            switch viewType {
                            case .cards:
                                scheduleOverviewCard(activeSchedule)
                                dayScheduleView(activeSchedule)
                            case .timeline:
                                VStack(spacing: 20) {
                                    // Day selector (temporary simplified version)
                                    VStack(spacing: 16) {
                                        HStack {
                                            Text("Daily Timeline")
                                                .font(.headline.weight(.semibold))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            let dayClasses = activeSchedule.scheduleItems.filter { $0.daysOfWeek.contains(selectedDay) }
                                            if !dayClasses.isEmpty {
                                                Text("\(dayClasses.count) items")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                                    )
                                            }
                                        }
                                        
                                        // Day selector buttons
                                        HStack(spacing: 8) {
                                            ForEach(DayOfWeek.allCases, id: \.self) { day in
                                                let dayClasses = activeSchedule.scheduleItems.filter { $0.daysOfWeek.contains(day) }
                                                let isSelected = selectedDay == day
                                                
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                        selectedDay = day
                                                    }
                                                }) {
                                                    VStack(spacing: 4) {
                                                        Text(day.shortName)
                                                            .font(.caption.weight(.semibold))
                                                            .foregroundColor(isSelected ? .white : .primary)
                                                        
                                                        Text("\(dayClasses.count)")
                                                            .font(.caption2.weight(.bold))
                                                            .foregroundColor(isSelected ? .white : themeManager.currentTheme.primaryColor)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(isSelected ? themeManager.currentTheme.primaryColor : Color(.systemGray6))
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    )
                                    
                                    // Timeline view
                                    TimelineView(schedule: activeSchedule, selectedDay: selectedDay)
                                        .environmentObject(scheduleManager)
                                        .environmentObject(themeManager)
                                }
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
                
                // Fixed floating action buttons
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
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
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
                
                // View Type Selector - icons only
                HStack(spacing: 6) {
                    ForEach(ScheduleViewType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewType = type
                            }
                        }) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(viewType == type ? .white : themeManager.currentTheme.primaryColor)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewType == type ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.primaryColor.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
        }
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
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
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
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSkipped ? Color.secondary.opacity(0.4) : item.color)
                    .frame(width: 4, height: 50)
                
                VStack(alignment: .leading, spacing: 6) {
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
                        
                        Text(daysText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(item.color.opacity(0.15))
                            .foregroundColor(item.color)
                            .cornerRadius(6)
                    }
                }
                
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
                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6));
            
            VStack(spacing: 8) {
                Text("Free Day!")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("No items scheduled for \(day)")
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

// MARK: - Timeline View
struct TimelineView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let schedule: ScheduleCollection
    let selectedDay: DayOfWeek
    
    private var dayClasses: [ScheduleItem] {
        schedule.scheduleItems
            .filter { $0.daysOfWeek.contains(selectedDay) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    // Calculate the time range for the timeline
    private var timeRange: (start: Date, end: Date) {
        guard !dayClasses.isEmpty else {
            // Default range: 8 AM to 6 PM
            let calendar = Calendar.current
            let now = Date()
            let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
            let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            return (start, end)
        }
        
        let firstClass = dayClasses.first!
        let lastClass = dayClasses.last!
        
        let calendar = Calendar.current
        
        // Start one hour before first class, rounded down to nearest hour
        let startHour = calendar.component(.hour, from: firstClass.startTime)
        let startMinute = calendar.component(.minute, from: firstClass.startTime)
        
        // Go back 1 hour and round down to the nearest hour
        let paddedStartHour = startHour - 1
        let start = calendar.date(bySettingHour: paddedStartHour, minute: 0, second: 0, of: firstClass.startTime) ?? firstClass.startTime
        
        // End one hour after last class, rounded up to nearest hour
        let endHour = calendar.component(.hour, from: lastClass.endTime)
        let endMinute = calendar.component(.minute, from: lastClass.endTime)
        
        // Go forward 1-2 hours and round up to the nearest hour
        let paddedEndHour = endHour + (endMinute > 0 ? 2 : 1)
        let end = calendar.date(bySettingHour: paddedEndHour, minute: 0, second: 0, of: lastClass.endTime) ?? lastClass.endTime
        
        return (start, end)
    }
    
    // Generate time slots (30-minute intervals)
    private var timeSlots: [Date] {
        let calendar = Calendar.current
        var slots: [Date] = []
        var current = timeRange.start
        
        while current <= timeRange.end {
            slots.append(current)
            current = calendar.date(byAdding: .minute, value: 30, to: current) ?? current
        }
        
        return slots
    }
    
    // Height per 30-minute slot
    private let slotHeight: CGFloat = 40
    
    // Convert time to Y position
    private func yPosition(for date: Date) -> CGFloat {
        let timeInterval = date.timeIntervalSince(timeRange.start)
        let thirtyMinuteSlots = timeInterval / (30 * 60)
        return CGFloat(thirtyMinuteSlots) * slotHeight
    }
    
    // Calculate height for a class duration
    private func height(for item: ScheduleItem) -> CGFloat {
        let duration = item.endTime.timeIntervalSince(item.startTime)
        let thirtyMinuteSlots = duration / (30 * 60)
        return CGFloat(thirtyMinuteSlots) * slotHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(selectedDay.displayName)")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !dayClasses.isEmpty {
                    let firstClass = dayClasses.first!
                    let lastClass = dayClasses.last!
                    
                    Text("\(timeFormatter.string(from: firstClass.startTime)) - \(timeFormatter.string(from: lastClass.endTime))")
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
                // Single unified timeline view - no inner ScrollView
                ZStack(alignment: .topLeading) {
                    // Time axis background
                    VStack(spacing: 0) {
                        ForEach(Array(timeSlots.enumerated()), id: \.offset) { index, timeSlot in
                            HStack {
                                // Time label
                                Text(timeFormatter.string(from: timeSlot))
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                                
                                // Grid line
                                Rectangle()
                                    .fill(Color.secondary.opacity(index % 2 == 0 ? 0.2 : 0.1))
                                    .frame(height: 1)
                            }
                            .frame(height: slotHeight)
                        }
                    }
                    
                    // Class blocks and gaps overlay
                    HStack(alignment: .top, spacing: 0) {
                        // Time column spacer
                        Spacer()
                            .frame(width: 76)
                        
                        // Content area
                        ZStack(alignment: .topLeading) {
                            // Background for content area
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: CGFloat(timeSlots.count) * slotHeight)
                            
                            // Class blocks
                            ForEach(dayClasses) { item in
                                TimelineClassBlock(
                                    item: item,
                                    scheduleID: schedule.id,
                                    selectedDay: selectedDay,
                                    yOffset: yPosition(for: item.startTime),
                                    blockHeight: height(for: item)
                                )
                                .environmentObject(scheduleManager)
                                .environmentObject(themeManager)
                            }
                            
                            // Gap indicators
                            ForEach(Array(gapElements.enumerated()), id: \.offset) { _, gap in
                                TimelineGapIndicator(
                                    startTime: gap.startTime,
                                    endTime: gap.endTime,
                                    duration: gap.duration,
                                    yOffset: yPosition(for: gap.startTime),
                                    gapHeight: yPosition(for: gap.endTime) - yPosition(for: gap.startTime)
                                )
                                .environmentObject(themeManager)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // Calculate gaps between classes
    private var gapElements: [(startTime: Date, endTime: Date, duration: TimeInterval)] {
        var gaps: [(startTime: Date, endTime: Date, duration: TimeInterval)] = []
        
        for i in 0..<(dayClasses.count - 1) {
            let currentClass = dayClasses[i]
            let nextClass = dayClasses[i + 1]
            let gapDuration = nextClass.startTime.timeIntervalSince(currentClass.endTime)
            
            if gapDuration > 0 {
                gaps.append((
                    startTime: currentClass.endTime,
                    endTime: nextClass.startTime,
                    duration: gapDuration
                ))
            }
        }
        
        return gaps
    }
}

// MARK: - Timeline Class Block
struct TimelineClassBlock: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let scheduleID: UUID
    let selectedDay: DayOfWeek
    let yOffset: CGFloat
    let blockHeight: CGFloat
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
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSkipped ? Color.secondary.opacity(0.4) : item.color)
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
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
                    
                    HStack {
                        Text("\(timeFormatter.string(from: item.startTime)) - \(timeFormatter.string(from: item.endTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(duration)
                            .font(.caption.weight(.medium))
                            .foregroundColor(item.color)
                    }
                    
                    if blockHeight > 80 {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    scheduleManager.toggleSkip(forItem: item, onDate: instanceDateForSelectedDay, in: scheduleID)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isSkipped ? "arrow.clockwise" : "xmark")
                                        .font(.caption.weight(.bold))
                                    Text(isSkipped ? "Restore" : "Skip")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundColor(isSkipped ? .green : .orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill((isSkipped ? Color.green : Color.orange).opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke((isSkipped ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: blockHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSkipped ?
                        LinearGradient(
                            colors: [Color(.systemGray6).opacity(0.5), Color(.systemGray6).opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [item.color.opacity(0.1), item.color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                (isSkipped ? Color.secondary : item.color).opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            )
            .opacity(isSkipped ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .offset(y: yOffset)
        .sheet(isPresented: $showingEditSheet) {
            EnhancedScheduleEditView(scheduleItem: item, scheduleID: scheduleID)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Timeline Gap Indicator
struct TimelineGapIndicator: View {
    @EnvironmentObject var themeManager: ThemeManager
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let yOffset: CGFloat
    let gapHeight: CGFloat
    
    private var gapDurationText: String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Dynamic layout based on available height
    private var layoutStyle: GapLayoutStyle {
        if gapHeight < 25 {
            return .minimal
        } else if gapHeight < 45 {
            return .compact
        } else {
            return .full
        }
    }
    
    private enum GapLayoutStyle {
        case minimal   // Just dots
        case compact   // Duration only
        case full      // Full layout with label
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Dotted line - always present
            VStack(spacing: 3) {
                ForEach(0..<Int(max(1, gapHeight / 8)), id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 2)
                }
            }
            .frame(width: 4)
            
            // Dynamic content based on available space
            Group {
                switch layoutStyle {
                case .minimal:
                    // Just a thin indicator for very small gaps
                    EmptyView()
                    
                case .compact:
                    // Duration only for medium gaps
                    Text(gapDurationText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        )
                    
                case .full:
                    // Full layout for larger gaps
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.badge")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            Text("Break")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(gapDurationText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6).opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        Color.secondary.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                    )
                            )
                    )
                }
            }
            
            Spacer()
        }
        .frame(height: gapHeight)
        .offset(y: yOffset)
    }
}

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