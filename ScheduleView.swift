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
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @StateObject private var courseManager = UnifiedCourseManager()
    @State private var showingScheduleManager = false
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0
    @State private var viewType: ScheduleViewType = .cards
    @State private var showingCalendarView = false
    @State private var showingAddCourse = false
    @State private var pulseAnimation: Double = 1.0
    @Environment(\.colorScheme) var colorScheme
    
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
        VStack(spacing: 0) {
            headerView
            contentView
        }
        .overlay {
            if showingCalendarView {
                calendarOverlay
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !showingCalendarView {
                magicalFloatingButtons
            }
        }
        .refreshable { await refreshScheduleData() }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingScheduleManager) {
            ScheduleManagerView()
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddCourse) {
            EnhancedAddCourseView(courseManager: courseManager)
                .environmentObject(themeManager)
                .environmentObject(scheduleManager)
        }
        .onAppear {
            setupInitialDate()
            courseManager.setScheduleManager(scheduleManager)
            scheduleManager.setCourseManager(courseManager)
            startAnimations()
        }
    }
    
    // MARK: - Spectacular Background
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.15
        }
    }
    
    private var calendarOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture { 
                withAnimation(.easeInOut(duration: 0.2)) { 
                    showingCalendarView = false 
                } 
            }
            .overlay(
                VStack {
                    Spacer()
                    CalendarView(
                        selectedDate: $selectedDate,
                        currentWeekOffset: $currentWeekOffset,
                        showingCalendarView: $showingCalendarView,
                        schedule: scheduleManager.activeSchedule
                    )
                    .environmentObject(themeManager)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 20)
            )
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Main header with title and view selector
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Schedule")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    if let activeSchedule = scheduleManager.activeSchedule {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.forma(.caption))
                                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))
                            
                            Text(activeSchedule.displayName)
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.forma(.caption))
                                .foregroundColor(.orange)
                            
                            Text("No Active Schedule")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                Spacer()
                
                viewTypeSelector
            }
            
            // Week navigation
            weekNavigationView
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color.clear)
    }

    private var viewTypeSelector: some View {
        HStack(spacing: 6) {
            ForEach(ScheduleViewType.allCases, id: \.self) { type in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) { 
                        viewType = type 
                    } 
                }) {
                    Image(systemName: type.icon)
                        .font(.forma(.callout, weight: .medium))
                        .foregroundColor(viewType == type ? .white : themeManager.currentTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(viewType == type ? themeManager.currentTheme.primaryColor : .clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                .opacity(viewType == type ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var weekNavigationView: some View {
        HStack(alignment: .center, spacing: 20) {
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) { 
                    currentWeekOffset -= 1 
                } 
            }) {
                Image(systemName: "chevron.left")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.1),
                        radius: 6, x: 0, y: 3
                    )
            }
            
            VStack(spacing: 6) {
                Text(weekHeaderText)
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
                
                if currentWeekOffset != 0 {
                    Button("Jump to Today") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentWeekOffset = 0
                            selectedDate = Date()
                        }
                    }
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }
            }
            
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) { 
                    currentWeekOffset += 1 
                } 
            }) {
                Image(systemName: "chevron.right")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.1),
                        radius: 6, x: 0, y: 3
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
                        spectacularTimelineComingSoon
                    }
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        } else {
            spectacularEmptyState
        }
    }

    private var spectacularTimelineComingSoon: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                // Background circles with animation
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.secondaryColor.opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 3.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Main icon
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.secondaryColor,
                                themeManager.currentTheme.tertiaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseAnimation * 0.95 + 0.05)
            }
            
            VStack(spacing: 16) {
                Text("Timeline View")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Coming in a future update with beautiful timeline visualization and enhanced scheduling features")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.secondaryColor.opacity(0.3),
                                    themeManager.currentTheme.tertiaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.secondaryColor.opacity(0.1),
                    radius: 24, x: 0, y: 12
                )
        )
    }
    
    private func setupInitialDate() {
        selectedDate = Date()
    }
    
    private func refreshScheduleData() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    @ViewBuilder
    private func weekOverviewSection(_ schedule: ScheduleCollection) -> some View {
        weekOverviewGrid(schedule)
    }
    
    @ViewBuilder
    private func weekOverviewGrid(_ schedule: ScheduleCollection) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Week Overview")
                    .font(.forma(.headline, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                ForEach(currentWeekDates, id: \.self) { date in
                    let dayOfWeek = DayOfWeek.from(weekday: Calendar.current.component(.weekday, from: date))
                    let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                    }) {
                        WeekDayCard(
                            date: date,
                            dayOfWeek: dayOfWeek,
                            classCount: schedule.getScheduleItems(for: date, usingCalendar: academicCalendar).count,
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
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.1),
                    radius: 12, x: 0, y: 6
                )
        )
    }
    
    @ViewBuilder
    private func dayScheduleSection(_ schedule: ScheduleCollection) -> some View {
        let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager)
        let dayClasses = schedule.getScheduleItems(for: selectedDate, usingCalendar: academicCalendar).sorted { $0.startTime < $1.startTime }
        
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatSelectedDate())
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let dayType = getDayType(for: schedule, date: selectedDate) {
                        Text(dayType)
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                
                Spacer()
                
                if !dayClasses.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(dayClasses.count)")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Text(dayClasses.count == 1 ? "class" : "classes")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            
            if dayClasses.isEmpty {
                EmptyDayView(date: selectedDate, schedule: schedule)
                    .environmentObject(themeManager)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(dayClasses) { item in
                        ModernScheduleRow(item: item, date: selectedDate, scheduleID: schedule.id)
                            .environmentObject(scheduleManager)
                            .environmentObject(themeManager)
                            .id(item.id)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.secondaryColor.opacity(0.1),
                                    themeManager.currentTheme.tertiaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.secondaryColor.opacity(0.1),
                    radius: 12, x: 0, y: 6
                )
        )
    }
    
    private func getDayType(for schedule: ScheduleCollection, date: Date) -> String? {
        guard schedule.scheduleType.supportsRotation,
              let pattern = schedule.rotationPattern else { return nil }
        
        let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager)
        guard !(academicCalendar?.isBreakDay(date) ?? false) else { return nil }
        
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
    
    private var spectacularEmptyState: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                // Background circles with animation
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 3.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Main icon
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseAnimation * 0.95 + 0.05)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to Your Schedule")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Create your first schedule to see your classes, track your time, and never miss an important session again.")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            // Gorgeous call-to-action button
            Button("Create Your First Schedule") {
                showingScheduleManager = true
            }
            .font(.forma(.headline, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.4),
                    radius: 16, x: 0, y: 8
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.2),
                    radius: 8, x: 0, y: 4
                )
            )
            .buttonStyle(EnhancedButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.1),
                    radius: 24, x: 0, y: 12
                )
        )
        .padding(.horizontal, 20)
    }
}

