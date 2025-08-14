import SwiftUI

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
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .forest
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
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
                        print("Error setting alternate app icon: \(error.localizedDescription)")
                    } else {
                        print("App icon changed successfully to \(newIconName ?? "Primary").")
                    }
                }
            }
        }
    }
}