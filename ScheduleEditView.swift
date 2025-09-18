import SwiftUI

struct ScheduleEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // Core fields
    @State private var title = ""
    @State private var instructor = ""
    @State private var location = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var showingDeleteAlert = false
    @State private var isLiveActivityEnabled: Bool = true
    @State private var reminderTime: ReminderTime = .none
    @State private var showingReminderPicker = false
    
    // Individual state for each day
    @State private var sunday = false
    @State private var monday = false
    @State private var tuesday = false
    @State private var wednesday = false
    @State private var thursday = false
    @State private var friday = false
    @State private var saturday = false
    
    let schedule: ScheduleItem?
    let scheduleID: UUID
    let onDelete: (() -> Void)?
    
    init(schedule: ScheduleItem? = nil, scheduleID: UUID, onDelete: (() -> Void)? = nil) {
        self.schedule = schedule
        self.scheduleID = scheduleID
        self.onDelete = onDelete
        
        if let schedule = schedule {
            self._title = State(initialValue: schedule.title)
            self._instructor = State(initialValue: schedule.instructor)
            self._location = State(initialValue: schedule.location)
            self._startTime = State(initialValue: schedule.startTime)
            self._endTime = State(initialValue: schedule.endTime)
            self._isLiveActivityEnabled = State(initialValue: schedule.isLiveActivityEnabled)
            self._reminderTime = State(initialValue: schedule.reminderTime)
            
            let daysOfWeek = schedule.daysOfWeek
            self._sunday = State(initialValue: daysOfWeek.contains(.sunday))
            self._monday = State(initialValue: daysOfWeek.contains(.monday))
            self._tuesday = State(initialValue: daysOfWeek.contains(.tuesday))
            self._wednesday = State(initialValue: daysOfWeek.contains(.wednesday))
            self._thursday = State(initialValue: daysOfWeek.contains(.thursday))
            self._friday = State(initialValue: daysOfWeek.contains(.friday))
            self._saturday = State(initialValue: daysOfWeek.contains(.saturday))
        } else {
            // Defaults for new
            let calendar = Calendar.current
            let now = Date()
            let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
            let defaultEndTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(3600)
            self._startTime = State(initialValue: defaultStartTime)
            self._endTime = State(initialValue: defaultEndTime)
        }
    }
    
    private var selectedDays: [DayOfWeek] {
        var days: [DayOfWeek] = []
        if sunday { days.append(.sunday) }
        if monday { days.append(.monday) }
        if tuesday { days.append(.tuesday) }
        if wednesday { days.append(.wednesday) }
        if thursday { days.append(.thursday) }
        if friday { days.append(.friday) }
        if saturday { days.append(.saturday) }
        return days
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedDays.isEmpty &&
        endTime > startTime
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // DETAILS CARD
                    VStack(alignment: .leading, spacing: 16) {
                        EditSectionHeader(title: "Class Details", icon: "book.fill", color: themeManager.currentTheme.primaryColor)
                        
                        VStack(spacing: 12) {
                            IconTextFieldRow(title: "Class Name", text: $title, icon: "text.alignleft", placeholder: "e.g., Linear Algebra")
                            IconTextFieldRow(title: "Professor", text: $instructor, icon: "person.fill", placeholder: "Optional")
                            IconTextFieldRow(title: "Location", text: $location, icon: "location.fill", placeholder: "Optional")
                        }
                        
                        Divider().padding(.top, 4)
                        
                        // Time pickers
                        VStack(spacing: 12) {
                            ScheduleTimePickerRow(label: "Start Time", date: $startTime, icon: "clock")
                            ScheduleTimePickerRow(label: "End Time", date: $endTime, icon: "clock.arrow.circlepath")
                        }
                        
                        if endTime <= startTime {
                            Text("End time must be later than start time")
                                .font(.forma(.caption))
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    }
                    .cardStyle(themeManager)
                    
                    // DAYS CARD
                    VStack(alignment: .leading, spacing: 16) {
                        EditSectionHeader(title: "Repeats On", icon: "calendar", color: themeManager.currentTheme.secondaryColor)
                        
                        DayChips(
                            sunday: $sunday,
                            monday: $monday,
                            tuesday: $tuesday,
                            wednesday: $wednesday,
                            thursday: $thursday,
                            friday: $friday,
                            saturday: $saturday,
                            accent: themeManager.currentTheme.primaryColor
                        )
                        
                        if selectedDays.isEmpty {
                            Text("Choose at least one day")
                                .font(.forma(.caption))
                                .foregroundColor(.orange)
                        }
                    }
                    .cardStyle(themeManager)
                    
                    // REMINDER & LIVE ACTIVITY
                    VStack(alignment: .leading, spacing: 12) {
                        EditSectionHeader(title: "Preferences", icon: "gearshape.fill", color: themeManager.currentTheme.primaryColor)
                        
                        Button {
                            showingReminderPicker = true
                        } label: {
                            HStack {
                                Label("Reminder", systemImage: "bell")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundColor(.primary)
                                    .font(.forma(.subheadline, weight: .medium))
                                Spacer()
                                Text(reminderTime.displayName)
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                        
                        Toggle(isOn: $isLiveActivityEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Activity")
                                    .font(.forma(.subheadline, weight: .semibold))
                                Text("Show in Dynamic Island & Lock Screen")
                                    .font(.forma(.caption))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(themeManager.currentTheme.primaryColor)
                        .padding(.horizontal, 2)
                    }
                    .cardStyle(themeManager)
                    
                    // SKIP CONTROLS (if editing)
                    if let schedule = schedule {
                        VStack(alignment: .leading, spacing: 14) {
                            EditSectionHeader(title: "Skip Options", icon: "calendar.badge.minus", color: .orange)
                            SkipControlsView(schedule: schedule, scheduleID: scheduleID)
                                .environmentObject(scheduleManager)
                                .environmentObject(themeManager)
                        }
                        .cardStyle(themeManager)
                    }
                    
                    // DELETE BUTTON (if editing)
                    if schedule != nil {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Class")
                                    .font(.forma(.subheadline, weight: .semibold))
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.25), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(schedule == nil ? "Add Class" : "Edit Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(schedule == nil ? "Add" : "Save") {
                        handleSave()
                    }
                    .disabled(!isValid)
                    .foregroundColor(isValid ? themeManager.currentTheme.primaryColor : .secondary)
                    .fontWeight(.semibold)
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
    
    private func handleSave() {
        let normalizedStartTime = normalizeTimeToToday(startTime)
        let normalizedEndTime = normalizeTimeToToday(endTime)
        
        let item = ScheduleItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: normalizedStartTime,
            endTime: normalizedEndTime,
            daysOfWeek: selectedDays,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
            color: (schedule?.color ?? themeManager.currentTheme.primaryColor),
            skippedInstanceIdentifiers: [],
            isLiveActivityEnabled: isLiveActivityEnabled,
            reminderTime: reminderTime
        )
        
        if schedule == nil {
            scheduleManager.addScheduleItem(item, to: scheduleID)
        } else {
            var updatedItem = item
            updatedItem.id = schedule?.id ?? item.id
            updatedItem.skippedInstanceIdentifiers = schedule?.skippedInstanceIdentifiers ?? []
            scheduleManager.updateScheduleItem(updatedItem, in: scheduleID)
        }
        dismiss()
    }
    
    // Normalize to today's date at selected time components
    private func normalizeTimeToToday(_ time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                             minute: timeComponents.minute ?? 0,
                             second: timeComponents.second ?? 0,
                             of: now) ?? time
    }
}

// MARK: - Cards & Rows

private struct EditSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.forma(.subheadline, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(color.opacity(0.12))
                        .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1))
                )
            Text(title)
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

