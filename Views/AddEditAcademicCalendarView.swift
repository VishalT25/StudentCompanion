import SwiftUI

struct AddEditAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var calendar: AcademicCalendar?
    
    @State private var name: String = ""
    @State private var academicYear: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    private var isEditing: Bool {
        calendar != nil
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endDate > startDate
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Compact Header Section
                headerSection
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero icon section
                        heroIconSection
                        
                        formContent
                        
                        if isEditing, let cal = calendar {
                            breaksManagementSection(cal)
                        }
                        
                        actionButtonsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                setup()
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.15
        }
        
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Compact Navigation Bar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.forma(.callout, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                
                Spacer()
                
                Text(isEditing ? "Edit Calendar" : "New Calendar")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Create") {
                    saveCalendar()
                }
                .font(.forma(.callout, weight: .bold))
                .foregroundColor(isValid ? themeManager.currentTheme.primaryColor : .secondary)
                .disabled(!isValid)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
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
    
    private var heroIconSection: some View {
        VStack(spacing: 16) {
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
                                endRadius: 50 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 100 + CGFloat(index * 40), height: 100 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.05)
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
                        .frame(width: 64, height: 64)
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
                                        angle: .degrees(animationOffset * 0.8)
                                    )
                                )
                        )
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 12, x: 0, y: 6
                        )
                    
                    Image(systemName: isEditing ? "calendar.badge.checkmark" : "calendar.badge.plus")
                        .font(.forma(.title2, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text(isEditing ? "Update Academic Calendar" : "Create Academic Calendar")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Manage semester dates, breaks, and holidays to keep all your schedules perfectly organized.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }
    
    private var formContent: some View {
        VStack(spacing: 24) {
            basicDetailsSection
            dateRangeSection
        }
    }
    
    private var basicDetailsSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Calendar Name")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                TextField("e.g., Fall 2024 Semester", text: $name)
                    .font(.forma(.body))
                    .textFieldStyle(EnhancedTextFieldStyle(themeManager: themeManager))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Academic Year")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                TextField("e.g., 2024-2025", text: $academicYear)
                    .font(.forma(.body))
                    .textFieldStyle(EnhancedTextFieldStyle(themeManager: themeManager))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 12, x: 0, y: 6
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.4 : 0,
            cornerRadius: 16
        )
    }
    
    private var dateRangeSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Start Date")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.forma(.body))
                    .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("End Date")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.forma(.body))
                    .labelsHidden()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 12, x: 0, y: 6
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.4 : 0,
            cornerRadius: 16
        )
    }
    
    private func breaksManagementSection(_ cal: AcademicCalendar) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breaks & Holidays")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(cal.breaks.count) break\(cal.breaks.count == 1 ? "" : "s") configured")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink {
                    AcademicCalendarEditorView(academicCalendar: $calendar)
                        .environmentObject(academicCalendarManager)
                        .environmentObject(themeManager)
                } label: {
                    HStack(spacing: 6) {
                        Text("Manage")
                            .font(.forma(.subheadline, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.forma(.caption, weight: .bold))
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 12, x: 0, y: 6
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.4 : 0,
            cornerRadius: 16
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: saveCalendar) {
                HStack(spacing: 12) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.forma(.title3, weight: .bold))
                    
                    Text(isEditing ? "Save Changes" : "Create Calendar")
                        .font(.forma(.headline, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        isValid ? themeManager.currentTheme.primaryColor : .gray,
                                        isValid ? themeManager.currentTheme.secondaryColor.opacity(0.8) : .gray
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: isValid ? themeManager.currentTheme.primaryColor.opacity(0.4) : .gray.opacity(0.2),
                        radius: 12, x: 0, y: 6
                    )
                )
            }
            .disabled(!isValid)
            .buttonStyle(EventsBounceButtonStyle())
            
            Button("Cancel") {
                dismiss()
            }
            .font(.forma(.callout, weight: .semibold))
            .foregroundColor(.secondary)
        }
    }
    
    private func setup() {
        if let cal = calendar {
            name = cal.name
            academicYear = cal.academicYear
            startDate = cal.startDate
            endDate = cal.endDate
        } else {
            // Set up defaults for new calendar without year in name
            let currentYear = Calendar.current.component(.year, from: Date())
            academicYear = "\(currentYear)-\(currentYear + 1)"
            name = ""  // Empty name so user can enter their own
            startDate = Calendar.current.date(from: DateComponents(year: currentYear, month: 8, day: 15)) ?? Date()
            endDate = Calendar.current.date(from: DateComponents(year: currentYear + 1, month: 6, day: 15)) ?? Date()
        }
    }
    
    private func saveCalendar() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedYear = academicYear.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existingCalendar = calendar {
            // Update existing calendar
            var updatedCalendar = existingCalendar
            updatedCalendar.name = trimmedName
            updatedCalendar.academicYear = trimmedYear
            updatedCalendar.startDate = startDate
            updatedCalendar.endDate = endDate
            
            academicCalendarManager.updateCalendar(updatedCalendar)
            calendar = updatedCalendar
        } else {
            // Create new calendar - use semester as default since we removed term type picker
            let newCalendar = AcademicCalendar(
                name: trimmedName,
                academicYear: trimmedYear,
                termType: .semester,  // Default to semester
                startDate: startDate,
                endDate: endDate
            )
            
            academicCalendarManager.addCalendar(newCalendar)
        }
        
        dismiss()
    }
}

// Enhanced Text Field Style for the form
struct EnhancedTextFieldStyle: TextFieldStyle {
    let themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
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