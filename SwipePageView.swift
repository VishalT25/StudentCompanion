import SwiftUI

enum PageType: Int, CaseIterable {
    case courses = 0
    case home = 1
    case schedule = 2
    case reminders = 3
    
    var icon: String {
        switch self {
        case .courses: return "graduationcap.fill"
        case .home: return "house.fill"
        case .schedule: return "calendar"
        case .reminders: return "star.fill"
        }
    }
    
    var title: String {
        switch self {
        case .courses: return "Courses"
        case .home: return "Home"
        case .schedule: return "Schedule"
        case .reminders: return "Reminders"
        }
    }
}

struct SwipePageView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject private var realtimeSyncManager: RealtimeSyncManager
    @StateObject private var weatherService = WeatherService()
    @StateObject private var calendarSyncManager = CalendarSyncManager()
    
    @State private var currentIndex: Int = PageType.home.rawValue
    @State private var dragAmount = CGSize.zero
    @State private var isAnimating = false
    @State private var showMenu = false
    @State private var selectedRoute: AppRoute?
    @State private var showingWeatherPopover = false
    @State private var servicesInitialized = false
    @State private var animationOffset: CGFloat = 0
    @Environment(\.scenePhase) var scenePhase
    
    @Binding var navigateToPage: PageType?
    
    @State private var showingSettings = false
    @State private var showingResources = false
    @State private var showingGame = false
    @State private var showingNotificationCenter = false

    init(navigateToPage: Binding<PageType?> = .constant(nil)) {
        self._navigateToPage = navigateToPage
        UIScrollView.appearance().backgroundColor = .clear
    }
    
    private var selectedPage: PageType {
        PageType(rawValue: currentIndex) ?? .home
    }

    var body: some View {
        ZStack {
            animatedBackground
            
            VStack(spacing: 0) {
                topToolbarView

                TabView(selection: $currentIndex) {
                    GPAView()
                        .environmentObject(themeManager)
                        .background(Color.clear)
                        .tag(PageType.courses.rawValue)
                    
                    HomePageView(navigateToPage: $navigateToPage)
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .environmentObject(weatherService)
                        .environmentObject(calendarSyncManager)
                        .environmentObject(academicCalendarManager)
                        .environmentObject(realtimeSyncManager)
                        .background(Color.clear)
                        .tag(PageType.home.rawValue)
                    
                    ScheduleView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .environmentObject(academicCalendarManager)
                        .background(Color.clear)
                        .tag(PageType.schedule.rawValue)
                    
                    EventsListView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .background(Color.clear)
                        .tag(PageType.reminders.rawValue)
                }
                .background(Color.clear)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay {
            if showMenu {
                ZStack {
                    Color.black.opacity(0.4)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showMenu = false
                            }
                        }
                    
                    HStack {
                        MenuContentView(isShowing: $showMenu, selectedRoute: $selectedRoute)
                            .environmentObject(themeManager)
                            .transition(.move(edge: .leading))
                        
                        Spacer()
                    }
                }
                .zIndex(100)
            }
        }
        .overlay {
            if showingWeatherPopover {
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial.opacity(0.7))
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingWeatherPopover = false
                            }
                        }
                    
                    VStack {
                        HStack {
                            Spacer()
                            WeatherWidgetView(weatherService: weatherService, isPresented: $showingWeatherPopover)
                                .environmentObject(themeManager)
                                .padding(.top, 120)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                .zIndex(200)
            }
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(themeManager)
                .environmentObject(calendarSyncManager)
                .environmentObject(weatherService)
                .environmentObject(viewModel)
                .environmentObject(realtimeSyncManager)
        }
        .fullScreenCover(isPresented: $showingResources) {
            NavigationView {
                ResourcesView()
                    .environmentObject(themeManager)
                    .background(Color(.systemGroupedBackground))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingResources = false
                            }
                            .font(.forma(.body))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showingGame) {
            NavigationView {
                IslandSmasherGameView()
                    .background(Color(.systemGroupedBackground))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingGame = false
                            }
                            .font(.forma(.body))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showingNotificationCenter) {
            NotificationsView()
                .environmentObject(themeManager)
                .environmentObject(viewModel)
                .environmentObject(NotificationManager.shared)
        }
        .onChange(of: selectedRoute) { oldRoute, newRoute in
            if let route = newRoute {
                showMenu = false
                switch route {
                case .schedule:
                    currentIndex = PageType.schedule.rawValue
                case .events:
                    currentIndex = PageType.reminders.rawValue
                case .gpa:
                    currentIndex = PageType.courses.rawValue
                case .settings:
                    showingSettings = true
                case .resources:
                    showingResources = true
                case .islandSmasherGame:
                    showingGame = true
                }
                selectedRoute = nil
            }
        }
        .onChange(of: navigateToPage) { oldPage, newPage in
            if let page = newPage {
                currentIndex = page.rawValue
                navigateToPage = nil
            }
        }
        .onChange(of: currentIndex) { _, _ in
            if showMenu { showMenu = false }
            if showingWeatherPopover { showingWeatherPopover = false }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    viewModel.manageLiveActivities(themeManager: themeManager)
                }
            }
        }
        .onAppear {
            if !servicesInitialized {
                DispatchQueue.main.async {
                    viewModel.setLiveDataServices(weatherService: weatherService, calendarSyncManager: calendarSyncManager)
                    servicesInitialized = true
                    
                    Task { @MainActor in
                        viewModel.manageLiveActivities(themeManager: themeManager)
                    }
                }
            }
            startAnimations()
        }
    }
    
    private var animatedBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    themeManager.currentTheme.quaternaryColor.opacity(0.3),
                    themeManager.currentTheme.tertiaryColor.opacity(0.2),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            ForEach(0..<3, id: \.self) { index in
                let baseX: CGFloat = CGFloat(index * 150 - 300)
                let baseY: CGFloat = CGFloat(index * 200 - 100)
                let sinComponent: CGFloat = CGFloat(sin(Double(animationOffset) * 0.001 + Double(index)) * 50.0)
                let cosComponent: CGFloat = CGFloat(cos(Double(animationOffset) * 0.0008 + Double(index * 2)) * 30.0)
                let xOffset: CGFloat = baseX + sinComponent
                let yOffset: CGFloat = baseY + cosComponent
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.15),
                                themeManager.currentTheme.secondaryColor.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: xOffset, y: yOffset)
                    .blur(radius: 30)
            }
            
            let progress = Double(animationOffset) * 0.0005
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.01),
                            Color.clear,
                            Color.black.opacity(0.01)
                        ],
                        startPoint: UnitPoint(x: progress, y: 0),
                        endPoint: UnitPoint(x: 1 + progress, y: 1)
                    )
                )
                .ignoresSafeArea()
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }

    private func selectIndex(_ index: Int) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentIndex = index
        }
    }
    
    private var topToolbarView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                HStack(spacing: 12) {
                    if let currentWeather = weatherService.currentWeather {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingWeatherPopover = true
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: currentWeather.condition.SFSymbolName)
                                    .font(.forma(.caption))
                                    .foregroundColor(currentWeather.condition.iconColor)
                                Text("\(currentWeather.temperature)°C")
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if weatherService.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Date(), format: Date.FormatStyle().weekday(.wide).day().month())
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 6)
            .padding(.bottom, 6)
            
            HStack {
                Button {
                    withAnimation(.spring()) {
                        showMenu.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.15), radius: 2, x: 0, y: 1)
                        )
                }
                .scaleEffect(showMenu ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showMenu)
                .buttonStyle(.plain)
                
                Spacer()
                
                pageIndicatorView
                
                Spacer()
                
                Image(systemName: "bell.fill")
                    .font(.forma(.caption, weight: .medium))
                    .opacity(0)
                    .padding(5)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .opacity(0)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(
            ZStack {
                // The .ultraThinMaterial provides the frosted glass effect.
                // I've removed the static gradient that was on top of it,
                // so now it will blur the main animated background, creating a
                // dynamic and modern textured look instead of a static gray.
                Rectangle().fill(.ultraThinMaterial)
            }
            .ignoresSafeArea(edges: .top)
        )
        .overlay(alignment: .bottom) {
            // Made the separator line thinner and more subtle for a cleaner look.
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
                .blendMode(.overlay)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
    
    private var pageIndicatorView: some View {
        HStack(spacing: 7) {
            ForEach(PageType.allCases, id: \.self) { page in
                Button {
                    currentIndex = page.rawValue
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: page.icon)
                            .font(.forma(.caption, weight: .medium))
                        
                        if selectedPage == page {
                            Text(page.title)
                                .font(.forma(.caption, weight: .semibold))
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                                    removal: .opacity
                                ))
                        }
                    }
                    .foregroundColor(selectedPage == page ? .white : themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, selectedPage == page ? 14 : 9)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(selectedPage == page ? themeManager.currentTheme.primaryColor : Color.gray.opacity(0.15))
                            .shadow(
                                color: selectedPage == page ? themeManager.currentTheme.primaryColor.opacity(0.25) : .clear,
                                radius: selectedPage == page ? 6 : 0,
                                x: 0,
                                y: selectedPage == page ? 3 : 0
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("TopTab_\(page.title)")
                }
                .buttonStyle(TabPillButtonStyle())
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedPage)
    }
}

