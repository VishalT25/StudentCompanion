import SwiftUI

struct EditAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let calendar: AcademicCalendar
    @State private var editedCalendar: AcademicCalendar
    @State private var showingBreakManager = false
    
    init(calendar: AcademicCalendar) {
        self.calendar = calendar
        self._editedCalendar = State(initialValue: calendar)
    }
    
    private var isValid: Bool {
        !editedCalendar.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editedCalendar.academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editedCalendar.endDate > editedCalendar.startDate
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navigationHeader
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Basic Info Section
                        basicInfoSection
                        
                        // Breaks Management Section
                        breaksSection
                        
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
        }
        .sheet(isPresented: $showingBreakManager) {
            BreaksManagerView(calendar: $editedCalendar)
                .environmentObject(themeManager)
                .environmentObject(academicCalendarManager)
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
            
            Text("Edit Calendar")
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
    
    private var basicInfoSection: some View {
        VStack(spacing: 20) {
            FormFieldView(
                icon: "text.alignleft",
                title: "Calendar Name",
                content: {
                    TextField("Calendar Name", text: $editedCalendar.name)
                        .font(.forma(.body))
                }
            )
            
            FormFieldView(
                icon: "calendar",
                title: "Academic Year",
                content: {
                    TextField("Academic Year", text: $editedCalendar.academicYear)
                        .font(.forma(.body))
                }
            )
            
            FormFieldView(
                icon: "calendar.badge.plus",
                title: "Start Date",
                content: {
                    DatePicker("", selection: $editedCalendar.startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            )
            
            FormFieldView(
                icon: "calendar.badge.minus",
                title: "End Date",
                content: {
                    DatePicker("", selection: $editedCalendar.endDate, in: editedCalendar.startDate..., displayedComponents: .date)
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
    
    private var breaksSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breaks & Holidays")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(editedCalendar.breaks.count) break\(editedCalendar.breaks.count == 1 ? "" : "s") configured")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showingBreakManager = true
                } label: {
                    HStack(spacing: 8) {
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
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Preview of breaks
            if !editedCalendar.breaks.isEmpty {
                let upcomingBreaks = editedCalendar.breaks
                    .filter { $0.endDate >= Date() }
                    .sorted { $0.startDate < $1.startDate }
                    .prefix(3)
                
                if !upcomingBreaks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(upcomingBreaks), id: \.id) { break_ in
                            HStack(spacing: 12) {
                                Image(systemName: break_.type.icon)
                                    .font(.forma(.caption))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(break_.name)
                                        .font(.forma(.caption, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(break_.startDate, format: .dateTime.day().month().year())
                                        .font(.forma(.caption2))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(break_.type.displayName)
                                    .font(.forma(.caption2, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(themeManager.currentTheme.primaryColor.opacity(0.15))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
            }
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
        }
    }
    
    private func saveChanges() {
        academicCalendarManager.updateCalendar(editedCalendar)
        dismiss()
    }
}