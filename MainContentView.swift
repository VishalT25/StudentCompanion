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
            VStack(spacing: 16) {
                // Header
                HStack {
                    Button {
                        withAnimation(.spring()) {
                            showMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.primaryGreen)
                    }
                    
                    Spacer()
                    
                    Text(Date(), style: .date)
                        .font(.headline)
                        .foregroundColor(.primaryGreen)
                }
                .padding(.horizontal)
                
                // Schedule Preview
                NavigationLink(value: AppRoute.schedule) {
                    TodayScheduleView()
                        .environmentObject(viewModel)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                // Events Preview
                NavigationLink(value: AppRoute.events) {
                    EventsPreviewView(events: viewModel.events)
                        .environmentObject(viewModel)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                // Quick Actions
                HStack(spacing: 12) {
                    NavigationLink(value: AppRoute.gpa) {
                        VStack {
                            Text("GPA")
                                .font(.caption.bold())
                            Text("3.85")
                                .font(.title.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(Color.secondaryGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        openCustomD2LLink()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.title2)
                            Text("D2L")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(Color.tertiaryGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    VStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.title2)
                        Text("Resources")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.quaternaryGreen)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationDestination(for: AppRoute.self) { route in 
                switch route {
                case .schedule:
                    ScheduleView()
                        .environmentObject(viewModel)
                case .events:
                    EventsListView()
                        .environmentObject(viewModel)
                case .gpa:
                    Text("GPA Calculator")
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
    
    private func openCustomD2LLink() {
        guard let url = URL(string: d2lLink) else {
            print("Invalid D2L URL: \(d2lLink)")
            // Optionally, show an alert to the user
            return
        }
        UIApplication.shared.open(url)
    }
}
