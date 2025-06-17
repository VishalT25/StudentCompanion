import SwiftUI

struct CustomReminderPickerView: View {
    @Binding var selectedReminder: ReminderTime
    @Environment(\.dismiss) private var dismiss
    
    @State private var customValue: String = "15"
    @State private var selectedUnit: TimeUnit = .minutes
    @State private var useCustom: Bool = false
    
    enum TimeUnit: String, CaseIterable {
        case minutes = "Minutes"
        case hours = "Hours"
        case days = "Days"
        case weeks = "Weeks"
        
        var shortName: String {
            switch self {
            case .minutes: return "min"
            case .hours: return "hr"
            case .days: return "day"
            case .weeks: return "wk"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Common presets section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Select")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ReminderTime.commonPresets, id: \.id) { preset in
                            Button(action: {
                                selectedReminder = preset
                                useCustom = false
                            }) {
                                VStack(spacing: 4) {
                                    Text(preset.shortDisplayName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(preset.displayName)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundColor(selectedReminder == preset && !useCustom ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedReminder == preset && !useCustom ? Color.blue : Color(.systemGray6))
                                )
                            }
                        }
                    }
                }
                
                Divider()
                
                // Custom time section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Custom Time")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $useCustom)
                            .labelsHidden()
                    }
                    
                    if useCustom {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("Value", text: $customValue)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .frame(width: 80)
                                
                                Picker("Unit", selection: $selectedUnit) {
                                    ForEach(TimeUnit.allCases, id: \.self) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Preview of custom time
                            if let value = Int(customValue), value > 0 {
                                let customReminder = createCustomReminder(value: value, unit: selectedUnit)
                                Text("Preview: \(customReminder.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // Apply button
                Button(action: applySelection) {
                    Text("Set Reminder")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(useCustom && (customValue.isEmpty || Int(customValue) == nil || Int(customValue)! <= 0))
            }
            .padding()
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            updateFromCurrentSelection()
        }
    }
    
    private func createCustomReminder(value: Int, unit: TimeUnit) -> ReminderTime {
        switch unit {
        case .minutes:
            return .minutes(value)
        case .hours:
            return .hours(value)
        case .days:
            return .days(value)
        case .weeks:
            return .weeks(value)
        }
    }
    
    private func applySelection() {
        if useCustom {
            if let value = Int(customValue), value > 0 {
                selectedReminder = createCustomReminder(value: value, unit: selectedUnit)
            }
        }
        // If not using custom, selectedReminder is already set by preset buttons
        dismiss()
    }
    
    private func updateFromCurrentSelection() {
        // Check if current selection matches any preset
        let matchesPreset = ReminderTime.commonPresets.contains(selectedReminder)
        
        if !matchesPreset && selectedReminder != .none {
            useCustom = true
            
            switch selectedReminder {
            case .none:
                break
            case .minutes(let m):
                customValue = String(m)
                selectedUnit = .minutes
            case .hours(let h):
                customValue = String(h)
                selectedUnit = .hours
            case .days(let d):
                customValue = String(d)
                selectedUnit = .days
            case .weeks(let w):
                customValue = String(w)
                selectedUnit = .weeks
            }
        }
    }
}

// MARK: - Preview
struct CustomReminderPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomReminderPickerView(selectedReminder: .constant(.minutes(15)))
    }
}