import SwiftUI

// MARK: - Simplified Schedule View (Traditional Only)
struct EnhancedScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private var activeSchedule: ScheduleCollection? {
        scheduleManager.activeSchedule
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date
            headerView
            
            // Schedule content
            if let schedule = activeSchedule {
                scheduleContentView(for: schedule)
            } else {
                noScheduleView
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .onAppear {
            print("🔍 SCHEDULE: View appeared for date \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            // Date selector
            Button(action: { showingDatePicker = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(headerSubtitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Week view for quick navigation
            weekNavigationView
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var weekNavigationView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(weekDates, id: \.self) { date in
                    WeekDayButton(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        onTap: { selectedDate = date }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }
    
    @ViewBuilder
    private func scheduleContentView(for schedule: ScheduleCollection) -> some View {
        let scheduleItems = getScheduleItems(for: schedule)
        
        if scheduleItems.isEmpty {
            emptyScheduleView
        } else {
            scheduleListView(items: scheduleItems, schedule: schedule)
        }
    }
    
    @ViewBuilder
    private var emptyScheduleView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: isBreakDay ? "sun.max.fill" : "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(isBreakDay ? .orange : .gray)
            
            VStack(spacing: 8) {
                Text(isBreakDay ? "Break Day" : "No Classes Today")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(isBreakDay ? getBreakMessage() : "Enjoy your free day!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    @ViewBuilder
    private func scheduleListView(items: [ScheduleItem], schedule: ScheduleCollection) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items.sorted { $0.startTime < $1.startTime }) { item in
                    EnhancedScheduleItemCard(
                        item: item,
                        date: selectedDate,
                        schedule: schedule
                    )
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private var noScheduleView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Active Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Create a schedule to see your classes here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("Create Schedule") {
                // Handle schedule creation
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Simplified Schedule Logic (Traditional Only)
    private func getScheduleItems(for schedule: ScheduleCollection) -> [ScheduleItem] {
        print("🔍 SCHEDULE: Getting schedule items for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        if weekday == 1 || weekday == 7 {
            print("🔍 SCHEDULE: Weekend, returning empty")
            return []
        }
        
        if let start = schedule.semesterStartDate,
           let end = schedule.semesterEndDate {
            let d = cal.startOfDay(for: selectedDate)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if d < s || d > e {
                print("🔍 SCHEDULE: Date outside schedule's semester bounds, returning empty")
                return []
            }
        }
        
        if let calendar = schedule.academicCalendar {
            if !calendar.isDateWithinSemester(selectedDate) {
                print("🔍 SCHEDULE: Date outside academic calendar bounds, returning empty")
                return []
            }
            if calendar.isBreakDay(selectedDate) {
                print("🔍 SCHEDULE: Date is a break day, returning empty")
                return []
            }
        }
        
        let coursesInSchedule = courseManager.courses.filter { $0.scheduleId == schedule.id }
        print("🔍 SCHEDULE: Found \(coursesInSchedule.count) courses in schedule")
        
        var scheduleItems: [ScheduleItem] = []
        
        for course in coursesInSchedule {
            print("🔍 SCHEDULE: Checking course '\(course.name)'")
            
            if let scheduleItem = course.toScheduleItem(for: selectedDate, in: schedule, calendar: schedule.academicCalendar) {
                scheduleItems.append(scheduleItem)
                print("🔍 SCHEDULE: ✅ Added '\(course.name)' at \(scheduleItem.startTime.formatted(date: .omitted, time: .shortened))")
            } else {
                print("🔍 SCHEDULE: ❌ Course '\(course.name)' should not appear today")
            }
        }
        
        let traditionalItems = getTraditionalScheduleItems(for: schedule)
        scheduleItems.append(contentsOf: traditionalItems)
        
        print("🔍 SCHEDULE: Total schedule items: \(scheduleItems.count)")
        return scheduleItems
    }
    
    // Legacy support for traditional schedule items
    private func getTraditionalScheduleItems(for schedule: ScheduleCollection) -> [ScheduleItem] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        let dayOfWeek = DayOfWeek.from(weekday: weekday)
        
        return schedule.scheduleItems.filter { item in
            let dayMatches = item.daysOfWeek.contains(dayOfWeek)
            let notSkipped = !item.isSkipped(onDate: selectedDate)
            return dayMatches && notSkipped
        }
    }
    
    // MARK: - Helper Methods
    private var isBreakDay: Bool {
        guard let schedule = activeSchedule,
              let calendar = schedule.academicCalendar else {
            return false
        }
        return calendar.isBreakDay(selectedDate)
    }
    
    private func getBreakMessage() -> String {
        guard let schedule = activeSchedule,
              let calendar = schedule.academicCalendar,
              let breakInfo = calendar.breakForDate(selectedDate) else {
            return "No classes scheduled"
        }
        return breakInfo.name
    }
    
    private var headerSubtitle: String {
        if let schedule = activeSchedule {
            return schedule.scheduleType == .rotating ? "Day 1 / Day 2 Schedule" : "Weekly Schedule"
        }
        return "Weekly Schedule"
    }
    
    private func rotatingDayLabel(for date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return day % 2 == 1 ? "Day 1" : "Day 2"
    }
}

// MARK: - Supporting Views (Simplified)
struct WeekDayButton: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    private var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(dayFormatter.string(from: date))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(dayNumberFormatter.string(from: date))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                    .frame(height: 12)
            }
            .frame(width: 50, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedScheduleItemCard: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let date: Date
    let schedule: ScheduleCollection
    
    @State private var showingOptions = false
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var duration: String {
        let interval = item.endTime.timeIntervalSince(item.startTime)
        let hours = Int(interval) / 3600
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var isCurrentClass: Bool {
        let now = Date()
        let calendar = Calendar.current
        
        guard calendar.isDate(date, inSameDayAs: now) else { return false }
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: item.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: item.endTime)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Time indicator
            VStack(alignment: .center, spacing: 4) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrentClass ? .white : .primary)
                
                Text(duration)
                    .font(.caption)
                    .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                
                Rectangle()
                    .fill(isCurrentClass ? .white.opacity(0.3) : item.color.opacity(0.3))
                    .frame(width: 2, height: 20)
            }
            .frame(width: 60)
            
            // Class info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(isCurrentClass ? .white : .primary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label(timeFormatter.string(from: item.endTime), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                    
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                    
                    if item.reminderTime != .none {
                        Label(item.reminderTime.shortDisplayName, systemImage: "bell")
                            .font(.caption)
                            .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Options menu
            Menu {
                Button("Skip This Class", systemImage: "forward.fill") {
                    scheduleManager.toggleSkip(forItem: item, onDate: date, in: schedule.id)
                }
                
                Button("Edit Class", systemImage: "pencil") {
                    // Handle edit
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrentClass ? item.color : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentClass ? Color.clear : item.color.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: isCurrentClass ? item.color.opacity(0.3) : .black.opacity(0.05),
                    radius: isCurrentClass ? 8 : 2,
                    x: 0,
                    y: isCurrentClass ? 4 : 1
                )
        )
        .scaleEffect(isCurrentClass ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCurrentClass)
    }
}

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationView {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    EnhancedScheduleView()
        .environmentObject(ScheduleManager())
        .environmentObject(ThemeManager())
        .environmentObject(UnifiedCourseManager())
}