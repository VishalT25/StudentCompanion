import SwiftUI

struct WeekDayCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    let date: Date
    let dayOfWeek: DayOfWeek
    let classCount: Int
    let isSelected: Bool
    let isToday: Bool
    let schedule: ScheduleCollection
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var dayAbbreviation: String {
        dayOfWeek.short
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayAbbreviation)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textColor)
                .opacity(0.8)
            
            Text(dayNumber)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
            
            if classCount > 0 {
                Text("\(classCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(badgeTextColor)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(badgeBackgroundColor)
                            .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                    )
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0, y: shadowRadius / 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryColor.opacity(0.15)
        } else if isToday {
            return themeManager.currentTheme.primaryColor.opacity(0.05)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryColor
        } else if isToday {
            return themeManager.currentTheme.primaryColor.opacity(0.4)
        } else {
            return colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryColor
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else {
            return .primary
        }
    }
    
    private var badgeBackgroundColor: Color {
        if isSelected || isToday {
            return themeManager.currentTheme.primaryColor
        } else {
            return themeManager.currentTheme.primaryColor.opacity(0.2)
        }
    }
    
    private var badgeTextColor: Color {
        if isSelected || isToday {
            return .white
        } else {
            return themeManager.currentTheme.primaryColor
        }
    }
    
    private var shadowColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryColor.opacity(0.2)
        } else if isToday {
            return themeManager.currentTheme.primaryColor.opacity(0.1)
        } else {
            return Color.black.opacity(0.03)
        }
    }
    
    private var shadowRadius: CGFloat {
        if isSelected {
            return 8
        } else if isToday {
            return 4
        } else {
            return 2
        }
    }
}