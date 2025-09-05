import SwiftUI

struct SpectacularBackground: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    themeManager.currentTheme.secondaryColor.opacity(0.2),
                    themeManager.currentTheme.primaryColor.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // You can add the animated circles here as well if you like
        }
    }
}