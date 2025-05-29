import SwiftUI

struct ScheduleEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EventViewModel
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var selectedColor: Color = .blue
    let schedule: ScheduleItem?
    
    init(schedule: ScheduleItem? = nil) {
        self.schedule = schedule
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
                            viewModel.updateScheduleItem(item)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || selectedDays.isEmpty || endTime <= startTime)
                }
            }
        }
    }
}