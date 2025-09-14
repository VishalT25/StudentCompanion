import SwiftUI

struct CreateAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var name: String = ""
    @State private var academicYear: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endDate > startDate
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Navigation Header
                navigationHeader
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero Section
                        heroSection
                        
                        // Form
                        formSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                setupDefaults()
                startAnimations()
            }
        }
    }
    
    private var navigationHeader: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.forma(.callout, weight: .semibold))
            .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Spacer()
            
            Text("New Academic Calendar")
                .font(.forma(.headline, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Create") {
                createCalendar()
            }
            .font(.forma(.callout, weight: .bold))
            .foregroundColor(isValid ? themeManager.currentTheme.primaryColor : .secondary)
            .disabled(!isValid)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(
            .regularMaterial,
            in: Rectangle()
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.12 - Double(index) * 0.04),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.03)
                }
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.clear
                                        ],
                                        center: .center,
                                        angle: .degrees(animationOffset * 0.5)
                                    )
                                )
                        )
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 16, x: 0, y: 8
                        )
                    
                    Image(systemName: "calendar.badge.plus")
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text("Create Academic Calendar")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Set up semester dates and manage breaks to keep your schedules organized.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 24) {
            // Basic Information
            VStack(spacing: 20) {
                FormFieldView(
                    icon: "text.alignleft",
                    title: "Calendar Name",
                    content: {
                        TextField("e.g., Fall 2024 Semester", text: $name)
                            .font(.forma(.body))
                    }
                )
                
                FormFieldView(
                    icon: "calendar",
                    title: "Academic Year",
                    content: {
                        TextField("e.g., 2024-2025", text: $academicYear)
                            .font(.forma(.body))
                    }
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.06),
                        radius: 12, x: 0, y: 6
                    )
            )
            .adaptiveCardDarkModeHue(
                using: themeManager.currentTheme,
                intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0,
                cornerRadius: 16
            )
            
            // Date Range
            VStack(spacing: 20) {
                FormFieldView(
                    icon: "calendar.badge.plus",
                    title: "Start Date",
                    content: {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                )
                
                FormFieldView(
                    icon: "calendar.badge.minus",
                    title: "End Date",
                    content: {
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.06),
                        radius: 12, x: 0, y: 6
                    )
            )
            .adaptiveCardDarkModeHue(
                using: themeManager.currentTheme,
                intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0,
                cornerRadius: 16
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                createCalendar()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.title3, weight: .bold))
                    
                    Text("Create Academic Calendar")
                        .font(.forma(.headline, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    isValid ? themeManager.currentTheme.primaryColor : .gray,
                                    isValid ? themeManager.currentTheme.secondaryColor : .gray
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: isValid ? themeManager.currentTheme.primaryColor.opacity(0.4) : .clear,
                            radius: 16, x: 0, y: 8
                        )
                )
            }
            .disabled(!isValid)
            .buttonStyle(EventsBounceButtonStyle())
            
            Button("Cancel") {
                dismiss()
            }
            .font(.forma(.callout, weight: .medium))
            .foregroundColor(.secondary)
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.06
        }
        
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private func setupDefaults() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        // Smart academic year detection
        let academicStartYear = currentMonth >= 8 ? currentYear : currentYear - 1
        academicYear = "\(academicStartYear)-\(academicStartYear + 1)"
        
        // Default dates
        startDate = Calendar.current.date(from: DateComponents(year: academicStartYear, month: 8, day: 15)) ?? Date()
        endDate = Calendar.current.date(from: DateComponents(year: academicStartYear + 1, month: 6, day: 15)) ?? Date()
    }
    
    private func createCalendar() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedYear = academicYear.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let calendar = AcademicCalendar(
            name: trimmedName,
            academicYear: trimmedYear,
            termType: .semester, // Default to semester
            startDate: startDate,
            endDate: endDate
        )
        
        academicCalendarManager.addCalendar(calendar)
        dismiss()
    }
}

struct FormFieldView<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let icon: String
    let title: String
    let content: Content
    
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}