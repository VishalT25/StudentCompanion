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
        VStack(spacing: 24) {
            // Beautiful illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                illustrationColor.opacity(0.2),
                                illustrationColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: illustrationIcon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(illustrationColor)
            }
            
            VStack(spacing: 12) {
                Text(emptyMessage)
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(emptySubtitle)
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            if !isWeekend && isToday {
                VStack(spacing: 8) {
                    Text("Perfect time to relax! ✨")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    
                    Text("Catch up on assignments or enjoy some free time.")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
    
    private var emptyMessage: String {
        if isWeekend {
            return "Weekend Vibes"
        } else if isToday {
            return "No Classes Today"
        } else {
            return "Free \(dayName)"
        }
    }
    
    private var emptySubtitle: String {
        if isWeekend {
            return "Time to relax and recharge for the week ahead"
        } else if isToday {
            return "You have a completely free day ahead"
        } else {
            return "This day is free from scheduled classes"
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