struct ModernScheduleRow: View {
    let item: ScheduleItem
    let date: Date
    let scheduleID: UUID
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDetailView = false
    
    private var isSkipped: Bool {
        item.isSkipped(onDate: date)
    }
    
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
        Button(action: {
            showingDetailView = true
        }) {
            HStack(spacing: 16) {
                // Beautiful color indicator with gradient
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: isSkipped 
                                ? [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
                                : [item.color, item.color.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 5, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.title)
                            .font(.forma(.callout, weight: .semibold))
                            .foregroundColor(isSkipped ? .secondary : .primary)
                            .lineLimit(1)
                            .strikethrough(isSkipped, color: .secondary)
                        
                        if isSkipped {
                            Image(systemName: "pause.circle.fill")
                                .font(.forma(.caption2))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        // Enhanced duration badge
                        Text(duration)
                            .font(.forma(.caption2, weight: .semibold))
                            .foregroundColor(isSkipped ? .secondary : item.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(item.color.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.forma(.caption2))
                                .foregroundColor(.secondary)
                            
                            Text(timeRange)
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if !item.location.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "location")
                                    .font(.forma(.caption2))
                                    .foregroundColor(.secondary)
                                
                                Text(item.location)
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(Color.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isSkipped 
                                    ? Color.secondary.opacity(0.08) 
                                    : item.color.opacity(0.18), 
                                lineWidth: 1
                            )
                    )
            )
            .opacity(isSkipped ? 0.7 : 1.0)
        }
        .buttonStyle(SmoothButtonStyle())
        .animation(nil, value: showingDetailView)
        .sheet(isPresented: $showingDetailView) {
            NavigationView {
                EnhancedCourseDetailView(
                    scheduleItem: item,
                    scheduleID: scheduleID
                )
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
            }
        }
    }
}

extension ModernScheduleRow: Equatable {
    static func == (lhs: ModernScheduleRow, rhs: ModernScheduleRow) -> Bool {
        lhs.item.id == rhs.item.id &&
        Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date) &&
        lhs.scheduleID == rhs.scheduleID
    }
}

// MARK: - Button Styles
struct SmoothButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct EnhancedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct MagicalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ScheduleView {
    @ViewBuilder
    private var magicalFloatingButtons: some View {
        VStack(spacing: 16) {
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                    showingCalendarView.toggle() 
                } 
            }) {
                Image(systemName: "calendar")
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.secondaryColor,
                                            themeManager.currentTheme.secondaryColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            themeManager.currentTheme.darkModeAccentHue.opacity(0.4),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 30
                                    )
                                )
                                .scaleEffect(pulseAnimation * 0.3 + 0.7)
                                .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.2)
                        }
                        .compositingGroup()
                        .shadow(
                            color: themeManager.currentTheme.secondaryColor.opacity(0.4),
                            radius: 12, x: 0, y: 6
                        )
                        .shadow(
                            color: themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.1),
                            radius: 8, x: 0, y: 4
                        )
                    )
            }
            .buttonStyle(MagicalButtonStyle())
            
            Button(action: { showingScheduleManager = true }) {
                Image(systemName: "calendar.badge.clock")
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.tertiaryColor,
                                            themeManager.currentTheme.tertiaryColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            themeManager.currentTheme.darkModeAccentHue.opacity(0.3),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 30
                                    )
                                )
                                .scaleEffect(pulseAnimation * 0.2 + 0.8)
                                .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.15)
                        }
                        .compositingGroup()
                        .shadow(
                            color: themeManager.currentTheme.tertiaryColor.opacity(0.3),
                            radius: 8, x: 0, y: 4
                        )
                    )
            }
            .buttonStyle(MagicalButtonStyle())
            
            Button(action: { showingAddCourse = true }) {
                Image(systemName: "plus")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        ZStack {
                            Circle()
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
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            themeManager.currentTheme.darkModeAccentHue.opacity(0.6),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 40
                                    )
                                )
                                .scaleEffect(pulseAnimation * 0.3 + 0.7)
                                .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.3)
                            Circle()
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.clear
                                        ],
                                        center: .center,
                                        angle: .degrees(0)
                                    )
                                )
                        }
                        .compositingGroup()
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 20, x: 0, y: 10
                        )
                        .shadow(
                            color: themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.2),
                            radius: 12, x: 0, y: 6
                        )
                    )
            }
            .buttonStyle(MagicalButtonStyle())
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
}