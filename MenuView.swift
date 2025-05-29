import SwiftUI

struct MenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedRoute: AppRoute?
    @State private var happyFaceClickCount = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }
            
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    menuItem(.schedule, icon: "calendar", title: "Schedule")
                    menuItem(.events, icon: "list.bullet.clipboard", title: "Events")
                    menuItem(.gpa, icon: "number", title: "GPA Calculator")
                    menuItem(.settings, icon: "gear", title: "Settings")
                    
                    Spacer() // Pushes the emoji to the bottom
                    
                    Button {
                        happyFaceClickCount += 1
                        if happyFaceClickCount >= 3 {
                            happyFaceClickCount = 0 // Reset counter
                            selectedRoute = .islandSmasherGame
                            withAnimation(.spring()) {
                                isShowing = false
                            }
                        }
                    } label: {
                        HStack {
                            Text("😀")
                                .font(.title)
                            if happyFaceClickCount > 0 { // Optional: show click progress
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
                .background(Color.primaryGreen)
                .offset(x: isShowing ? 0 : -250)
                
                Spacer()
            }
        }
    }
    
    private func menuItem(_ route: AppRoute, icon: String, title: String) -> some View {
        Button {
            selectedRoute = route
            withAnimation(.spring()) {
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