private struct TabPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct HomePageView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var weatherService: WeatherService
    @EnvironmentObject private var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager
    
    @Binding var navigateToPage: PageType?
    @State private var selectedRoute: AppRoute?
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    
    @State private var showingResources = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            navigateToPage = .schedule
                        }
                    } label: {
                        TodayScheduleView(onNavigateToSchedule: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                navigateToPage = .schedule
                            }
                        })
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    }
                    .buttonStyle(SpringButtonStyle())
                    
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            navigateToPage = .reminders
                        }
                    } label: {
                        EventsPreviewView()
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    }
                    .buttonStyle(SpringButtonStyle())
                }
                
                quickActionsView
            }
            .padding(.horizontal, 20)
            .padding(.top, 25)
        }
        .refreshable {
            await viewModel.refreshLiveData()
        }
        .fullScreenCover(isPresented: $showingResources) {
            NavigationView {
                ResourcesView()
                    .environmentObject(themeManager)
                    .background(Color(.systemGroupedBackground))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingResources = false
                            }
                            .font(.forma(.body))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
            }
        }
    }

    private var quickActionsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        navigateToPage = .courses
                    }
                } label: {
                    ActionCardView(
                        icon: "graduationcap.fill",
                        title: "View Courses",
                        subtitle: calculateDisplayGrade(updateTrigger: lastGradeUpdate)
                    )
                    .environmentObject(themeManager)
                }
                .buttonStyle(SpringButtonStyle())
                
                Button(action: { openCustomD2LLink() }) {
                    ActionCardView(
                        icon: "link.circle.fill",
                        title: "D2L Portal",
                        subtitle: ""
                    )
                    .environmentObject(themeManager)
                }
                .buttonStyle(SpringButtonStyle())
                
                Button {
                    showingResources = true
                } label: {
                    ActionCardView(
                        icon: "doc.text.fill",
                        title: "Resources",
                        subtitle: ""
                    )
                    .environmentObject(themeManager)
                }
                .buttonStyle(SpringButtonStyle())
            }
        }
    }
    
    private func calculateDisplayGrade(updateTrigger: Double) -> String {
        guard showCurrentGPA else { return "View" }
        
        guard let savedCoursesData = UserDefaults.standard.data(forKey: "gpaCourses"),
              let courses = try? JSONDecoder().decode([Course].self, from: savedCoursesData),
              !courses.isEmpty else {
            return "No Data"
        }
        
        var totalGrade = 0.0
        var courseCount = 0
        
        for course in courses {
            var totalWeightedGrade = 0.0
            var totalWeight = 0.0
            
            for assignment in course.assignments {
                if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                    totalWeightedGrade += grade * weight
                    totalWeight += weight
                }
            }
            
            if totalWeight > 0 {
                let courseGrade = totalWeightedGrade / totalWeight
                totalGrade += courseGrade
                courseCount += 1
            }
        }
        
        guard courseCount > 0 else { return "No Grades" }
        
        let averageGrade = totalGrade / Double(courseCount)
        
        if usePercentageGrades {
            return String(format: "%.1f%%", averageGrade)
        } else {
            let gpa = (averageGrade / 100.0) * 4.0
            return String(format: "%.2f", gpa)
        }
    }
    
    private func openCustomD2LLink() {
        guard let url = URL(string: d2lLink) else {
            print("Invalid D2L URL: \(d2lLink)")
            return
        }
        UIApplication.shared.open(url)
    }
}

