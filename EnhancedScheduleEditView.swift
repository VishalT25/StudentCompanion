import SwiftUI

struct EnhancedScheduleEditView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let scheduleItem: ScheduleItem?
    let scheduleID: UUID
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedColor: Color = .blue
    @State private var reminderTime: ReminderTime = .none
    @State private var isLiveActivityEnabled = true
    @State private var showingDeleteAlert = false
    
    // Day selection
    @State private var selectedDays: Set<DayOfWeek> = []
    
    var isEditing: Bool { scheduleItem != nil }
    
    init(scheduleItem: ScheduleItem?, scheduleID: UUID) {
        self.scheduleItem = scheduleItem
        self.scheduleID = scheduleID
        
        if let item = scheduleItem {
            _title = State(initialValue: item.title)
            _startTime = State(initialValue: item.startTime)
            _endTime = State(initialValue: item.endTime)
            _selectedColor = State(initialValue: item.color)
            _reminderTime = State(initialValue: item.reminderTime)
            _isLiveActivityEnabled = State(initialValue: item.isLiveActivityEnabled)
            _selectedDays = State(initialValue: item.daysOfWeek)
        } else {
            // Set reasonable default times for new schedule items
            let calendar = Calendar.current
            let now = Date()
            
            // Default start time: 9:00 AM
            let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
            // Default end time: 10:00 AM
            let defaultEndTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(3600)
            
            _startTime = State(initialValue: defaultStartTime)
            _endTime = State(initialValue: defaultEndTime)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Class Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Class Details", icon: "book.fill")
                        
                        VStack(spacing: 12) {
                            CustomTextField(title: "Class Name", text: $title, placeholder: "e.g., Introduction to Psychology")
                            
                            TimePickerRow(title: "Start Time", time: $startTime)
                            TimePickerRow(title: "End Time", time: $endTime)
                            
                            ColorPickerRow(title: "Class Color", color: $selectedColor)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                    }
                    
                    // Schedule Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Schedule", icon: "calendar")
                        
                        DaySelectionGrid(selectedDays: $selectedDays)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Preferences", icon: "gear")
                        
                        VStack(spacing: 16) {
                            ReminderPickerRow(reminderTime: $reminderTime)
                            
                            ToggleRow(
                                title: "Live Activity",
                                subtitle: "Show in Dynamic Island & Lock Screen",
                                isOn: $isLiveActivityEnabled,
                                color: themeManager.currentTheme.primaryColor
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                    }
                    
                    // Skip Controls (if editing)
                    if let item = scheduleItem {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Skip Options", icon: "xmark.circle")
                            
                            EnhancedSkipControlsView(schedule: item, scheduleID: scheduleID)
                                .environmentObject(scheduleManager)
                                .environmentObject(themeManager)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                        }
                    }
                    
                    // Delete Button (if editing)
                    if isEditing {
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Class")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(16)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Class" : "Add Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveScheduleItem()
                    }
                    .disabled(!isValidInput)
                    .foregroundColor(isValidInput ? themeManager.currentTheme.primaryColor : .secondary)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Delete Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = scheduleItem {
                    scheduleManager.deleteScheduleItem(item, from: scheduleID)
                }
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this class? This action cannot be undone.")
        }
    }
    
    private var isValidInput: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedDays.isEmpty &&
        endTime > startTime
    }
    
    private func saveScheduleItem() {
        // Normalize times to ensure they only contain time components, not date
        let normalizedStartTime = normalizeTimeToToday(startTime)
        let normalizedEndTime = normalizeTimeToToday(endTime)
        
        let newItem = ScheduleItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: normalizedStartTime,
            endTime: normalizedEndTime,
            daysOfWeek: selectedDays,
            color: selectedColor,
            reminderTime: reminderTime,
            isLiveActivityEnabled: isLiveActivityEnabled
        )
        
        if let existingItem = scheduleItem {
            var updatedItem = newItem
            updatedItem.id = existingItem.id
            updatedItem.skippedInstanceIdentifiers = existingItem.skippedInstanceIdentifiers
            scheduleManager.updateScheduleItem(updatedItem, in: scheduleID)
        } else {
            scheduleManager.addScheduleItem(newItem, to: scheduleID)
        }
        
        dismiss()
    }
    
    // Helper function to normalize time to today's date with the selected time
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

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
        }
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
        }
    }
}

struct TimePickerRow: View {
    let title: String
    @Binding var time: Date
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, height: 44)
        }
    }
}

struct ReminderPickerRow: View {
    @Binding var reminderTime: ReminderTime
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Text("Reminder")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(reminderTime.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            CustomReminderPickerView(selectedReminder: $reminderTime)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let color: Color
    
    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.color = color
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(color)
        }
    }
}

struct DaySelectionGrid: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDays: Set<DayOfWeek>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat On")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    DayToggleButton(
                        day: day,
                        isSelected: selectedDays.contains(day),
                        color: themeManager.currentTheme.primaryColor
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        }
                    }
                }
            }
            
            // Quick select buttons
            HStack(spacing: 12) {
                QuickSelectButton(title: "Weekdays", color: themeManager.currentTheme.secondaryColor) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                    }
                }
                
                QuickSelectButton(title: "Weekend", color: themeManager.currentTheme.secondaryColor) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDays = [.saturday, .sunday]
                    }
                }
                
                Spacer()
                
                Button("Clear") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDays.removeAll()
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            }
        }
    }
}

struct DayToggleButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(day.shortName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(isSelected ? .white : color)
                
                Text(dayFullName(day))
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func dayFullName(_ day: DayOfWeek) -> String {
        switch day {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct QuickSelectButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct EnhancedSkipControlsView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let schedule: ScheduleItem
    let scheduleID: UUID
    
    private var todaysSkipStatus: Bool {
        schedule.isSkipped(onDate: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today's status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Status")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(todaysSkipStatus ? "Skipped" : "Scheduled")
                        .font(.caption)
                        .foregroundColor(todaysSkipStatus ? .orange : .green)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scheduleManager.toggleSkip(forItem: schedule, onDate: Date(), in: scheduleID)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: todaysSkipStatus ? "arrow.clockwise" : "xmark")
                        Text(todaysSkipStatus ? "Unskip" : "Skip Today")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(todaysSkipStatus ? Color.green : Color.orange)
                    .cornerRadius(8)
                }
            }
        }
    }
}