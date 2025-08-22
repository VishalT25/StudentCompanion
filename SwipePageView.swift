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
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager // NEW
    @StateObject private var weatherService = WeatherService()
    @StateObject private var calendarSyncManager = CalendarSyncManager()
    
    @State private var currentPage: PageType = .home
    @State private var dragAmount = CGSize.zero
    @State private var isAnimating = false
    @State private var showMenu = false
    @State private var selectedRoute: AppRoute?
    @State private var showingWeatherPopover = false
    @State private var servicesInitialized = false
    @Environment(\.scenePhase) var scenePhase
    
    @Binding var navigateToPage: PageType?
    
    @State private var showingSettings = false
    @State private var showingResources = false
    @State private var showingGame = false
    @State private var showingNotificationCenter = false
    
    init(navigateToPage: Binding<PageType?> = .constant(nil)) {
        self._navigateToPage = navigateToPage
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topToolbarView
                    .zIndex(10)
                
                TabView(selection: $currentPage) {
                    GPAView()
                        .environmentObject(themeManager)
                        .background(Color(.systemGroupedBackground))
                        .tag(PageType.courses)
                    
                    HomePageView(navigateToPage: $navigateToPage)
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .environmentObject(weatherService)
                        .environmentObject(calendarSyncManager)
                        .environmentObject(academicCalendarManager) // NEW
                        .background(Color(.systemGroupedBackground))
                        .tag(PageType.home)
                    
                    ScheduleView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .environmentObject(academicCalendarManager) // NEW
                        .background(Color(.systemGroupedBackground))
                        .tag(PageType.schedule)
                    
                    EventsListView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .background(Color(.systemGroupedBackground))
                        .tag(PageType.reminders)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
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
        .overlay {
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
            NavigationView {
                SettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(calendarSyncManager)
                    .environmentObject(weatherService)
                    .environmentObject(viewModel)
                    .background(Color(.systemGroupedBackground))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSettings = false
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
            }
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
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showingNotificationCenter) {
            NotificationCenterView()
                .environmentObject(themeManager)
                .environmentObject(viewModel)
                .environmentObject(NotificationManager.shared)
        }
        .onChange(of: selectedRoute) { newRoute in
            if let route = newRoute {
                switch route {
                case .schedule:
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentPage = .schedule
                    }
                case .events:
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentPage = .reminders
                    }
                case .gpa:
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentPage = .courses
                    }
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
        .onChange(of: navigateToPage) { newPage in
            if let page = newPage {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentPage = page
                }
                navigateToPage = nil
            }
        }
        .onChange(of: currentPage) { _, _ in
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
                                    .font(.caption)
                                    .foregroundColor(currentWeather.condition.iconColor)
                                Text("\(currentWeather.temperature)°C")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                    } else if weatherService.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Date(), format: Date.FormatStyle().weekday(.wide).day().month())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            HStack {
                Button {
                    withAnimation(.spring()) {
                        showMenu.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.15), radius: 2, x: 0, y: 1)
                        )
                }
                .scaleEffect(showMenu ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showMenu)
                
                Spacer()
                
                pageIndicatorView
                
                Spacer()
                
                Button {
                    withAnimation(.spring()) {
                        showingNotificationCenter = true
                    }
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.15), radius: 2, x: 0, y: 1)
                        )
                }
                .scaleEffect(showingNotificationCenter ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingNotificationCenter)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .top)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 0.6)
                .blendMode(.overlay)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
        .zIndex(50)
    }
    
    private var pageIndicatorView: some View {
        HStack(spacing: 7) {
            ForEach(PageType.allCases, id: \.self) { page in
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentPage = page
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: page.icon)
                            .font(.system(size: 14, weight: .medium))
                        
                        if currentPage == page {
                            Text(page.title)
                                .font(.system(size: 14, weight: .semibold))
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity
                                ))
                        }
                    }
                    .foregroundColor(currentPage == page ? .white : themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, currentPage == page ? 14 : 9)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(currentPage == page ? themeManager.currentTheme.primaryColor : Color.gray.opacity(0.15))
                            .shadow(
                                color: currentPage == page ? themeManager.currentTheme.primaryColor.opacity(0.25) : .clear,
                                radius: currentPage == page ? 4 : 0,
                                x: 0,
                                y: currentPage == page ? 2 : 0
                            )
                    )
                    .scaleEffect(currentPage == page ? 1.02 : 0.98)
                }
                .buttonStyle(SpringButtonStyle())
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
    }
}

struct HomePageView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var weatherService: WeatherService
    @EnvironmentObject private var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager // NEW
    
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
                        TodayScheduleView()
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
            .padding(.top, 10)
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
                .font(.title2)
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.bold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.12), radius: 8, x: 0, y: 4)
        )
    }
}