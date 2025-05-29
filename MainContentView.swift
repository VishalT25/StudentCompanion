import SwiftUI

enum AppRoute: Hashable { 
    case schedule
    case events
    case gpa
    case settings
    case islandSmasherGame
}

struct MainContentView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @State private var showMenu = false
    @State private var selectedRoute: AppRoute?
    @State private var path = NavigationPath()
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu" // Default URL

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Schedule Preview
                    NavigationLink(value: AppRoute.schedule) {
                        TodayScheduleView()
                            .environmentObject(viewModel)
                    }
                    .buttonStyle(.plain)
                    
                    // Events Preview
                    NavigationLink(value: AppRoute.events) {
                        EventsPreviewView(events: viewModel.events)
                            .environmentObject(viewModel)
                    }
                    .buttonStyle(.plain)
                    
                    // Quick Actions
                    quickActionsView
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(.systemGroupedBackground))

            .navigationDestination(for: AppRoute.self) { route in 
                switch route {
                case .schedule:
                    ScheduleView()
                        .environmentObject(viewModel)
                case .events:
                    EventsListView()
                        .environmentObject(viewModel)
                case .gpa:
                    GPAView()
                case .settings:
                    SettingsView()
                case .islandSmasherGame:
                    IslandSmasherGameView()
                }
            }
            .overlay {
                if showMenu {
                    MenuView(isShowing: $showMenu, selectedRoute: $selectedRoute)
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: selectedRoute) { newRoute in
            if let route = newRoute {
                path.append(route)
                selectedRoute = nil // Reset after appending to path
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
                    .foregroundColor(.primaryGreen)
                    .padding(8)
                    .background(Color.primaryGreen.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(Date(), style: .date)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primaryGreen)
            }
        }
    }
    
    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                NavigationLink(value: AppRoute.gpa) {
                    QuickActionCard(
                        title: "Courses",
                        subtitle: "3.85",
                        icon: "graduationcap.fill",
                        color: .secondaryGreen
                    )
                }
                
                Button(action: { openCustomD2LLink() }) {
                    QuickActionCard(
                        title: "D2L",
                        subtitle: "Portal",
                        icon: "link",
                        color: .tertiaryGreen
                    )
                }
                
                QuickActionCard(
                    title: "Resources",
                    subtitle: "Library",
                    icon: "book.fill",
                    color: .quaternaryGreen,
                    textColor: .black
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
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

