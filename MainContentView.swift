import SwiftUI

enum AppRoute: Hashable {
    case schedule
    case events
    case gpa
    case settings
    case resources
    case islandSmasherGame
}

struct MainContentView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var weatherService = WeatherService()
    @StateObject private var calendarSyncManager = CalendarSyncManager()
    @EnvironmentObject private var scheduleManager: ScheduleManager

    @State private var showMenu = false
    @State private var selectedRoute: AppRoute?
    @State private var path = NavigationPath()
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme

    @State private var showingWeatherPopover = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    var body: some View {
        mainNavigationView
            .background(
                // Better background separation in dark mode
                Group {
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.05, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refreshLiveData()
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .toolbar {
                toolbarContent
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: selectedRoute) { newRoute in
                handleRouteChange(newRoute)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleSceneChange(newPhase)
            }
            .onAppear {
                setupServices()
                configureNavigationBarAppearance()
                startAnimations()
            }
    }
    
    private var mainNavigationView: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    // Add header section to match GPAView spacing
                    homeHeaderSection
                    
                    schedulePreview
                    eventsPreview
                    quickActionsView
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .background(
                // Better background separation in dark mode
                Group {
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.05, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refreshLiveData()
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .toolbar {
                toolbarContent
            }
        }
    }
    
    @ViewBuilder
    private var enhancedWeatherButton: some View {
        if let currentWeather = weatherService.currentWeather {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingWeatherPopover = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: currentWeather.condition.SFSymbolName)
                        .font(.forma(.body)) // Increased by ~10%
                        .foregroundColor(currentWeather.condition.iconColor)
                        .shadow(color: currentWeather.condition.iconColor.opacity(0.5), radius: 4)
                    Text("\(currentWeather.temperature)°C")
                        .font(.forma(.body, weight: .semibold)) // Increased by ~10%
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
        } else if weatherService.isLoading {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
    }
    
    private var enhancedDateDisplay: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Today")
                .font(.forma(.footnote)) // Increased by ~10%
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 1)
            Text(Date(), style: .date)
                .font(.forma(.subheadline, weight: .semibold)) // Increased by ~10%
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
    }
    
    private func startAnimations() {
        // Continuous rotation animation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.05
        }
    }
    
    private var homeHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dashboard")
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
                
                Text("Welcome back")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var schedulePreview: some View {
        NavigationLink(value: AppRoute.schedule) {
            TodayScheduleView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .buttonStyle(.plain)
    }
    
    private var eventsPreview: some View {
        NavigationLink(value: AppRoute.events) {
            EventsListView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .buttonStyle(.plain)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showMenu.toggle()
                    if showMenu {
                        showingWeatherPopover = false
                    }
                }
            } label: {
                Image(systemName: "line.horizontal.3")
                    .font(.forma(.title3))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                }
                
                weatherButton
                dateDisplay
            }
        }
    }
    
    @ViewBuilder
    private var weatherButton: some View {
        if let currentWeather = weatherService.currentWeather {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingWeatherPopover = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentWeather.condition.SFSymbolName)
                        .font(.forma(.subheadline))
                        .foregroundColor(currentWeather.condition.iconColor)
                    Text("\(currentWeather.temperature)°C")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        } else if weatherService.isLoading {
            ProgressView()
                .scaleEffect(0.6)
        }
    }
    
    private var dateDisplay: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("Today")
                .font(.forma(.caption2))
                .foregroundColor(.secondary)
            Text(Date(), style: .date)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private var menuOverlay: some View {
        if showMenu {
            ZStack {
                Color.black.opacity(0.4)
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
    
    @ViewBuilder
    private var weatherOverlay: some View {
        if showingWeatherPopover {
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial.opacity(0.7))
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
                            .padding(.top, 160) // Adjusted for enhanced nav bar height
                        Spacer()
                    }
                    Spacer()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            .zIndex(200)
        }
    }
    
    // MARK: - Helper Methods
    
    private func configureNavigationBarAppearance() {
        // Configure navigation bar to be hidden since we're using custom spectacular nav
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    private func handleRouteChange(_ newRoute: AppRoute?) {
        if let route = newRoute {
            path.removeLast(path.count)
            path.append(route)
            selectedRoute = nil
        }
    }
    
    private func handleSceneChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { @MainActor in
                // Handle live activities when app becomes active
                 ("🔄 MainContentView: App became active")
            }
        }
    }
    
    private func setupServices() {
        // Setup services when view appears
         ("🔄 MainContentView: Setting up services")
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .schedule:
            ScheduleView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .environmentObject(scheduleManager) // Pass shared ScheduleManager
                .background(Color.white)
        case .events:
            EventsListView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .background(Color.white)
        case .gpa:
            GPAView()
                .environmentObject(themeManager)
                .environmentObject(scheduleManager) // Pass shared ScheduleManager
                .background(Color.white)
        case .settings:
            SettingsView()
                .environmentObject(themeManager)
                .environmentObject(calendarSyncManager)
                .environmentObject(weatherService)
                .background(Color.white)
                .navigationBarBackButtonHidden(false)
        case .resources:
            ResourcesView()
                .environmentObject(themeManager)
                .background(Color.white)
        case .islandSmasherGame:
            IslandSmasherGameView()
                .background(Color.white)
        }
    }
    
    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.forma(.title3, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                NavigationLink(value: AppRoute.gpa) {
                    QuickActionCard(
                        title: "Courses",
                        subtitle: calculateDisplayGrade(updateTrigger: lastGradeUpdate),
                        icon: "graduationcap.fill",
                        color: themeManager.currentTheme.secondaryColor
                    )
                }
                
                Button(action: { openCustomD2LLink() }) {
                    QuickActionCard(
                        title: "D2L",
                        subtitle: "Portal",
                        icon: "link",
                        color: themeManager.currentTheme.tertiaryColor
                    )
                }
                
                NavigationLink(value: AppRoute.resources) {
                    QuickActionCard(
                        title: "Resources",
                        subtitle: "Library",
                        icon: "book.fill",
                        color: themeManager.currentTheme.quaternaryColor
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        // ADAPTIVE DARK MODE EFFECTS WITH INTENSITY CONTROL
        .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
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
             ("Invalid D2L URL: \(d2lLink)")
            return
        }
        UIApplication.shared.open(url)
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var textColor: Color = .primary
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.forma(.title2))
                .foregroundColor(adaptiveIconColor)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(adaptiveTextColor)
                Text(subtitle)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(adaptiveTextColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(colorScheme == .dark ? 0.6 : 0.8), 
                    color.opacity(colorScheme == .dark ? 0.8 : 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
        .adaptiveWidgetDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
    }
    
    private var adaptiveTextColor: Color {
        if colorScheme == .dark {
            return .white
        } else {
            // For light mode, check if the background color is light or dark
            return isDarkColor(color) ? .white : .black
        }
    }
    
    private var adaptiveIconColor: Color {
        if colorScheme == .dark {
            return themeManager.currentTheme.darkModeAccentHue
        } else {
            return isDarkColor(color) ? .white : color.opacity(0.7)
        }
    }
    
    private func isDarkColor(_ color: Color) -> Bool {
        // Convert SwiftUI Color to UIColor to get RGB values
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate luminance using standard formula
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }
}