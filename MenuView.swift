import SwiftUI

struct MenuView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isShowing: Bool
    @Binding var selectedRoute: AppRoute?
    @State private var happyFaceClickCount = 0

    var body: some View {
        ZStack {
            // Color.black.opacity(0.3)
            //     .ignoresSafeArea()
            //     .onTapGesture {
            //         withAnimation(.spring()) {
            //             isShowing = false
            //         }
            //     }
            
            HStack {
                MenuContentView(isShowing: $isShowing, selectedRoute: $selectedRoute)
                    .environmentObject(themeManager)
                
                Spacer()
            }
        }
    }
}

struct MenuContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isShowing: Bool
    @Binding var selectedRoute: AppRoute?
    @State private var happyFaceClickCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuItem(.schedule, icon: "calendar", title: "Schedule")
            menuItem(.events, icon: "star.fill", title: "Reminders")
            menuItem(.gpa, icon: "graduationcap", title: "Courses")
            menuItem(.resources, icon: "book.fill", title: "Resources")
            menuItem(.settings, icon: "gear", title: "Settings")
            
            Spacer() // Pushes the emoji to the bottom
            
            Button {
                happyFaceClickCount += 1
                if happyFaceClickCount >= 3 {
                    happyFaceClickCount = 0
                    selectedRoute = .islandSmasherGame
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            } label: {
                HStack {
                    Text("😀")
                        .font(.title)
                    if happyFaceClickCount > 0 {
                        Text("(\(happyFaceClickCount)/3)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            }
            // END: Easter egg trigger
        }
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(themeManager.currentTheme.primaryColor)
        .shadow(radius: 10)
    }
    
    private func menuItem(_ route: AppRoute, icon: String, title: String) -> some View {
        Button {
            selectedRoute = route
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowing = false
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(selectedRoute == route ? Color.white.opacity(0.2) : Color.clear)
        }
    }
}