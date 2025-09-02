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
            .background(Color.white)
            .overlay {
                menuOverlay
            }
            .overlay {
                weatherOverlay
            }
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
                    schedulePreview
                    eventsPreview
                    quickActionsView
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                spectacularNavigationBar
            }
        }
    }
    
    private var spectacularNavigationBar: some View {
        HStack {
            // Leading - Menu Button
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showMenu.toggle()
                    if showMenu {
                        showingWeatherPopover = false
                    }
                }
            } label: {
                Image(systemName: "line.horizontal.3")
                    .font(.forma(.title2))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        ZStack {
                            // Base glassmorphism
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                            
                            // Animated gradient overlay
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            themeManager.currentTheme.primaryColor.opacity(0.6),
                                            themeManager.currentTheme.secondaryColor.opacity(0.4),
                                            themeManager.currentTheme.tertiaryColor.opacity(0.5),
                                            themeManager.currentTheme.primaryColor.opacity(0.6)
                                        ],
                                        center: .center,
                                        angle: .degrees(animationOffset)
                                    )
                                )
                                .blur(radius: 8)
                            
                            // Sharp border
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.8),
                                            Color.white.opacity(0.2),
                                            themeManager.currentTheme.darkModeAccentHue.opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .scaleEffect(pulseAnimation)
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                        .shadow(
                            color: themeManager.currentTheme.darkModeAccentHue.opacity(0.3),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                    )
            }
            
            Spacer()
            
            // Center - Weather and Date with enhanced styling
            HStack(spacing: 16) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                enhancedWeatherButton
                enhancedDateDisplay
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Multi-layer glassmorphism background
                    Capsule()
                        .fill(.regularMaterial)
                    
                    // Animated mesh gradient
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2),
                                    themeManager.currentTheme.tertiaryColor.opacity(0.25),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.3 + animationOffset * 0.001, y: 0.4),
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [
                                    Color.clear,
                                    themeManager.currentTheme.quaternaryColor.opacity(0.15),
                                    themeManager.currentTheme.primaryColor.opacity(0.2)
                                ],
                                center: UnitPoint(x: 0.7 - animationOffset * 0.0008, y: 0.6),
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                    
                    // Shimmer effect
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: UnitPoint(x: -0.5 + animationOffset * 0.002, y: 0),
                                endPoint: UnitPoint(x: 0.5 + animationOffset * 0.002, y: 1)
                            )
                        )
                    
                    // Enhanced border
                    Capsule()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    themeManager.currentTheme.darkModeAccentHue.opacity(0.7),
                                    themeManager.currentTheme.primaryColor.opacity(0.6),
                                    Color.white.opacity(0.8)
                                ],
                                center: .center,
                                angle: .degrees(animationOffset * 0.5)
                            ),
                            lineWidth: 2
                        )
                }
                .scaleEffect(pulseAnimation * 0.98 + 0.02)
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.5),
                    radius: 15,
                    x: 0,
                    y: 8
                )
                .shadow(
                    color: themeManager.currentTheme.darkModeAccentHue.opacity(0.4),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            )
            
            Spacer()
            
            // Trailing - Profile Button
            Button {
                // Future: Profile or quick settings
            } label: {
                Image(systemName: "person.circle")
                    .font(.forma(.title2))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            themeManager.currentTheme.tertiaryColor.opacity(0.6),
                                            themeManager.currentTheme.quaternaryColor.opacity(0.4),
                                            themeManager.currentTheme.primaryColor.opacity(0.5),
                                            themeManager.currentTheme.tertiaryColor.opacity(0.6)
                                        ],
                                        center: .center,
                                        angle: .degrees(-animationOffset)
                                    )
                                )
                                .blur(radius: 8)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.darkModeAccentHue.opacity(0.6),
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .scaleEffect(pulseAnimation)
                        .shadow(
                            color: themeManager.currentTheme.tertiaryColor.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(
            ZStack {
                // Base spectacular background
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.black,
                                Color(red: 0.02, green: 0.02, blue: 0.05),
                                Color(red: 0.04, green: 0.04, blue: 0.08),
                                Color(red: 0.06, green: 0.06, blue: 0.1)
                            ] : [
                                Color.white,
                                Color(red: 0.98, green: 0.98, blue: 1.0),
                                Color(red: 0.95, green: 0.95, blue: 0.98),
                                Color(red: 0.92, green: 0.92, blue: 0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Animated mesh gradient layers
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.15 * themeManager.darkModeHueIntensity),
                                themeManager.currentTheme.secondaryColor.opacity(0.1 * themeManager.darkModeHueIntensity),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.2 + animationOffset * 0.0003, y: 0.3),
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                themeManager.currentTheme.tertiaryColor.opacity(0.08 * themeManager.darkModeHueIntensity),
                                themeManager.currentTheme.quaternaryColor.opacity(0.12 * themeManager.darkModeHueIntensity)
                            ],
                            center: UnitPoint(x: 0.8 - animationOffset * 0.0005, y: 0.7),
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                
                // Noise texture overlay for depth
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05),
                                Color.clear,
                                Color.black.opacity(colorScheme == .dark ? 0.05 : 0.02)
                            ],
                            startPoint: UnitPoint(x: animationOffset * 0.001, y: 0),
                            endPoint: UnitPoint(x: 1 + animationOffset * 0.001, y: 1)
                        )
                    )
                
                // Enhanced bottom border with animation
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    themeManager.currentTheme.primaryColor.opacity(0.3 * themeManager.darkModeHueIntensity),
                                    themeManager.currentTheme.darkModeAccentHue.opacity(0.4 * themeManager.darkModeHueIntensity),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2 * themeManager.darkModeHueIntensity),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .scaleEffect(x: pulseAnimation, y: 1, anchor: .center)
                }
                
                // Subtle animated particles effect
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.darkModeAccentHue.opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 3
                            )
                        )
                        .frame(width: 6, height: 6)
                        .offset(
                            x: CGFloat(index * 60 - 150) + animationOffset * CGFloat(index % 2 == 0 ? 0.02 : -0.015),
                            y: CGFloat(index * 8 - 20) + sin(animationOffset * 0.005 + Double(index)) * 10
                        )
                        .opacity(0.6 * themeManager.darkModeHueIntensity)
                }
            }
            .ignoresSafeArea(edges: .top)
        )
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
        // Keep empty since we're using custom spectacular nav bar
        ToolbarItem(placement: .navigationBarLeading) {
            EmptyView()
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            EmptyView()
        }
    }
    
    private var menuButton: some View {
        Button {
            withAnimation(.spring()) {
                showMenu.toggle()
                if showMenu {
                    showingWeatherPopover = false
                }
            }
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.forma(.title2))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .padding(8)
                .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var trailingToolbarContent: some View {
        HStack(spacing: 12) {
            if viewModel.isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
            }
            
            weatherButton
            dateDisplay
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
                print("🔄 MainContentView: App became active")
            }
        }
    }
    
    private func setupServices() {
        // Setup services when view appears
        print("🔄 MainContentView: Setting up services")
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .schedule:
            ScheduleView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .background(Color.white)
        case .events:
            EventsListView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .background(Color.white)
        case .gpa:
            GPAView()
                .environmentObject(themeManager)
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
            print("Invalid D2L URL: \(d2lLink)")
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