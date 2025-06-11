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

    @State private var showMenu = false
    @State private var selectedRoute: AppRoute?
    @State private var path = NavigationPath()
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false

    @Environment(\.scenePhase) var scenePhase

    @State private var showingWeatherPopover = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    // Schedule Preview
                    NavigationLink(value: AppRoute.schedule) {
                        TodayScheduleView()
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    }
                    .buttonStyle(.plain)
                    
                    // Events Preview
                    NavigationLink(value: AppRoute.events) {
                        EventsPreviewView()
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    }
                    .buttonStyle(.plain)
                    
                    // Quick Actions
                    quickActionsView
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color.white) // Consider .background(themeManager.currentTheme.quaternaryColor.opacity(0.3)) or similar for theming
            .navigationDestination(for: AppRoute.self) { route in
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
                        .background(Color.white)
                case .resources:
                    ResourcesView()
                        .environmentObject(themeManager)
                        .background(Color.white)
                case .islandSmasherGame:
                    IslandSmasherGameView()
                        .background(Color.white)
                }
            }
            .overlay(mainOverlayView)
        }
        .background(Color.white) // This might be redundant if the ScrollView has a background
        .onChange(of: selectedRoute) { newRoute in
            if let route = newRoute {
                path.append(route)
                selectedRoute = nil
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task { @MainActor in // Ensure it runs on the main actor
                    viewModel.manageLiveActivities(themeManager: themeManager)
                }
            }
        }
        .onAppear {
            Task { @MainActor in // Ensure it runs on the main actor
                viewModel.manageLiveActivities(themeManager: themeManager)
            }
        }
    }
    
    @ViewBuilder
    private var mainOverlayView: some View {
        ZStack {
            if showMenu {
                MenuView(isShowing: $showMenu, selectedRoute: $selectedRoute)
                    .environmentObject(themeManager)
                    .transition(.opacity) // Consider a more distinct transition like .move(edge: .leading)
            }
            
            if showingWeatherPopover {
                ZStack {
                    // Transparent background to catch taps for dismissal
                    Color.clear 
                        .background(.ultraThinMaterial.opacity(0.7)) // Or .black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingWeatherPopover = false
                            }
                        }
                    
                    // Weather Widget Content
                    VStack {
                        // Spacer to push content down, or adjust padding as needed
                        HStack {
                            Spacer()
                            WeatherWidgetView(weatherService: weatherService, isPresented: $showingWeatherPopover)
                                .environmentObject(themeManager)
                                .padding(.top, UIApplication.shared.connectedScenes
                                    .compactMap { $0 as? UIWindowScene }
                                    .first?.windows.first?.safeAreaInsets.top ?? 20) // Adjust top padding dynamically
                            Spacer()
                        }
                        .padding(.top, 40) // Adjust this padding as needed
                        
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top))) // Nicer transition
                .zIndex(1000) // Ensure it's on top
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button {
                withAnimation(.spring()) {
                    showMenu.toggle()
                }
            } label: {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(8)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            if let currentWeather = weatherService.currentWeather {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingWeatherPopover = true
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: currentWeather.condition.SFSymbolName)
                            .font(.headline)
                            .foregroundColor(currentWeather.condition.iconColor)
                        Text("\(currentWeather.temperature)°C")
                            .font(.headline.weight(.regular))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                .padding(.trailing, 10)
            } else if weatherService.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(.trailing, 10)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(Date(), style: .date)
                    .font(.headline.weight(.medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
        }
    }
    
    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3.bold())
                .foregroundColor(.black)
            
            HStack(spacing: 12) {
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
                        color: themeManager.currentTheme.quaternaryColor,
                        textColor: .black
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
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
    var textColor: Color = .white
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(textColor)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(textColor)
                Text(subtitle)
                    .font(.headline.bold())
                    .foregroundColor(textColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [color.opacity(0.8), color]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
    }
}
