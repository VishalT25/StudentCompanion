import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let themes: [AppTheme] = AppTheme.allCases

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(themes) { theme in
                        Button(action: {
                            themeManager.setTheme(theme)
                        }) {
                            VStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.primaryColor)
                                        .frame(height: 100)

                                    if themeManager.currentTheme == theme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    }
                                }
                                Text(theme.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Theme")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}