import SwiftUI
import Combine

struct EnhancedCourseDetailView: View {
    let scheduleItem: ScheduleItem
    let scheduleID: UUID
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var course: Course?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var scrollOffset: CGFloat = 0
    
    private let headerHeight: CGFloat = 180
    
    var body: some View {
        ZStack {
            // Background with gorgeous gradient
            backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Hero Header with parallax effect
                    heroHeaderSection
                        .offset(y: max(-scrollOffset * 0.3, -100))
                    
                    // Main Content
                    VStack(spacing: 24) {
                        // Quick Stats Cards
                        quickStatsSection
                        
                        // Schedule Information
                        scheduleInfoSection
                        
                        // Create Course Prompt (if no course exists)
                        if course == nil {
                            createCoursePrompt
                        }
                        
                        // Action Buttons
                        actionButtonsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .background {
                        // Elegant content background
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: -10)
                            .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 32)
                    }
                    .offset(y: -32)
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                })
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            .coordinateSpace(name: "scroll")
            .scrollBounceBehavior(.basedOnSize)
            
            // Custom Navigation Bar with blur effect
            VStack {
                customNavigationBar
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadCourseData()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let schedule = scheduleManager.schedule(for: scheduleID) {
                EnhancedScheduleEditView(scheduleItem: scheduleItem, scheduleID: scheduleID)
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
            }
        }
        .alert("Delete Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteScheduleItem()
            }
        } message: {
            Text("Are you sure you want to delete \(scheduleItem.title)? This action cannot be undone.")
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                scheduleItem.color.opacity(0.8),
                scheduleItem.color.opacity(0.6),
                scheduleItem.color.opacity(0.4),
                themeManager.currentTheme.quaternaryColor.opacity(0.3),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Custom Navigation Bar
    
    private var customNavigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
            }
            
            Spacer()
            
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(min(max(scrollOffset / -100, 0), 1))
                .ignoresSafeArea(edges: .top)
        }
    }
    
    // MARK: - Hero Header Section
    
    private var heroHeaderSection: some View {
        VStack(spacing: 16) {
            // Course Icon - much smaller and more compact
            ZStack {
                // Subtle outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 25,
                            endRadius: 45
                        )
                    )
                    .frame(width: 90, height: 90)
                
                // Main icon container
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
                
                // Course icon
                Image(systemName: course?.iconName ?? "book.closed.fill")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                scheduleItem.color,
                                scheduleItem.color.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Course Title - more compact
            Text(scheduleItem.title)
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 20)
            
            // Professor and Location on same line - compact
            if !scheduleItem.instructor.isEmpty || !scheduleItem.location.isEmpty {
                HStack(spacing: 16) {
                    if !scheduleItem.instructor.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.forma(.caption))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(scheduleItem.instructor)
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    if !scheduleItem.location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.forma(.caption))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(scheduleItem.location)
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                }
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight)
        .padding(.top, 20)
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "clock.fill",
                title: "Duration",
                value: scheduleItem.duration,
                color: themeManager.currentTheme.primaryColor
            )
            
            StatCard(
                icon: "calendar.badge.clock",
                title: "Days",
                value: "\(scheduleItem.daysOfWeek.count)",
                color: themeManager.currentTheme.secondaryColor
            )
            
            StatCard(
                icon: "calendar.circle.fill",
                title: "Weekly Hours",
                value: String(format: "%.1f", scheduleItem.weeklyHours),
                color: themeManager.currentTheme.tertiaryColor
            )
        }
    }
    
    // MARK: - Schedule Info Section
    
    private var scheduleInfoSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Schedule Details", icon: "calendar")
            
            VStack(spacing: 12) {
                ScheduleDetailRow(
                    icon: "clock.fill",
                    title: "Time",
                    detail: scheduleItem.timeRange,
                    color: scheduleItem.color
                )
                
                ScheduleDetailRow(
                    icon: "calendar.badge.checkmark",
                    title: "Days",
                    detail: scheduleItem.daysOfWeek.map { $0.short }.joined(separator: ", "),
                    color: scheduleItem.color
                )
                
                if !scheduleItem.location.isEmpty {
                    ScheduleDetailRow(
                        icon: "location.fill",
                        title: "Location",
                        detail: scheduleItem.location,
                        color: scheduleItem.color
                    )
                }
                
                if !scheduleItem.instructor.isEmpty {
                    ScheduleDetailRow(
                        icon: "person.fill",
                        title: "Professor",
                        detail: scheduleItem.instructor,
                        color: scheduleItem.color
                    )
                }
                
                if scheduleItem.reminderTime != .none {
                    ScheduleDetailRow(
                        icon: "bell.fill",
                        title: "Reminder",
                        detail: scheduleItem.reminderTime.displayName,
                        color: scheduleItem.color
                    )
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 18)
        }
    }
    
    // MARK: - Create Course Prompt
    
    private var createCoursePrompt: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Grade Tracking", icon: "graduationcap")
            
            VStack(spacing: 14) {
                Image(systemName: "graduationcap.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(scheduleItem.color.opacity(0.8))
                
                VStack(spacing: 6) {
                    Text("Track Your Grades")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Create a course profile to track assignments and monitor your academic progress.")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Start Tracking Grades") {
                    createCourseFromScheduleItem()
                }
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    scheduleItem.color,
                                    scheduleItem.color.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: scheduleItem.color.opacity(0.3), radius: 8, x: 0, y: 4)
                        .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 18)
        }
    }
    
    // MARK: - Action Buttons Section (Simplified)
    
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Skip Status Display
            if isSkippedToday {
                HStack(spacing: 12) {
                    Image(systemName: "pause.circle.fill")
                        .font(.forma(.body))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Class Skipped Today")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("This class is marked as skipped for today")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        }
                        .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity * 0.3, cornerRadius: 12)
                }
            }
            
            // Action Buttons
            HStack(spacing: 14) {
                ActionButton(
                    icon: "pencil",
                    title: "Edit Class",
                    color: themeManager.currentTheme.primaryColor,
                    action: { showingEditSheet = true }
                )
                
                ActionButton(
                    icon: isSkippedToday ? "play.fill" : "pause.fill",
                    title: isSkippedToday ? "Unskip Today" : "Skip Today",
                    color: isSkippedToday ? .green : .orange,
                    action: { toggleSkipToday() }
                )
            }
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var isSkippedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let identifier = ScheduleItem.instanceIdentifier(for: scheduleItem.id, onDate: today)
        return scheduleItem.skippedInstanceIdentifiers.contains(identifier)
    }
    
    private func loadCourseData() {
        // Check if a course already exists for this schedule item
        // In a real implementation, you'd query your course manager
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Create a sample course for demonstration
            course = Course(
                id: scheduleItem.id,
                scheduleId: scheduleID,
                name: scheduleItem.title,
                iconName: "book.closed.fill",
                colorHex: scheduleItem.color.toHex() ?? "",
                assignments: [
                    Assignment(courseId: scheduleItem.id, name: "Homework 1", grade: "95", weight: "15"),
                    Assignment(courseId: scheduleItem.id, name: "Midterm Exam", grade: "87", weight: "25"),
                    Assignment(courseId: scheduleItem.id, name: "Quiz 1", grade: "92", weight: "10")
                ]
            )
        }
    }
    
    private func createCourseFromScheduleItem() {
        course = Course.from(scheduleItem: scheduleItem, scheduleId: scheduleID)
        // In practice, save this to your course manager
    }
    
    private func toggleSkipToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Update the schedule item through the schedule manager
        scheduleManager.toggleSkip(forItem: scheduleItem, onDate: today, in: scheduleID)
        
        // The UI will automatically update since scheduleManager is @EnvironmentObject
    }
    
    private func deleteScheduleItem() {
        scheduleManager.deleteScheduleItem(scheduleItem, from: scheduleID)
        dismiss()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay {
                            Circle()
                                .stroke(color.opacity(0.25), lineWidth: 1)
                        }
                }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 14)
        }
    }
}

struct ScheduleDetailRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(detail)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.forma(.subheadline, weight: .semibold))
                
                Text(title)
                    .font(.forma(.subheadline, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                    .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationView {
        EnhancedCourseDetailView(
            scheduleItem: ScheduleItem(
                title: "Advanced Swift Programming",
                startTime: Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date(),
                endTime: Calendar.current.date(from: DateComponents(hour: 11, minute: 30)) ?? Date(),
                daysOfWeek: [.monday, .wednesday, .friday],
                location: "Engineering Building Room 201",
                instructor: "Dr. Sarah Johnson",
                color: .blue
            ),
            scheduleID: UUID()
        )
        .environmentObject(ScheduleManager())
        .environmentObject(ThemeManager())
    }
}