private struct IconTextFieldRow: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                TextField(placeholder, text: $text)
                    .font(.forma(.subheadline))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
    }
}

private struct ScheduleTimePickerRow: View {
    let label: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .font(.forma(.subheadline))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
    }
}

private struct DayChips: View {
    @Binding var sunday: Bool
    @Binding var monday: Bool
    @Binding var tuesday: Bool
    @Binding var wednesday: Bool
    @Binding var thursday: Bool
    @Binding var friday: Bool
    @Binding var saturday: Bool
    let accent: Color
    
    var body: some View {
        let rows: [[(String, Binding<Bool>)]] = [
            [("Sun", $sunday), ("Mon", $monday), ("Tue", $tuesday), ("Wed", $wednesday)],
            [("Thu", $thursday), ("Fri", $friday), ("Sat", $saturday)]
        ]
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<rows[row].count, id: \.self) { col in
                        let item = rows[row][col]
                        DayChip(label: item.0, isOn: item.1, accent: accent)
                    }
                }
            }
        }
    }
}

private struct DayChip: View {
    let label: String
    @Binding var isOn: Bool
    let accent: Color
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isOn.toggle()
            }
        } label: {
            Text(label)
                .font(.forma(.caption, weight: .semibold))
                .foregroundColor(isOn ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isOn ? accent : Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isOn ? accent.opacity(0.0) : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private extension View {
    func cardStyle(_ themeManager: ThemeManager) -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
            )
    }
}

// MARK: - SkipControlsView (unchanged)

struct SkipControlsView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let schedule: ScheduleItem
    let scheduleID: UUID
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
                        scheduleManager.toggleSkip(forItem: schedule, onDate: Date(), in: scheduleID)
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
            
            if !thisWeekSkippedDays.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skipped This Week")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(thisWeekSkippedDays, id: \.self) { day in
                            HStack(spacing: 4) {
                                Text(day.short)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.orange)
                                
                                Button {
                                    let calendar = Calendar.current
                                    let today = Date()
                                    guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
                                          let dayDate = calendar.date(byAdding: .day, value: day.rawValue - 1, to: startOfWeek) else { return }
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        scheduleManager.toggleSkip(forItem: schedule, onDate: dayDate, in: scheduleID)
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
                            scheduleManager.toggleSkip(forItem: schedule, onDate: dayDate, in: scheduleID)
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
                        scheduleManager.toggleSkip(forItem: schedule, onDate: dayDate, in: scheduleID)
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
                        scheduleManager.toggleSkip(forItem: schedule, onDate: dayDate, in: scheduleID)
                    }
                }
            }
        }
    }
}