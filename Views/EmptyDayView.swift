import SwiftUI

struct EmptyDayView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let date: Date
    let schedule: ScheduleCollection
    
    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                illustrationColor.opacity(0.15),
                                illustrationColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity)
                
                Image(systemName: illustrationIcon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(illustrationColor)
            }
            
            VStack(spacing: 8) {
                Text(emptyMessage)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(emptySubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            if !isWeekend && isToday {
                VStack(spacing: 6) {
                    Text("Enjoy your free time!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    
                    Text("Perfect time to catch up on assignments or relax.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                        )
                        .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 10)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
    
    private var emptyMessage: String {
        if isWeekend {
            return "Weekend Vibes ✨"
        } else if isToday {
            return "No Classes Today"
        } else {
            return "Free \(dayName)"
        }
    }
    
    private var emptySubtitle: String {
        if isWeekend {
            return "Time to relax, recharge, and enjoy your weekend!"
        } else if isToday {
            return "You have a completely free day ahead of you."
        } else {
            return "This day is free from scheduled classes."
        }
    }
    
    private var illustrationIcon: String {
        if isWeekend {
            return "sun.max.fill"
        } else if isToday {
            return "hand.wave.fill"
        } else {
            return "calendar"
        }
    }
    
    private var illustrationColor: Color {
        if isWeekend {
            return .orange
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else {
            return themeManager.currentTheme.secondaryColor
        }
    }
}