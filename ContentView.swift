import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State private var showSplash = true
    @State private var navigateToPage: PageType?
    
    var body: some View {
        NavigationStack {
            Group {
                ZStack {
                    if showSplash {
                        SplashScreenView()
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        showSplash = false
                                    }
                                }
                            }
                    } else {
                        SwipePageView(navigateToPage: $navigateToPage)
                            .transition(.opacity)
                    }
                }
            }
            .environmentObject(viewModel)
        }
    }
}