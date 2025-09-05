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
        VStack(spacing: 4) {
            Text(dayAbbreviation)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(textColor.opacity(0.7))
            
            Text(dayNumber)
                .font(.forma(.callout, weight: .bold))
                .foregroundColor(textColor)
            
            if classCount > 0 {
                Text("\(classCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(badgeTextColor)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(badgeBackgroundGradient)
                    )
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 14, height: 14)
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderGradient, lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0, y: shadowRadius / 2
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isToday)
    }
    
    private var backgroundGradient: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.2),
                    themeManager.currentTheme.primaryColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isToday {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.1),
                    themeManager.currentTheme.primaryColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    .clear,
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var borderGradient: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.primaryColor.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isToday {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.5),
                    themeManager.currentTheme.primaryColor.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(.systemGray5),
                    Color(.systemGray6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
    
    private var badgeBackgroundGradient: LinearGradient {
        if isSelected || isToday {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.primaryColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.3),
                    themeManager.currentTheme.primaryColor.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            return Color.black.opacity(0.02)
        }
    }
    
    private var shadowRadius: CGFloat {
        if isSelected {
            return 12
        } else if isToday {
            return 6
        } else {
            return 3
        }
    }
}