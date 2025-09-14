import SwiftUI

struct EditBreakView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var calendar: AcademicCalendar
    let academicBreak: AcademicBreak
    
    @State private var name: String = ""
    @State private var type: BreakType = .custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var description: String = ""
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navigationHeader
                
                ScrollView {
                    VStack(spacing: 32) {
                        heroSection
                        formSection
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
                setupFromBreak()
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
            
            Text("Edit Break")
                .font(.forma(.headline, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Save") {
                saveChanges()
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
                                    themeManager.currentTheme.primaryColor.opacity(0.10 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 100 + CGFloat(index * 40), height: 100 + CGFloat(index * 40))
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
                        .frame(width: 72, height: 72)
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
                    
                    Image(systemName: type.icon)
                        .font(.forma(.title2, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text("Edit Academic Break")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Update break information and dates.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 24) {
            // Basic Details
            VStack(spacing: 20) {
                FormFieldView(
                    icon: "text.alignleft",
                    title: "Break Name",
                    content: {
                        TextField("Break Name", text: $name)
                            .font(.forma(.body))
                    }
                )
                
                FormFieldView(
                    icon: "tag",
                    title: "Type",
                    content: {
                        Picker("Type", selection: $type) {
                            ForEach(BreakType.allCases, id: \.self) { breakType in
                                HStack {
                                    Image(systemName: breakType.icon)
                                    Text(breakType.displayName)
                                }
                                .tag(breakType)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.forma(.body))
                    }
                )
                
                FormFieldView(
                    icon: "note.text",
                    title: "Description (Optional)",
                    content: {
                        TextField("Add notes about this break", text: $description, axis: .vertical)
                            .font(.forma(.body))
                            .lineLimit(2...4)
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
            
            // Dates
            VStack(spacing: 20) {
                FormFieldView(
                    icon: "calendar.badge.plus",
                    title: "Start Date",
                    content: {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .onChange(of: startDate) { _, newValue in
                                if endDate < newValue {
                                    endDate = newValue
                                }
                            }
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
                saveChanges()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.forma(.title3, weight: .bold))
                    
                    Text("Save Changes")
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
            pulseAnimation = 1.05
        }
        
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private func setupFromBreak() {
        name = academicBreak.name
        type = academicBreak.type
        startDate = academicBreak.startDate
        endDate = academicBreak.endDate
        description = academicBreak.description
    }
    
    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let index = calendar.breaks.firstIndex(where: { $0.id == academicBreak.id }) {
            calendar.breaks[index].name = trimmedName
            calendar.breaks[index].type = type
            calendar.breaks[index].startDate = startDate
            calendar.breaks[index].endDate = endDate
            calendar.breaks[index].description = description
        }
        
        dismiss()
    }
}