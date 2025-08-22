import SwiftUI

struct AddEditAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @Binding var calendar: AcademicCalendar?
    
    @State private var name: String = ""
    @State private var academicYear: String = ""
    @State private var termType: AcademicTermType = .semester
    @State private var startDate = Date()
    @State private var endDate = Date()
    
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
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    formContent
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .onAppear(perform: setup)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Text(isEditing ? "Edit Calendar" : "Create Academic Calendar")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("Academic calendars help manage semester dates, breaks, and holidays across all your schedules.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
    
    private var formContent: some View {
        VStack(spacing: 20) {
            basicDetailsSection
            dateRangeSection
            
            if isEditing, let cal = calendar {
                breaksManagementSection(cal)
            }
            
            actionButtonsSection
        }
    }
    
    private var basicDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Details")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                CustomTextField(
                    title: "Calendar Name",
                    placeholder: "e.g., Fall 2024 Semester",
                    text: $name,
                    icon: "text.alignleft"
                )
                
                CustomTextField(
                    title: "Academic Year",
                    placeholder: "e.g., 2024-2025",
                    text: $academicYear,
                    icon: "calendar"
                )
                
                termTypePickerSection
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var termTypePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 24)
                
                Text("Term Type")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            Picker("Term Type", selection: $termType) {
                ForEach(AcademicTermType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Academic Year Duration")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                CustomDatePicker(
                    title: "Start Date",
                    date: $startDate,
                    icon: "calendar.badge.plus"
                )
                
                CustomDatePicker(
                    title: "End Date",
                    date: $endDate,
                    icon: "calendar.badge.minus"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func breaksManagementSection(_ cal: AcademicCalendar) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breaks & Holidays")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            NavigationLink {
                AcademicCalendarEditorView(academicCalendar: $calendar)
                    .environmentObject(academicCalendarManager)
                    .environmentObject(themeManager)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Breaks")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("\(cal.breaks.count) break\(cal.breaks.count == 1 ? "" : "s") configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: saveCalendar) {
                HStack(spacing: 8) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                    
                    Text(isEditing ? "Save Changes" : "Create Calendar")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isValid ? themeManager.currentTheme.primaryColor : Color.gray)
                )
            }
            .disabled(!isValid)
            
            Button("Cancel") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }
    
    private func setup() {
        if let cal = calendar {
            name = cal.name
            academicYear = cal.academicYear
            termType = cal.termType
            startDate = cal.startDate
            endDate = cal.endDate
        } else {
            // Set up defaults for new calendar
            let currentYear = Calendar.current.component(.year, from: Date())
            academicYear = "\(currentYear)-\(currentYear + 1)"
            name = "Academic Year \(academicYear)"
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
            updatedCalendar.termType = termType
            updatedCalendar.startDate = startDate
            updatedCalendar.endDate = endDate
            
            academicCalendarManager.updateCalendar(updatedCalendar)
            calendar = updatedCalendar
        } else {
            // Create new calendar
            let newCalendar = AcademicCalendar(
                name: trimmedName,
                academicYear: trimmedYear,
                termType: termType,
                startDate: startDate,
                endDate: endDate
            )
            
            academicCalendarManager.addCalendar(newCalendar)
        }
        
        dismiss()
    }
}