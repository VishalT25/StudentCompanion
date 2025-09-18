import SwiftUI
import Combine

struct ScheduleView: View {
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject private var viewModel: EventViewModel 
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @State private var showingScheduleManager = false
    @State private var showingAcademicCalendarManager = false
    @State private var showingAcademicCalendarSelection = false
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0
    @State private var showingCalendarView = false
    @State private var showingAddCourse = false
    @Environment(\.colorScheme) var colorScheme
    
    @State private var weekItemsCache: [Date: [ScheduleItem]] = [:]
    @State private var pendingRebuild = false
    @State private var coursesCountSnapshot: Int = 0

    @State private var selectedDetail: SelectedScheduleDetail?

    @State private var isInteracting = false

    private var darkSectionBackground: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.currentTheme.darkModeBackgroundFill.opacity(0.4),
                themeManager.currentTheme.darkModeBackgroundFill.opacity(0.3),
                themeManager.currentTheme.darkModeHue.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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
        let formatter = DateFormatterCache.mmmdd
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
            EnhancedAddCourseWithMeetingsView()
                .environmentObject(themeManager)
                .environmentObject(scheduleManager)
                .environmentObject(courseManager)
        }
        .sheet(isPresented: $showingAcademicCalendarManager) {
            AcademicCalendarManagementView()
                .environmentObject(academicCalendarManager)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAcademicCalendarSelection) {
            if let activeSchedule = scheduleManager.activeSchedule {
                AcademicCalendarSelectionView(schedule: activeSchedule)
                    .environmentObject(academicCalendarManager)
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
            }
        }
        .sheet(item: $selectedDetail) { detail in
            EnhancedCourseDetailView(
                scheduleItem: detail.item,
                scheduleID: detail.scheduleID
            )
            .environmentObject(scheduleManager)
            .environmentObject(themeManager)
            .environmentObject(courseManager)
            .interactiveDismissDisabled(false)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            setupInitialDate()
            
            // Only set manager references once to prevent conflicts
            scheduleManager.setCourseManager(courseManager)
            courseManager.setScheduleManager(scheduleManager)

            coursesCountSnapshot = courseManager.courses.count
            if let active = scheduleManager.activeSchedule {
                rebuildWeekCache(for: active)
            }

            // Only refresh if we don't have course data loaded
            // This prevents wiping data when switching tabs
            if courseManager.courses.isEmpty {
                Task { await courseManager.refreshCourseData() }
            }
        }
        .onChange(of: scheduleManager.activeScheduleID) { _, _ in
            Task { await courseManager.refreshCourseData() }
            if let active = scheduleManager.activeSchedule {
                requestCoalescedRebuild(for: active)
            }
        }
        .onChange(of: currentWeekOffset) { _, _ in
            if let active = scheduleManager.activeSchedule {
                requestCoalescedRebuild(for: active)
            }
        }
        .onChange(of: courseManager.courses.count) { _, _ in
            coursesCountSnapshot = courseManager.courses.count
            if let active = scheduleManager.activeSchedule {
                requestCoalescedRebuild(for: active)
            }
        }
        .onReceive(scheduleManager.objectWillChange) { _ in
            if let active = scheduleManager.activeSchedule {
                requestCoalescedRebuild(for: active)
            }
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
                            Button {
                                showingScheduleManager = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.forma(.caption))
                                        .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))
                                    
                                    Text(activeSchedule.displayName)
                                        .font(.forma(.caption, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                showingAcademicCalendarSelection = true
                            } label: {
                                let academicCalendar = scheduleManager.getAcademicCalendar(for: activeSchedule, from: academicCalendarManager)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.forma(.caption2))
                                        .foregroundColor(academicCalendar != nil ? themeManager.currentTheme.primaryColor : .orange)
                                    
                                    if let calendar = academicCalendar {
                                        Text(calendar.academicYear)
                                            .font(.forma(.caption2, weight: .medium))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Setup")
                                            .font(.forma(.caption2, weight: .medium))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill((academicCalendar != nil ? themeManager.currentTheme.primaryColor : .orange).opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke((academicCalendar != nil ? themeManager.currentTheme.primaryColor : .orange).opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
            }
            
            weekNavigationView
        }
        .padding(.horizontal, 20)
        .padding(.top, 25)
        .padding(.bottom, 16)
        .background(Color.clear)
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
                                // Subtle tint to feel like refracted color
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.secondaryColor.opacity(0.12),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blendMode(.plusLighter)
                            )
                            .overlay(
                                // Inner rim for glass edge
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                                    .blur(radius: 0.5)
                                    .opacity(0.7)
                            )
                            .overlay(
                                // Outer colored rim
                                Circle()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.1), radius: 6, x: 0, y: 3)
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.18), radius: 10, x: 0, y: 6)

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
                                // Subtle tint to feel like refracted color
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.secondaryColor.opacity(0.12),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blendMode(.plusLighter)
                            )
                            .overlay(
                                // Inner rim for glass edge
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                                    .blur(radius: 0.5)
                                    .opacity(0.7)
                            )
                            .overlay(
                                // Outer colored rim
                                Circle()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.1), radius: 6, x: 0, y: 3)
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.18), radius: 10, x: 0, y: 6)

                    )
            }
        }
    }

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
                            .shadow(color: themeManager.currentTheme.secondaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    )
            }
            .buttonStyle(MagicalButtonStyle())
            
            Button(action: { showingAddCourse = true }) {
                Image(systemName: "plus")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(
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
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.4), radius: 16, x: 0, y: 8)
                    )
            }
            .buttonStyle(MagicalButtonStyle())
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var contentView: some View {
        if let activeSchedule = scheduleManager.activeSchedule {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    weekOverviewSection(activeSchedule)
                    dayScheduleSection(activeSchedule)
                    Spacer(minLength: 160)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .transaction { $0.disablesAnimations = true }
        } else {
            spectacularEmptyState
        }
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
                            classCount: cachedClassCount(for: date, schedule: schedule, academicCalendar: academicCalendar),
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
                .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(.regularMaterial))
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
        let dayClasses = itemsFor(date: selectedDate, schedule: schedule, academicCalendar: academicCalendar).sorted { $0.startTime < $1.startTime }
        
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatSelectedDate())
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)
                
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Classes")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    LazyVStack(spacing: 16) {
                        ForEach(dayClasses) { item in
                            ModernScheduleRow(
                                item: item,
                                date: selectedDate,
                                scheduleID: schedule.id,
                                onTap: {
                                    selectedDetail = SelectedScheduleDetail(item: item, scheduleID: schedule.id)
                                }
                            )
                            .environmentObject(scheduleManager)
                            .environmentObject(themeManager)
                        }
                    }
                }
            }
            
            RemindersSection(selectedDate: selectedDate)
                .environmentObject(themeManager)
                .environmentObject(viewModel)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(.regularMaterial))
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
        if schedule.scheduleType == .rotating {
            let day = Calendar.current.component(.day, from: date)
            return day % 2 == 1 ? "Day 1" : "Day 2"
        }
        return nil
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
            spectacularEmptyIllustration
            spectacularEmptyTextContent
            spectacularEmptyCTAButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(.regularMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .trailing
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

    private var spectacularEmptyIllustration: some View {
        ZStack {
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
            }
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
        }
    }

    private var spectacularEmptyTextContent: some View {
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
    }

    private var spectacularEmptyCTAButton: some View {
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
                            startPoint: .leading,
                            endPoint: .trailing
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
    
    private func setupInitialDate() {
        selectedDate = Date()
    }
    
    private func refreshScheduleData() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    private func scheduleItemsForDate(schedule: ScheduleCollection, date: Date, academicCalendar: AcademicCalendar?) -> [ScheduleItem] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        
        // Skip weekends entirely
        if weekday == 1 || weekday == 7 {
            return []
        }
        
        // Check semester bounds
        if let start = schedule.semesterStartDate,
           let end = schedule.semesterEndDate {
            let day = cal.startOfDay(for: date)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if day < s || day > e { return [] }
        }
        
        // Check academic calendar
        if let calendar = academicCalendar {
            if !calendar.isDateWithinSemester(date) { return [] }
            if calendar.isBreakDay(date) { return [] }
        }
        
        var items: [ScheduleItem] = []
        
        let coursesInSchedule = courseManager.courses.filter { $0.scheduleId == schedule.id }
        
        print(" DEBUG: Found \(coursesInSchedule.count) courses for schedule \(schedule.id)")
        
        for course in coursesInSchedule {
            print(" DEBUG: Course '\(course.name)' has \(course.meetings.count) meetings")
            
            for meeting in course.meetings {
                print(" DEBUG: Checking meeting '\(meeting.displayName)' for date \(date.formatted(date: .abbreviated, time: .omitted))")
                print(" DEBUG: - Meeting days: \(meeting.daysOfWeek)")
                print(" DEBUG: - Target weekday: \(weekday)")
                print(" DEBUG: - Should appear: \(meeting.shouldAppear(on: date, in: schedule, calendar: academicCalendar))")
                
                if meeting.shouldAppear(on: date, in: schedule, calendar: academicCalendar) {
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
                    items.append(item)
                    print(" DEBUG: Added schedule item for meeting '\(meeting.displayName)'")
                }
            }
        }
        
        print(" DEBUG: Generated \(items.count) schedule items for date")
        return items
    }

    private func sod(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }

    private func rebuildWeekCache(for schedule: ScheduleCollection) {
        var newCache: [Date: [ScheduleItem]] = [:]
        let academicCalendar = scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager)
        for date in currentWeekDates {
            let key = sod(date)
            newCache[key] = scheduleItemsForDate(schedule: schedule, date: key, academicCalendar: academicCalendar)
        }
        weekItemsCache = newCache
    }

    private func requestCoalescedRebuild(for schedule: ScheduleCollection) {
        DispatchQueue.main.async {
            if pendingRebuild { return }
            pendingRebuild = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pendingRebuild = false
                rebuildWeekCache(for: schedule)
            }
        }
    }

    private func itemsFor(date: Date, schedule: ScheduleCollection, academicCalendar: AcademicCalendar?) -> [ScheduleItem] {
        let key = sod(date)
        if let cached = weekItemsCache[key] {
            return cached
        }
        return scheduleItemsForDate(schedule: schedule, date: key, academicCalendar: academicCalendar)
    }

    private func cachedClassCount(for date: Date, schedule: ScheduleCollection, academicCalendar: AcademicCalendar?) -> Int {
        let key = sod(date)
        if let cached = weekItemsCache[key] { return cached.count }
        return scheduleItemsForDate(schedule: schedule, date: key, academicCalendar: academicCalendar).count
    }
}

