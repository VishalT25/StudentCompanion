import SwiftUI

struct ScheduleTimelineView: View {
    let schedule: ScheduleCollection
    let weekDates: [Date]
    @Binding var selectedDate: Date
    
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager
    
    @State private var showingDetailForItem: ScheduleItem?
    @State private var scrollOffset: CGFloat = 0
    
    private var academicCalendar: AcademicCalendar? {
        scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager)
    }
    
    private var scheduleData: WeeklyScheduleData {
        WeeklyScheduleData(
            dates: weekDates,
            schedule: schedule,
            academicCalendar: academicCalendar
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with days
            dayHeaderSection
            
            // Main timeline content
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            timelineContent
                        }
                        .padding(.horizontal, 16)
                    }
                    .coordinateSpace(name: "scroll")
                    .onAppear {
                        // Scroll to current time
                        let now = Date()
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: now)
                        
                        if let targetSlot = scheduleData.timeSlots.first(where: { $0.hour >= hour }) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    proxy.scrollTo(targetSlot.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor.opacity(0.2),
                            themeManager.currentTheme.secondaryColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: themeManager.currentTheme.primaryColor.opacity(0.1),
            radius: 12, x: 0, y: 6
        )
        .sheet(item: $showingDetailForItem) { item in
            NavigationView {
                EnhancedCourseDetailView(
                    scheduleItem: item,
                    scheduleID: schedule.id
                )
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
            }
        }
    }
    
    private var dayHeaderSection: some View {
        HStack(spacing: 0) {
            // Time column spacer
            Rectangle()
                .fill(Color.clear)
                .frame(width: 60)
            
            // Day headers
            HStack(spacing: 0) {
                ForEach(Array(scheduleData.dailyData.enumerated()), id: \.offset) { index, dayData in
                    DayHeaderCell(
                        dayData: dayData,
                        isSelected: Calendar.current.isDate(dayData.date, inSameDayAs: selectedDate),
                        primaryColor: themeManager.currentTheme.primaryColor
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedDate = dayData.date
                        }
                    }
                    
                    if index < scheduleData.dailyData.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .frame(height: 60)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var timelineContent: some View {
        ForEach(scheduleData.timeSlots, id: \.id) { timeSlot in
            TimeSlotRow(
                timeSlot: timeSlot,
                dailyData: scheduleData.dailyData,
                selectedDate: selectedDate,
                primaryColor: themeManager.currentTheme.primaryColor,
                onEventTap: { item in
                    showingDetailForItem = item
                }
            )
            .id(timeSlot.id)
        }
    }
}

// MARK: - Data Models
struct WeeklyScheduleData {
    let dates: [Date]
    let schedule: ScheduleCollection
    let academicCalendar: AcademicCalendar?
    
    var dailyData: [DayData] {
        dates.map { date in
            let items = schedule.getScheduleItems(for: date, usingCalendar: academicCalendar)
                .sorted { $0.startTime < $1.startTime }
            return DayData(date: date, items: items)
        }
    }
    
    var timeSlots: [TimeSlot] {
        let allItems = dailyData.flatMap { $0.items }
        guard !allItems.isEmpty else {
            return (8...20).map { TimeSlot(hour: $0) }
        }
        
        let minHour = allItems.map { Calendar.current.component(.hour, from: $0.startTime) }.min() ?? 8
        let maxHour = allItems.map { 
            Calendar.current.component(.hour, from: $0.endTime) + 
            (Calendar.current.component(.minute, from: $0.endTime) > 0 ? 1 : 0)
        }.max() ?? 18
        
        // Ensure valid range with safety checks
        let start = max(6, min(minHour - 1, 22))
        let end = max(start + 2, min(23, maxHour + 1))
        
        // Double check to prevent crash
        guard start < end else {
            return (8...20).map { TimeSlot(hour: $0) }
        }
        
        return (start...end).map { TimeSlot(hour: $0) }
    }
}

struct DayData {
    let date: Date
    let items: [ScheduleItem]
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    func itemsForHour(_ hour: Int) -> [ScheduleItem] {
        items.filter { item in
            let startHour = Calendar.current.component(.hour, from: item.startTime)
            let endHour = Calendar.current.component(.hour, from: item.endTime)
            return hour >= startHour && hour < endHour
        }
    }
}

struct TimeSlot: Identifiable {
    let hour: Int
    var id: Int { hour }
    
    var displayTime: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        
        guard let date = calendar.date(from: components) else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }
    
    var isCurrentHour: Bool {
        Calendar.current.component(.hour, from: Date()) == hour
    }
}

// MARK: - UI Components
struct DayHeaderCell: View {
    let dayData: DayData
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(dayData.dayName)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(dayData.dayNumber)
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(
                        dayData.isToday ? .white : 
                        isSelected ? primaryColor : .primary
                    )
                
                if dayData.items.count > 0 {
                    Text("\(dayData.items.count)")
                        .font(.forma(.caption2, weight: .bold))
                        .foregroundColor(dayData.isToday || isSelected ? .white : primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    dayData.isToday ? Color.white.opacity(0.2) :
                                    isSelected ? primaryColor.opacity(0.2) : primaryColor.opacity(0.1)
                                )
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        dayData.isToday ? primaryColor : 
                        isSelected ? primaryColor.opacity(0.1) : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TimeSlotRow: View {
    let timeSlot: TimeSlot
    let dailyData: [DayData]
    let selectedDate: Date
    let primaryColor: Color
    let onEventTap: (ScheduleItem) -> Void
    
    private let rowHeight: CGFloat = 80
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time label
            VStack {
                Text(timeSlot.displayTime)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(timeSlot.isCurrentHour ? primaryColor : .secondary)
                Spacer()
            }
            .frame(width: 60, height: rowHeight)
            
            // Day columns
            HStack(spacing: 0) {
                ForEach(Array(dailyData.enumerated()), id: \.offset) { index, dayData in
                    DayColumn(
                        dayData: dayData,
                        timeSlot: timeSlot,
                        isSelectedDay: Calendar.current.isDate(dayData.date, inSameDayAs: selectedDate),
                        primaryColor: primaryColor,
                        onEventTap: onEventTap
                    )
                    
                    if index < dailyData.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 1, height: rowHeight)
                    }
                }
            }
        }
        .frame(height: rowHeight)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(timeSlot.isCurrentHour ? 0.2 : 0.05))
                .frame(height: 1),
            alignment: .bottom
        )
        .background(
            timeSlot.isCurrentHour ? 
            Rectangle().fill(primaryColor.opacity(0.05)) : 
            Rectangle().fill(Color.clear)
        )
    }
}

