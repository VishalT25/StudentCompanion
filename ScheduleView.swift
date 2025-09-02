import SwiftUI
import Combine

enum ScheduleViewType: CaseIterable {
    case cards
    case timeline

    var icon: String {
        switch self {
        case .cards: return "square.grid.2x2"
        case .timeline: return "rectangle.split.3x1"
        }
    }
}

struct ScheduleView: View {
    @StateObject private var scheduleManager = ScheduleManager()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager // NEW
    @State private var showingScheduleManager = false
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0
    @State private var viewType: ScheduleViewType = .cards
    @State private var showingCalendarView = false
    @State private var showingAddClass = false
    
    private var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let startOfTargetWeek = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: weekInterval.start) ?? weekInterval.start
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfTargetWeek)
        }
    }
    
    private var weekHeaderText: String {
        guard let firstDay = currentWeekDates.first, let lastDay = currentWeekDates.last else { return "This Week" }
        if currentWeekOffset == 0 { return "This Week" }
        if currentWeekOffset == 1 { return "Next Week" }
        if currentWeekOffset == -1 { return "Last Week" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: firstDay)) - \(formatter.string(from: lastDay))"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.quaternaryColor.opacity(0.3),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    contentView
                }
                .refreshable { await refreshScheduleData() }
                
                floatingButtons
                
                if showingCalendarView {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                                showingCalendarView = false 
                            } 
                        }
                    
                    VStack {
                        Spacer()
                        CalendarView(
                            selectedDate: $selectedDate,
                            currentWeekOffset: $currentWeekOffset,
                            showingCalendarView: $showingCalendarView,
                            schedule: scheduleManager.activeSchedule
                        )
                        .environmentObject(themeManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
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
        .onAppear(perform: setupInitialDate)
    }
    
    // MARK: - ScheduleView Header Updates

    private var headerView: some View {
        VStack(spacing: 16) {
            // Top navigation bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.forma(.largeTitle, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let activeSchedule = scheduleManager.activeSchedule {
                        Text(activeSchedule.displayName)
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                    .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 20)
                            )
                    }
                }
                
                Spacer()
                
                viewTypeSelector
            }
            
            // Week navigation
            weekNavigationView
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            Color(.systemGroupedBackground)
                .overlay(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.quaternaryColor.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    private var viewTypeSelector: some View {
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
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    viewType == type 
                                        ? themeManager.currentTheme.primaryColor 
                                        : themeManager.currentTheme.primaryColor.opacity(0.12)
                                )
                                .shadow(
                                    color: viewType == type 
                                        ? themeManager.currentTheme.primaryColor.opacity(0.3) 
                                        : Color.clear,
                                    radius: 4, x: 0, y: 2
                                )
                                .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekNavigationView: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: { 
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                    currentWeekOffset -= 1 
                } 
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.forma(.title2))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                    )
            }
            
            VStack(spacing: 4) {
                Text(weekHeaderText)
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                
                if currentWeekOffset != 0 {
                    Button("Jump to Today") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentWeekOffset = 0
                            selectedDate = Date()
                        }
                    }
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                            .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 10)
                    )
                }
            }
            
            Button(action: { 
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                    currentWeekOffset += 1 
                } 
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.forma(.title2))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if let activeSchedule = scheduleManager.activeSchedule {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    if viewType == .cards {
                        weekOverviewSection(activeSchedule)
                        dayScheduleSection(activeSchedule)
                    } else {
                        // Beautiful "Coming Soon" for timeline view
                        VStack(spacing: 16) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                            
                            Text("Timeline View")
                                .font(.title2.bold())
                            
                            Text("Coming in a future update")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 20)
                        )
                    }
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        } else {
            emptyStateView
        }
    }

    @ViewBuilder
    private var floatingButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // Calendar button
                    Button(action: { 
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                            showingCalendarView.toggle() 
                        } 
                    }) {
                        Image(systemName: showingCalendarView ? "xmark" : "calendar")
                            .font(.headline.bold())
                            .foregroundColor(showingCalendarView ? .white : themeManager.currentTheme.primaryColor)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(showingCalendarView ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.secondaryColor.opacity(0.2))
                                    .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                            )
                    }
                    .rotationEffect(.degrees(showingCalendarView ? 180 : 0))
                    
                    // Manage Schedule button
                    Button(action: { showingScheduleManager = true }) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.headline.bold())
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(themeManager.currentTheme.secondaryColor.opacity(0.2))
                                    .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                            )
                    }
                    
                    // Add Class button (primary/biggest)
                    Button(action: { showingAddClass = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(
                                Circle()
                                    .fill(themeManager.currentTheme.primaryColor)
                                    .shadow(
                                        color: themeManager.currentTheme.primaryColor.opacity(0.3),
                                        radius: 8, x: 0, y: 4
                                    )
                                    .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                            )
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func setupInitialDate() {
        selectedDate = Date()
    }
    
    private func refreshScheduleData() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    @ViewBuilder
    private func weekOverviewSection(_ schedule: ScheduleCollection) -> some View {
        VStack(spacing: 20) {
            // Week overview grid
            weekOverviewGrid(schedule)
        }
    }
    
    @ViewBuilder
    private func weekOverviewGrid(_ schedule: ScheduleCollection) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Week Overview")
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                ForEach(currentWeekDates, id: \.self) { date in
                    let dayOfWeek = DayOfWeek.from(weekday: Calendar.current.component(.weekday, from: date))
                    let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager) // NEW
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                            // Don't recalculate week offset - the date is already in the current week view
                            // The currentWeekOffset should remain the same since we're selecting a date from the current displayed week
                        }
                    }) {
                        WeekDayCard(
                            date: date,
                            dayOfWeek: dayOfWeek,
                            classCount: schedule.getScheduleItems(for: date, usingCalendar: academicCalendar).count, // UPDATED
                            isSelected: Calendar.current.isDate(selectedDate, inSameDayAs: date),
                            isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                            schedule: schedule
                        )
                        .environmentObject(themeManager)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 20)
        )
    }
    
    @ViewBuilder
    private func dayScheduleSection(_ schedule: ScheduleCollection) -> some View {
        let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager) // NEW
        let dayClasses = schedule.getScheduleItems(for: selectedDate, usingCalendar: academicCalendar).sorted { $0.startTime < $1.startTime } // UPDATED
        
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatSelectedDate())
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let dayType = getDayType(for: schedule, date: selectedDate) {
                        Text(dayType)
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.12))
                                    .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
                            )
                    }
                }
                
                Spacer()
                
                if !dayClasses.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(dayClasses.count)")
                            .font(.forma(.title2, weight: .bold))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Text(dayClasses.count == 1 ? "class" : "classes")
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                            .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
                    )
                }
            }
            
            if dayClasses.isEmpty {
                EmptyDayView(date: selectedDate, schedule: schedule)
                    .environmentObject(themeManager)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dayClasses) { item in
                        ModernScheduleRow(item: item, date: selectedDate, scheduleID: schedule.id)
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
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 20)
        )
    }
    
    private func getDayType(for schedule: ScheduleCollection, date: Date) -> String? {
        guard schedule.scheduleType.supportsRotation,
              let pattern = schedule.rotationPattern else { return nil }
        
        let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager) // NEW
        guard !(academicCalendar?.isBreakDay(date) ?? false) else { return nil } // UPDATED
        
        return pattern.dayType(for: date)
    }
    
    private func formatSelectedDate() -> String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.1),
                                themeManager.currentTheme.primaryColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "calendar.badge.plus")
                    .font(.forma(.largeTitle, weight: .light))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            
            VStack(spacing: 12) {
                Text("Welcome to Your Schedule")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Create your first schedule to see your classes, track your time, and never miss an important class again.")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: { showingScheduleManager = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.body, weight: .semibold))
                    
                    Text("Create Schedule")
                        .font(.forma(.body, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
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
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.3),
                            radius: 8, x: 0, y: 4
                        )
                        .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 24)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Supporting Views Updates

struct StatCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.forma(.title2, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
        )
    }
}

struct ModernScheduleRow: View {
    let item: ScheduleItem
    let date: Date
    let scheduleID: UUID
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    
    private var timeRange: String {
        "\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))"
    }
    
    private var duration: String {
        let duration = item.endTime.timeIntervalSince(item.startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(item.color)
                .frame(width: 4, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.forma(.body, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(duration)
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(item.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(item.color.opacity(0.15))
                                .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
                        )
                }
                
                HStack(spacing: 12) {
                    Label(timeRange, systemImage: "clock")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "location")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(item.color.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(item.color.opacity(0.15), lineWidth: 1)
                )
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
        )
    }
}