struct ModernScheduleRow: View {
    let item: ScheduleItem
    let date: Date
    let scheduleID: UUID
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    var onTap: (() -> Void)?

    private var isSkipped: Bool {
        item.isSkipped(onDate: date)
    }
    
    private var timeRange: String {
        "\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))"
    }
    
    private var duration: String {
        let durationTime = item.endTime.timeIntervalSince(item.startTime)
        let hours = Int(durationTime) / 3600
        let minutes = Int(durationTime) % 3600 / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private var rowBackgroundStyle: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.darkModeBackgroundFill.opacity(0.32),
                        themeManager.currentTheme.darkModeBackgroundFill.opacity(0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            onTap?()
        }) {
            HStack(spacing: 16) {
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
                    .fill(rowBackgroundStyle)
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
        .buttonStyle(UltraFastButtonStyle())
    }
}

struct UltraFastButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
    }
}

struct SmoothButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
    }
}

struct ScheduleReminderRow: View {
    let reminder: Event
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var viewModel: EventViewModel
    @State private var showingDetail = false
    @State private var isCompletedLocal: Bool

    init(reminder: Event) {
        self.reminder = reminder
        _isCompletedLocal = State(initialValue: reminder.isCompleted)
    }
    
    private var isOverdue: Bool {
        reminder.date < Date() && !isCompletedLocal
    }
    
