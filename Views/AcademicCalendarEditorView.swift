import SwiftUI

struct AcademicCalendarEditorView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var academicCalendar: AcademicCalendar?
    @State private var showingAddBreak = false
    @State private var breakToEdit: AcademicBreak?

    var body: some View {
        Form {
            Section(header: Text("Academic Year")) {
                TextField("Year (e.g., 2024-2025)", text: Binding(
                    get: { academicCalendar?.academicYear ?? "" },
                    set: { academicCalendar?.academicYear = $0 }
                ))
            }

            Section(header: Text("Breaks & Holidays")) {
                if let breaks = academicCalendar?.breaks, !breaks.isEmpty {
                    ForEach(breaks) { academicBreak in
                        Button(action: { breakToEdit = academicBreak }) {
                            HStack {
                                Image(systemName: academicBreak.type.icon)
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                VStack(alignment: .leading) {
                                    Text(academicBreak.name).foregroundColor(.primary)
                                    Text("\(academicBreak.startDate.formatted(date: .abbreviated, time: .omitted)) - \(academicBreak.endDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteBreak)
                } else {
                    Text("No breaks added yet.")
                        .foregroundColor(.secondary)
                }
                
                Button(action: { showingAddBreak = true }) {
                    Label("Add Break or Holiday", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Academic Calendar")
        .sheet(isPresented: $showingAddBreak) {
            AddEditAcademicBreakView(calendar: $academicCalendar, breakToEdit: .constant(nil))
                .environmentObject(themeManager)
        }
        .sheet(item: $breakToEdit) { academicBreak in
            AddEditAcademicBreakView(calendar: $academicCalendar, breakToEdit: .constant(academicBreak))
                .environmentObject(themeManager)
        }
    }

    private func deleteBreak(at offsets: IndexSet) {
        academicCalendar?.breaks.remove(atOffsets: offsets)
    }
}

struct AddEditAcademicBreakView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Binding var calendar: AcademicCalendar?
    @Binding var breakToEdit: AcademicBreak?
    
    @State private var name: String = ""
    @State private var type: BreakType = .custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    private var isEditing: Bool {
        breakToEdit != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Break Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(BreakType.allCases, id: \.self) { breakType in
                            Text(breakType.displayName).tag(breakType)
                        }
                    }
                }
                
                Section(header: Text("Dates")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle(isEditing ? "Edit Break" : "Add Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveBreak()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: setup)
        }
    }
    
    private func setup() {
        guard let breakToEdit = breakToEdit else { return }
        name = breakToEdit.name
        type = breakToEdit.type
        startDate = breakToEdit.startDate
        endDate = breakToEdit.endDate
    }
    
    private func saveBreak() {
        if let breakToEdit = breakToEdit, let index = calendar?.breaks.firstIndex(where: { $0.id == breakToEdit.id }) {
            // Update existing break
            calendar?.breaks[index].name = name
            calendar?.breaks[index].type = type
            calendar?.breaks[index].startDate = startDate
            calendar?.breaks[index].endDate = endDate
        } else {
            // Add new break
            let newBreak = AcademicBreak(name: name, type: type, startDate: startDate, endDate: endDate)
            calendar?.breaks.append(newBreak)
        }
    }
}