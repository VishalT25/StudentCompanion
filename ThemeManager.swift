import SwiftUI

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark" 
    case system = "System"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

// MARK: - Theme System
enum AppTheme: String, CaseIterable, Identifiable {
    case forest = "Forest"
    case ice = "Ice"
    case fire = "Fire"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var alternateIconName: String? {
        switch self {
        case .forest:
            return "ForestThemeIcon"
        case .ice:
            return "IceThemeIcon"
        case .fire:
            return "FireThemeIcon"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
                } else {
                    return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 95/255, green: 135/255, blue: 155/255, alpha: 1.0)
                } else {
                    return UIColor(red: 134/255, green: 167/255, blue: 187/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 155/255, green: 95/255, blue: 105/255, alpha: 1.0)
                } else {
                    return UIColor(red: 187/255, green: 134/255, blue: 147/255, alpha: 1.0)
                }
            })
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 115/255, green: 145/255, blue: 125/255, alpha: 1.0)
                } else {
                    return UIColor(red: 178/255, green: 200/255, blue: 186/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 115/255, green: 145/255, blue: 165/255, alpha: 1.0)
                } else {
                    return UIColor(red: 178/255, green: 200/255, blue: 220/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 165/255, green: 115/255, blue: 125/255, alpha: 1.0)
                } else {
                    return UIColor(red: 220/255, green: 178/255, blue: 186/255, alpha: 1.0)
                }
            })
        }
    }
    
    var tertiaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 135/255, green: 155/255, blue: 145/255, alpha: 1.0)
                } else {
                    return UIColor(red: 210/255, green: 227/255, blue: 200/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 135/255, green: 155/255, blue: 175/255, alpha: 1.0)
                } else {
                    return UIColor(red: 200/255, green: 227/255, blue: 240/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 175/255, green: 135/255, blue: 145/255, alpha: 1.0)
                } else {
                    return UIColor(red: 240/255, green: 210/255, blue: 200/255, alpha: 1.0)
                }
            })
        }
    }
    
    var quaternaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 65/255, green: 75/255, blue: 70/255, alpha: 1.0)
                } else {
                    return UIColor(red: 235/255, green: 243/255, blue: 232/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 65/255, green: 75/255, blue: 85/255, alpha: 1.0)
                } else {
                    return UIColor(red: 232/255, green: 243/255, blue: 252/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 85/255, green: 65/255, blue: 70/255, alpha: 1.0)
                } else {
                    return UIColor(red: 252/255, green: 235/255, blue: 232/255, alpha: 1.0)
                }
            })
        }
    }
    
    // MARK: - Dark Mode Hue Colors
    
    /// Enhanced hue color for dark mode widgets - creates a strong, visible glow effect
    var darkModeHue: Color {
        switch self {
        case .forest:
            return Color(red: 120/255, green: 200/255, blue: 140/255)
        case .ice:
            return Color(red: 100/255, green: 180/255, blue: 220/255)
        case .fire:
            return Color(red: 220/255, green: 120/255, blue: 140/255)
        }
    }
    
    /// Shadow color for dark mode widgets - much more prominent
    var darkModeShadowColor: Color {
        switch self {
        case .forest:
            return Color(red: 120/255, green: 200/255, blue: 140/255)
        case .ice:
            return Color(red: 100/255, green: 180/255, blue: 220/255)
        case .fire:
            return Color(red: 220/255, green: 120/255, blue: 140/255)
        }
    }
    
    /// Bright accent hue for prominent elements in dark mode
    var darkModeAccentHue: Color {
        switch self {
        case .forest:
            return Color(red: 140/255, green: 220/255, blue: 160/255)
        case .ice:
            return Color(red: 120/255, green: 200/255, blue: 240/255)
        case .fire:
            return Color(red: 240/255, green: 140/255, blue: 160/255)
        }
    }
    
    /// Background fill for better contrast in dark mode
    var darkModeBackgroundFill: Color {
        switch self {
        case .forest:
            return Color(red: 25/255, green: 35/255, blue: 28/255)
        case .ice:
            return Color(red: 20/255, green: 30/255, blue: 40/255)
        case .fire:
            return Color(red: 35/255, green: 25/255, blue: 30/255)
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .forest
    @Published var appearanceMode: AppearanceMode = .system
    @Published var darkModeHueIntensity: Double = 0.5 // New intensity slider (0.0 to 1.0)
    
    init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // Load saved appearance mode
        if let savedAppearance = UserDefaults.standard.string(forKey: "selectedAppearance"),
           let appearance = AppearanceMode(rawValue: savedAppearance) {
            appearanceMode = appearance
        }
        
        // Load saved hue intensity
        let savedIntensity = UserDefaults.standard.double(forKey: "darkModeHueIntensity")
        if savedIntensity > 0 {
            darkModeHueIntensity = savedIntensity
        }
        
        // Apply appearance mode
        applyAppearanceMode()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
        
        DispatchQueue.main.async {
            let currentIconName = UIApplication.shared.alternateIconName
            let newIconName = theme.alternateIconName
            
            if currentIconName != newIconName {
                UIApplication.shared.setAlternateIconName(newIconName) { error in
                    if let error = error {
                         ("Error setting alternate app icon: \(error.localizedDescription)")
                    } else {
                         ("App icon changed successfully to \(newIconName ?? "Primary").")
                    }
                }
            }
        }
    }
    
    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "selectedAppearance")
        applyAppearanceMode()
    }
    
    func setDarkModeHueIntensity(_ intensity: Double) {
        darkModeHueIntensity = intensity
        UserDefaults.standard.set(intensity, forKey: "darkModeHueIntensity")
    }
    
    private func applyAppearanceMode() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            switch self.appearanceMode {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

// MARK: - Dark Mode Enhancement Modifier
extension View {
    /// Applies adaptive dark mode styling with theme-matching hues and intensity control
    @ViewBuilder
    func adaptiveDarkModeEnhanced(using theme: AppTheme, intensity: Double, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.3 * intensity),
                                    theme.darkModeBackgroundFill.opacity(0.2 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue.opacity(intensity),
                                            theme.darkModeHue.opacity(0.8 * intensity)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1 + (2 * intensity)
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.4 * intensity),
                            radius: 8 + (12 * intensity),
                            x: 0,
                            y: 4 + (6 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.3 * intensity),
                            radius: 4 + (8 * intensity),
                            x: 0,
                            y: 2 + (4 * intensity)
                        )
                }
        } else {
            self
        }
    }
    
    /// LEGACY: Applies enhanced dark mode styling with theme-matching hues - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func darkModeEnhanced(using theme: AppTheme, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.8),
                                    theme.darkModeBackgroundFill.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue,
                                            theme.darkModeHue
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.8),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.6),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.4),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                }
        } else {
            self
        }
    }
    
    /// Adaptive card dark mode enhancement with customizable corner radius
    @ViewBuilder
    func adaptiveCardDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 16, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.darkModeAccentHue.opacity(intensity * 0.6),
                                    theme.darkModeHue.opacity(intensity * 0.4),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1 + (intensity * 1.5)
                        )
                )
                .shadow(
                    color: theme.darkModeShadowColor.opacity(intensity * 0.3),
                    radius: 8 + (intensity * 8),
                    x: 0,
                    y: 4 + (intensity * 4)
                )
        } else {
            self
        }
    }
    
    /// Widget-specific dark mode enhancement for smaller components
    @ViewBuilder
    func adaptiveWidgetDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 12, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            theme.darkModeAccentHue.opacity(intensity * 0.4),
                            lineWidth: 0.5 + (intensity * 1.0)
                        )
                )
                .shadow(
                    color: theme.darkModeShadowColor.opacity(intensity * 0.25),
                    radius: 6 + (intensity * 6),
                    x: 0,
                    y: 3 + (intensity * 3)
                )
        } else {
            self
        }
    }
}
