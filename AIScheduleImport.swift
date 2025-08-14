import SwiftUI
import Foundation

// MARK: - Schedule Import Models
struct ScheduleImportData: Codable {
    let version: Int
    let timezone: String?
    let items: [ScheduleImportItem]
}

struct ScheduleImportItem: Codable {
    let title: String
    let start: String // "HH:mm" format
    let end: String   // "HH:mm" format
    let days: [String] // ["Mon", "Tue", etc.]
    let color: String?
    let reminder: String?
    let liveActivity: Bool?
    let dayIndices: [Int]? // Optional 1-7 mapping
}

// MARK: - Schedule Import Parser
class ScheduleImportParser {
    static func parseScheduleJSON(_ jsonString: String) throws -> [ScheduleItem] {
        // Clean the JSON string (remove any markdown formatting or extra text)
        let cleanedJson = cleanJsonString(jsonString)
        
        guard let jsonData = cleanedJson.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }
        
        let importData = try JSONDecoder().decode(ScheduleImportData.self, from: jsonData)
        
        guard importData.version == 1 else {
            throw ImportError.unsupportedVersion
        }
        
        var scheduleItems: [ScheduleItem] = []
        
        for item in importData.items {
            guard let scheduleItem = try convertImportItem(item) else {
                continue // Skip invalid items
            }
            scheduleItems.append(scheduleItem)
        }
        
        return scheduleItems
    }
    
    private static func cleanJsonString(_ input: String) -> String {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        }
        if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        // Find the JSON object (starts with { and ends with })
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func convertImportItem(_ item: ScheduleImportItem) throws -> ScheduleItem? {
        // Parse times
        guard let startTime = parseTime(item.start),
              let endTime = parseTime(item.end) else {
            throw ImportError.invalidTimeFormat
        }
        
        // Parse days
        let daysOfWeek = try parseDays(item.days)
        
        // Parse color
        let color = parseColor(item.color) ?? .blue
        
        // Parse reminder
        let reminderTime = parseReminder(item.reminder) ?? .none
        
        // Create schedule item
        return ScheduleItem(
            title: item.title,
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: daysOfWeek,
            color: color,
            reminderTime: reminderTime,
            isLiveActivityEnabled: item.liveActivity ?? true
        )
    }
    
    private static func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
    
    private static func parseDays(_ dayStrings: [String]) throws -> Set<DayOfWeek> {
        var days: Set<DayOfWeek> = []
        
        for dayString in dayStrings {
            switch dayString.lowercased() {
            case "sun", "sunday":
                days.insert(.sunday)
            case "mon", "monday":
                days.insert(.monday)
            case "tue", "tuesday":
                days.insert(.tuesday)
            case "wed", "wednesday":
                days.insert(.wednesday)
            case "thu", "thursday":
                days.insert(.thursday)
            case "fri", "friday":
                days.insert(.friday)
            case "sat", "saturday":
                days.insert(.saturday)
            default:
                throw ImportError.invalidDayFormat
            }
        }
        
        return days
    }
    
    private static func parseColor(_ colorString: String?) -> Color? {
        guard let colorString = colorString else { return nil }
        
        // Handle hex colors
        if colorString.hasPrefix("#") {
            return Color(hex: colorString)
        }
        
        // Handle named colors
        switch colorString.lowercased() {
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        case "gray", "grey": return .gray
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
    }
    
    private static func parseReminder(_ reminderString: String?) -> ReminderTime? {
        guard let reminderString = reminderString else { return nil }
        
        switch reminderString.lowercased() {
        case "none": return .none
        case "atstart": return .atTime
        case "5m": return .fiveMinutes
        case "10m": return .tenMinutes
        case "15m": return .fifteenMinutes
        case "30m": return .thirtyMinutes
        case "1h": return .oneHour
        case "2h": return .twoHours
        default: return .tenMinutes
        }
    }
}

// MARK: - Import Errors
enum ImportError: LocalizedError {
    case invalidJSON
    case unsupportedVersion
    case invalidTimeFormat
    case invalidDayFormat
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .unsupportedVersion:
            return "Unsupported import version"
        case .invalidTimeFormat:
            return "Invalid time format"
        case .invalidDayFormat:
            return "Invalid day format"
        case .parsingFailed:
            return "Failed to parse schedule data"
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - AI Import Tutorial View
struct AIImportTutorialView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let scheduleID: UUID
    @State private var currentStep = 0
    @State private var showingImportView = false
    
    private let steps = [
        TutorialStep(
            title: "Take a Screenshot",
            description: "Capture a clear image of your class schedule. Make sure all class names, times, and days are visible.",
            icon: "camera.fill",
            detail: "Your schedule can be from any source - student portal, PDF, or even a printed schedule."
        ),
        TutorialStep(
            title: "Use AI to Parse",
            description: "Copy our special prompt and paste it into any AI assistant (ChatGPT, Claude, etc.) along with your screenshot.",
            icon: "brain.head.profile",
            detail: "The AI will analyze your schedule and convert it to a format our app can understand."
        ),
        TutorialStep(
            title: "Import Your Schedule",
            description: "Copy the AI's response and paste it back into our app. Your classes will be automatically added!",
            icon: "square.and.arrow.down",
            detail: "Just paste the JSON output and we'll handle the rest."
        ),
        TutorialStep(
            title: "Double-Check & Customize",
            description: "AI can make mistakes! Always review your imported schedule for accuracy.",
            icon: "checkmark.shield.fill",
            detail: "Check times, days, and class names. You can always edit individual classes afterward. Advanced users can customize the AI prompt to better fit their schedule format."
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 20)
                
                // Step content
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        TutorialStepView(step: steps[index])
                            .environmentObject(themeManager)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                        if currentStep == steps.count - 1 {
                            showingImportView = true
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("AI Schedule Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImportView) {
            AIScheduleImportView(scheduleID: scheduleID)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
}

struct TutorialStep {
    let title: String
    let description: String
    let icon: String
    let detail: String
}

struct TutorialStepView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let step: TutorialStep
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 80))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}