    private var isPastDue: Bool {
        reminder.date < Date()
    }
    
    private var categoryColor: Color {
        let category = reminder.category(from: viewModel.categories)
        return category.color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 4) {
                Text(reminder.date.formatted(date: .omitted, time: .shortened))
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(isOverdue ? .red : (isPastDue ? .secondary : themeManager.currentTheme.tertiaryColor))
                
                if isCompletedLocal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.forma(.caption2))
                        .foregroundColor(.green)
                } else if isOverdue {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.forma(.caption2))
                        .foregroundColor(.red)
                } else {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reminder.title)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(isCompletedLocal ? .secondary : .primary)
                        .strikethrough(isCompletedLocal, color: .secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if reminder.reminderTime != .none {
                        Image(systemName: "bell.fill")
                            .font(.forma(.caption2))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                
                HStack(spacing: 8) {
                    let category = reminder.category(from: viewModel.categories)
                    if category.name != "Unknown" {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .font(.forma(.caption2, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !isCompletedLocal {
                        Text(timeDescription)
                            .font(.forma(.caption2))
                            .foregroundColor(isOverdue ? .red : .secondary.opacity(0.8))
                    }
                }
            }
            
            Button(action: {
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isCompletedLocal.toggle()
                }
                viewModel.toggleEventCompleted(reminder)
            }) {
                Image(systemName: isCompletedLocal ? "checkmark.circle.fill" : "circle")
                    .font(.forma(.title3))
                    .foregroundColor(isCompletedLocal ? .green : themeManager.currentTheme.tertiaryColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isCompletedLocal 
                                ? Color.green.opacity(0.3) 
                                : (isOverdue ? Color.red.opacity(0.3) : categoryColor.opacity(0.2)),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isCompletedLocal ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                EventEditView(event: reminder, isNew: false)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
        }
        .onReceive(viewModel.eventOperationsManager.$events) { events in
            if let updated = events.first(where: { $0.id == reminder.id }) {
                if updated.isCompleted != isCompletedLocal {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCompletedLocal = updated.isCompleted
                    }
                }
            }
        }
    }
    
    private var timeDescription: String {
        let now = Date()
        let timeInterval = reminder.date.timeIntervalSince(now)
        
        if timeInterval < 0 {
            let pastInterval = -timeInterval
            if pastInterval < 3600 {
                let minutes = Int(pastInterval / 60)
                return "\(minutes)m ago"
            } else if pastInterval < 86400 {
                let hours = Int(pastInterval / 3600)
                return "\(hours)h ago"
            } else {
                let days = Int(pastInterval / 86400)
                return "\(days)d ago"
            }
        } else {
            if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "in \(minutes)m"
            } else if timeInterval < 86400 {
                let hours = Int(timeInterval / 3600)
                return "in \(hours)h"
            } else {
                let days = Int(timeInterval / 86400)
                return "in \(days)d"
            }
        }
    }
}

