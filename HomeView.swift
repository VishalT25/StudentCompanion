import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var viewModel = EventViewModel()

    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Events preview
                    NavigationLink(destination: EventsListView()
                                    .environmentObject(viewModel)) {
                        EventsPreviewView(events: viewModel.events)
                            .padding(8)
                            .background(Color.primaryGreen)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // GPA & D2L row
                    HStack(spacing: 16) {
                        CardView(text: "GPA Here")
                            .background(Color.secondaryGreen)
                            .cornerRadius(12)

                        Button(action: openD2L) {
                            VStack {
                                Image(systemName: "link")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                Text("Go to D2L")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.tertiaryGreen)
                            .cornerRadius(12)
                        }
                    }

                    CardView(text: "Ideas for this space")
                        .background(Color.quaternaryGreen)
                        .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: openMenu) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.primaryGreen)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(currentDate)
                        .font(.title.bold())
                        .foregroundColor(.primaryGreen)
                }
            }
        }
    }

    private func openMenu() { }
    private func openD2L() {
        guard let url = URL(string: "https://d2l.youruniversity.edu") else { return }
        UIApplication.shared.open(url)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView().preferredColorScheme(.light)
            HomeView().preferredColorScheme(.dark)
        }
    }
}

// MARK: - Reusable CardView

struct CardView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

