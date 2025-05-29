import SwiftUI

struct Course: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "New Course"
    var iconName: String = "book.closed.fill" // Default SF Symbol
    var colorHex: String = Color.blue.toHex() ?? "007AFF" // Store color as hex string for Codable

    var assignments: [Assignment] = [Assignment(), Assignment(), Assignment()] // Start with 3 empty assignments
    
    // For "Final Grade Planning"
    var finalGradeGoal: String = ""
    var weightOfRemainingTasks: String = ""

    // Computed property for actual Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    // Placeholder for overall grade - will be calculated
    // var currentOverallGrade: Double? {
    //     // Calculation logic will go here
    //     return nil
    // }
}

// Helper to convert Color to Hex and vice-versa (needed for Codable Color)
// You might want to put this in a separate utility file later.
extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) { // If alpha is not 1, return RGBA
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else { // Else return RGB
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }

    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
