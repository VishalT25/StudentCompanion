import SwiftUI

struct ScheduleEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var selectedColor: Color = .blue
    @State private var showingDeleteAlert = false
    let schedule: ScheduleItem?
    let onDelete: (() -> Void)?
    let onToggleSkip: (() -> Void)?
    
    init(schedule: ScheduleItem? = nil, onDelete: (() -> Void)? = nil, onToggleSkip: (() -> Void)? = nil) {
        self.schedule = schedule
        self.onDelete = onDelete
        self.onToggleSkip = onToggleSkip
        if let schedule = schedule {
            _title = State(initialValue: schedule.title)
            _startTime = State(initialValue: schedule.startTime)
            _endTime = State(initialValue: schedule.endTime)
            _selectedDays = State(initialValue: schedule.daysOfWeek)
            _selectedColor = State(initialValue: schedule.color)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Schedule Details") {
                    TextField("Title", text: $title)
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Repeats On") {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        Toggle(day.shortName, isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(day)
                                } else {
                                    selectedDays.remove(day)
                                }
                            }
                        ))
                    }
                }
                
                Section("Color") {
                    ColorPicker("Schedule Color", selection: $selectedColor)
                }
                
                if let schedule = schedule {
                    Section("Actions") {
                        // Skip toggle button
                        Button {
                            onToggleSkip?()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: schedule.isSkippedForCurrentWeek() ? "arrow.clockwise" : "pause.circle")
                                    .foregroundColor(schedule.isSkippedForCurrentWeek() ? .green : .orange)
                                Text(schedule.isSkippedForCurrentWeek() ? "Unskip This Week" : "Skip This Week")
                                    .foregroundColor(schedule.isSkippedForCurrentWeek() ? .green : .orange)
                                Spacer()
                            }
                        }
                        
                        // Delete button
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Schedule")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(schedule == nil ? "Add Schedule" : "Edit Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(schedule == nil ? "Add" : "Save") {
                        let item = ScheduleItem(
                            title: title,
                            startTime: startTime,
                            endTime: endTime,
                            daysOfWeek: selectedDays,
                            color: selectedColor
                        )
                        if schedule == nil {
                            viewModel.addScheduleItem(item)
                        } else {
                            var updatedItem = item
                            updatedItem.id = schedule?.id ?? item.id
                            updatedItem.skippedWeeks = schedule?.skippedWeeks ?? []
                            viewModel.updateScheduleItem(updatedItem)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || selectedDays.isEmpty || endTime <= startTime)
                }
            }
        }
        .alert("Delete Schedule Item", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this schedule item? This action cannot be undone.")
        }
    }
}
