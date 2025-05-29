import SwiftUI

struct SplashScreenView: View {
    @State private var scale = 0.7
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            Color.primaryGreen
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                
                Text("Student Companion")
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            .opacity(opacity)
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