struct AddReminderSheet: View {
    let selectedDate: Date
    @Binding var isPresented: Bool
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        AddEventView(
            isPresented: $isPresented,
            preselectedDate: selectedDate
        )
        .environmentObject(viewModel)
        .environmentObject(themeManager)
    }
}

struct MagicalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct RemindersSection: View {
    let selectedDate: Date
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var viewModel: EventViewModel
    @State private var showingAddReminder = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayReminders: [Event] {
        let calendar = Calendar.current
        let filtered = viewModel.events.filter { event in
            calendar.isDate(event.date, inSameDayAs: selectedDate)
        }.sorted { $0.date < $1.date }
        var seen = Set<Event.ID>()
        return filtered.filter { seen.insert($0.id).inserted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.tertiaryColor)
                Text("Reminders")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !dayReminders.isEmpty {
                    Text("\(dayReminders.count)")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Circle()
                                .fill(themeManager.currentTheme.tertiaryColor)
                        )
                }
                
                Button(action: { showingAddReminder = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.tertiaryColor)
                }
                .buttonStyle(.plain)
            }
            
            if dayReminders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(themeManager.currentTheme.tertiaryColor.opacity(0.6))
                    
                    VStack(spacing: 4) {
                        Text("No reminders")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Button("Add Reminder") {
                        showingAddReminder = true
                    }
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.tertiaryColor,
                                        themeManager.currentTheme.tertiaryColor.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            colorScheme == .dark
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.darkModeBackgroundFill.opacity(0.28),
                                        themeManager.currentTheme.darkModeBackgroundFill.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    themeManager.currentTheme.tertiaryColor.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dayReminders) { reminder in
                        ScheduleReminderRow(reminder: reminder)
                            .environmentObject(themeManager)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet(selectedDate: selectedDate, isPresented: $showingAddReminder)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

private enum DateFormatterCache {
    static let mmmdd: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()
}

private struct SelectedScheduleDetail: Identifiable {
    let item: ScheduleItem
    let scheduleID: UUID
    var id: ScheduleItem.ID { item.id }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView()
            .environmentObject(ThemeManager())
            .environmentObject(ScheduleManager())
            .environmentObject(AcademicCalendarManager())
            .environmentObject(EventViewModel())
            .environmentObject(UnifiedCourseManager())
    }
}