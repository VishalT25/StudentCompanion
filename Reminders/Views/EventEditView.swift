import SwiftUI

struct EventEditView: View {
    let event: Event
    let isNew: Bool
    
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var title: String
    @State private var date: Date
    @State private var categoryId: UUID?
    @State private var reminderTime: ReminderTime
    @State private var syncToApple: Bool
    @State private var syncToGoogle: Bool
    @State private var isCompleted: Bool
    @State private var showDeleteAlert = false
    
    private var currentCategory: Category? {
        guard let categoryId = categoryId else { return nil }
        return viewModel.categories.first { $0.id == categoryId }
    }
    
    private var primaryColor: Color {
        currentCategory?.color ?? themeManager.currentTheme.primaryColor
    }
    
    init(event: Event, isNew: Bool = false) {
        self.event = event
        self.isNew = isNew
        
        _title = State(initialValue: event.title)
        _date = State(initialValue: event.date)
        _categoryId = State(initialValue: event.categoryId)
        _reminderTime = State(initialValue: event.reminderTime)
        _syncToApple = State(initialValue: event.syncToAppleCalendar)
        _syncToGoogle = State(initialValue: event.syncToGoogleCalendar)
        _isCompleted = State(initialValue: event.isCompleted)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(isNew ? "New Reminder" : "Edit Reminder")
                            .font(.forma(.largeTitle, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [primaryColor, primaryColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .padding(.top)
                    
                    VStack(spacing: 20) {
                        // Title Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(primaryColor)
                                Text("Title")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                TextField("Reminder title", text: $title)
                                    .font(.forma(.body))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                Spacer()
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Date & Time
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(primaryColor)
                                Text("Date & Time")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                DatePicker("Select date and time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(primaryColor)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Category
                        if !viewModel.categories.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "tag")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(primaryColor)
                                    Text("Category")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Picker("Category", selection: $categoryId) {
                                        Text("No Category")
                                            .tag(nil as UUID?)
                                        ForEach(viewModel.categories) { category in
                                            HStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(category.color)
                                                    .frame(width: 12, height: 12)
                                                Text(category.name)
                                                    .font(.forma(.body))
                                            }
                                            .tag(category.id as UUID?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(primaryColor)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        
                        // Reminder Time
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.fill")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(primaryColor)
                                Text("Notification")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Picker("Notification", selection: $reminderTime) {
                                    ForEach(ReminderTime.allCases, id: \.self) { rt in
                                        Text(rt.displayName)
                                            .font(.forma(.body))
                                            .tag(rt)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(primaryColor)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Status Toggle
                        if !isNew {
                            Toggle(isOn: $isCompleted) {
                                HStack(spacing: 8) {
                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(isCompleted ? .green : primaryColor)
                                    Text("Completed")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .tint(primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Sync Options
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $syncToApple) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(primaryColor)
                                    Text("Sync to Apple Calendar")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .tint(primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            Toggle(isOn: $syncToGoogle) {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(primaryColor)
                                    Text("Sync to Google Calendar")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .tint(primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Delete Button (for existing events)
                    if !isNew {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.forma(.subheadline))
                                Text("Delete Reminder")
                                    .font(.forma(.subheadline, weight: .medium))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(primaryColor)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Reminder", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteEvent(event)
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func saveEvent() {
        let updatedEvent = Event(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            categoryId: categoryId,
            reminderTime: reminderTime,
            isCompleted: isCompleted,
            externalIdentifier: event.externalIdentifier,
            sourceName: event.sourceName,
            syncToAppleCalendar: syncToApple,
            syncToGoogleCalendar: syncToGoogle
        )
        
        // Preserve the original event ID if not new
        if !isNew {
            var eventToSave = updatedEvent
            eventToSave.id = event.id
            eventToSave.appleCalendarIdentifier = event.appleCalendarIdentifier
            eventToSave.googleCalendarIdentifier = event.googleCalendarIdentifier
            viewModel.updateEvent(eventToSave)
        } else {
            viewModel.addEvent(updatedEvent)
        }
        
        dismiss()
    }
}