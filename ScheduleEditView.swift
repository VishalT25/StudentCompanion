import SwiftUI

struct ScheduleEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedColor: Color = .blue
    @State private var showingDeleteAlert = false
    @State private var isLiveActivityEnabled: Bool = true
    @State private var reminderTime: ReminderTime = .none
    @State private var showingSkipOptions = false
    @State private var showingReminderPicker = false
    
    // Individual state for each day - simpler for compiler
    @State private var sunday = false
    @State private var monday = false
    @State private var tuesday = false
    @State private var wednesday = false
    @State private var thursday = false
    @State private var friday = false
    @State private var saturday = false
    
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
            _selectedColor = State(initialValue: schedule.color)
            _isLiveActivityEnabled = State(initialValue: schedule.isLiveActivityEnabled)
            _reminderTime = State(initialValue: schedule.reminderTime)
            
            // Set individual day states
            _sunday = State(initialValue: schedule.daysOfWeek.contains(.sunday))
            _monday = State(initialValue: schedule.daysOfWeek.contains(.monday))
            _tuesday = State(initialValue: schedule.daysOfWeek.contains(.tuesday))
            _wednesday = State(initialValue: schedule.daysOfWeek.contains(.wednesday))
            _thursday = State(initialValue: schedule.daysOfWeek.contains(.thursday))
            _friday = State(initialValue: schedule.daysOfWeek.contains(.friday))
            _saturday = State(initialValue: schedule.daysOfWeek.contains(.saturday))
        }
    }
    
    private var selectedDays: Set<DayOfWeek> {
        var days: Set<DayOfWeek> = []
        if sunday { days.insert(.sunday) }
        if monday { days.insert(.monday) }
        if tuesday { days.insert(.tuesday) }
        if wednesday { days.insert(.wednesday) }
        if thursday { days.insert(.thursday) }
        if friday { days.insert(.friday) }
        if saturday { days.insert(.saturday) }
        return days
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
                    Toggle("Sunday", isOn: $sunday)
                    Toggle("Monday", isOn: $monday)
                    Toggle("Tuesday", isOn: $tuesday)
                    Toggle("Wednesday", isOn: $wednesday)
                    Toggle("Thursday", isOn: $thursday)
                    Toggle("Friday", isOn: $friday)
                    Toggle("Saturday", isOn: $saturday)
                }
                
                Section("Reminder") {
                    Button(action: {
                        showingReminderPicker = true
                    }) {
                        HStack {
                            Text("Reminder")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(reminderTime.displayName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Color") {
                    ColorPicker("Schedule Color", selection: $selectedColor)
                }
                
                Section("Live Activity") {
                    Toggle("Show in Dynamic Island & Lock Screen", isOn: $isLiveActivityEnabled)
                        .tint(themeManager.currentTheme.primaryColor)
                }
                
                if let schedule = schedule {
                    Section("Skip Options") {
                        SkipControlsView(schedule: schedule)
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    }
                }
                
                if schedule != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Schedule Item")
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
                            color: selectedColor,
                            reminderTime: reminderTime,
                            isLiveActivityEnabled: isLiveActivityEnabled
                        )
                        if schedule == nil {
                            viewModel.addScheduleItem(item, themeManager: themeManager)
                        } else {
                            var updatedItem = item
                            updatedItem.id = schedule?.id ?? item.id
                            updatedItem.skippedInstanceIdentifiers = schedule?.skippedInstanceIdentifiers ?? []
                            viewModel.updateScheduleItem(updatedItem, themeManager: themeManager)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || selectedDays.isEmpty || endTime <= startTime)
                }
            }
            .sheet(isPresented: $showingReminderPicker) {
                CustomReminderPickerView(selectedReminder: $reminderTime)
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

struct SkipControlsView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let schedule: ScheduleItem
    @State private var showingSkipOptions = false
    
    private var todaysSkipStatus: Bool {
        schedule.isSkipped(onDate: Date())
    }
    
    private var thisWeekSkippedDays: [DayOfWeek] {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        
        var skippedDays: [DayOfWeek] = []
        for dayOfWeek in schedule.daysOfWeek {
            if let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.rawValue - 1, to: startOfWeek) {
                if schedule.isSkipped(onDate: dayDate) {
                    skippedDays.append(dayOfWeek)
                }
            }
        }
        return skippedDays
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today's skip status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Status")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    if todaysSkipStatus {
                        Text("Skipped")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Scheduled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.toggleSkip(forInstance: schedule, onDate: Date(), themeManager: themeManager)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: todaysSkipStatus ? "arrow.clockwise" : "xmark")
                            .font(.caption)
                        Text(todaysSkipStatus ? "Unskip Today" : "Skip Today")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // This week's skip status
            if !thisWeekSkippedDays.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skipped This Week")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(thisWeekSkippedDays, id: \.self) { day in
                            HStack(spacing: 4) {
                                Text(day.shortName)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.orange)
                                
                                Button {
                                    let calendar = Calendar.current
                                    let today = Date()
                                    guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
                                          let dayDate = calendar.date(byAdding: .day, value: day.rawValue - 1, to: startOfWeek) else { return }
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.toggleSkip(forInstance: schedule, onDate: dayDate, themeManager: themeManager)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                    }
                }
            }
            
            // Week skip options
            Button {
                showingSkipOptions = true
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text("Skip Week Options")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .confirmationDialog("Skip Week Options", isPresented: $showingSkipOptions, titleVisibility: .visible) {
            Button("Skip remaining classes this week") {
                skipRemainingThisWeek()
            }
            Button("Skip all classes this week") {
                skipAllThisWeek()
            }
            Button("Unskip all classes this week") {
                unskipAllThisWeek()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you want to manage classes for \(schedule.title) this week")
        }
    }
    
    private func skipRemainingThisWeek() {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return }
        
        for dayOfWeek in schedule.daysOfWeek {
            if dayOfWeek.rawValue >= currentWeekday {
                if let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.rawValue - 1, to: startOfWeek) {
                    if !schedule.isSkipped(onDate: dayDate) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.toggleSkip(forInstance: schedule, onDate: dayDate, themeManager: themeManager)
                        }
                    }
                }
            }
        }
    }
    
    private func skipAllThisWeek() {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return }
        
        for dayOfWeek in schedule.daysOfWeek {
            if let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.rawValue - 1, to: startOfWeek) {
                if !schedule.isSkipped(onDate: dayDate) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.toggleSkip(forInstance: schedule, onDate: dayDate, themeManager: themeManager)
                    }
                }
            }
        }
    }
    
    private func unskipAllThisWeek() {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return }
        
        for dayOfWeek in schedule.daysOfWeek {
            if let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.rawValue - 1, to: startOfWeek) {
                if schedule.isSkipped(onDate: dayDate) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.toggleSkip(forInstance: schedule, onDate: dayDate, themeManager: themeManager)
                    }
                }
            }
        }
    }
}
