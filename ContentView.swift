import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State private var showSplash = true
    
    var body: some View {
        Group {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    NavigationStack {
                        MainContentView()
                            .transition(.opacity)
                    }
                }
            }
        }
        .environmentObject(viewModel)
    }
}