struct ActionCardView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.title2))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.12), radius: 8, x: 0, y: 4)
        )
        .adaptiveWidgetDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
    }
}

struct EventsPreviewView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.forma(.subheadline))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    Text("Reminders")
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.forma(.caption))
                    .foregroundColor(.primary)
            }
            
            let todaysEvents = viewModel.todaysEvents()
            let upcomingEvents = viewModel.upcomingEvents()
            
            if todaysEvents.isEmpty && upcomingEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star.circle")
                        .font(.forma(.title2))
                        .foregroundColor(.primary)
                    Text("No upcoming reminders")
                        .font(.forma(.subheadline))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    // Today's events
                    if !todaysEvents.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Today")
                                    .font(.forma(.subheadline, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(todaysEvents.count)")
                                    .font(.forma(.caption))
                                    .foregroundColor(.primary)
                            }
                            
                            ForEach(Array(todaysEvents.prefix(2))) { event in
                                EventPreviewRow(event: event)
                                    .environmentObject(viewModel)
                                    .environmentObject(themeManager)
                            }
                            
                            if todaysEvents.count > 2 {
                                Text("+ \(todaysEvents.count - 2) more today")
                                    .font(.forma(.caption))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Upcoming events
                    if !upcomingEvents.isEmpty {
                        VStack(spacing: 8) {
                            if !todaysEvents.isEmpty {
                                Divider()
                            }
                            
                            HStack {
                                Text("Upcoming")
                                    .font(.forma(.subheadline, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(upcomingEvents.count)")
                                    .font(.forma(.caption))
                                    .foregroundColor(.primary)
                            }
                            
                            ForEach(Array(upcomingEvents.prefix(todaysEvents.isEmpty ? 3 : 2))) { event in
                                EventPreviewRow(event: event)
                                    .environmentObject(viewModel)
                                    .environmentObject(themeManager)
                            }
                            
                            let displayedCount = todaysEvents.isEmpty ? 3 : 2
                            if upcomingEvents.count > displayedCount {
                                Text("+ \(upcomingEvents.count - displayedCount) more upcoming")
                                    .font(.forma(.caption))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.12), radius: 12, x: 0, y: 6)
        )
        .adaptiveWidgetDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
    }
}

struct EventPreviewRow: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: event.date))")
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                Text(monthShort(from: event.date))
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 32)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(timeString(from: event.date), systemImage: "clock")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(event.category(from: viewModel.categories).color)
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func monthShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}