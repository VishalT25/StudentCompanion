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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    MainContentView()
                        .transition(.opacity)
                }
            }
        }
        .environmentObject(viewModel)
    }
}