struct DayColumn: View {
    let dayData: DayData
    let timeSlot: TimeSlot
    let isSelectedDay: Bool
    let primaryColor: Color
    let onEventTap: (ScheduleItem) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(dayData.itemsForHour(timeSlot.hour), id: \.id) { item in
                Button {
                    onEventTap(item)
                } label: {
                    EventCard(
                        item: item,
                        date: dayData.date,
                        isInSelectedDay: isSelectedDay
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            isSelectedDay ? 
            Rectangle().fill(primaryColor.opacity(0.02)) : 
            Rectangle().fill(Color.clear)
        )
    }
}

struct EventCard: View {
    let item: ScheduleItem
    let date: Date
    let isInSelectedDay: Bool
    
    private var isSkipped: Bool {
        item.isSkipped(onDate: date)
    }
    
    private var timeRange: String {
        "\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.title)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if isSkipped {
                    Image(systemName: "pause.circle.fill")
                        .font(.forma(.caption2))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            if !item.location.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "location")
                        .font(.forma(.caption2))
                    Text(item.location)
                        .font(.forma(.caption2, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            }
            
            Text(timeRange)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: isSkipped ? 
                        [.gray.opacity(0.6), .gray.opacity(0.5)] :
                        [item.color, item.color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(
            color: isSkipped ? .clear : item.color.opacity(0.3),
            radius: 4, x: 0, y: 2
        )
        .scaleEffect(isInSelectedDay ? 1.0 : 0.95)
        .opacity(isSkipped ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isInSelectedDay)
    }
}