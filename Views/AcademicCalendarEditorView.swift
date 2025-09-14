import SwiftUI

struct AcademicCalendarEditorView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var academicCalendar: AcademicCalendar?
    @State private var showingAddBreak = false
    @State private var breakToEdit: AcademicBreak?
    @State private var showingDeleteAlert = false
    @State private var breakToDelete: AcademicBreak?
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    private var sortedBreaks: [AcademicBreak] {
        academicCalendar?.breaks.sorted { $0.startDate < $1.startDate } ?? []
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                if sortedBreaks.isEmpty {
                    emptyStateView
                } else {
                    breaksListView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                startAnimations()
            }
        }
        .sheet(isPresented: $showingAddBreak) {
            AddEditAcademicBreakView(
                calendar: $academicCalendar,
                breakToEdit: .constant(nil)
            )
            .environmentObject(themeManager)
            .environmentObject(academicCalendarManager)
        }
        .sheet(item: $breakToEdit) { academicBreak in
            AddEditAcademicBreakView(
                calendar: $academicCalendar,
                breakToEdit: .constant(academicBreak)
            )
            .environmentObject(themeManager)
            .environmentObject(academicCalendarManager)
        }
        .alert("Delete Break", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                breakToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteBreak()
            }
        } message: {
            if let break_ = breakToDelete {
                Text("Are you sure you want to delete '\(break_.name)'? This cannot be undone.")
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
        
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button("Done") {
                    dismiss()
                }
                .font(.forma(.callout, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Breaks & Holidays")
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let calendar = academicCalendar {
                        Text(calendar.name)
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    showingAddBreak = true
                } label: {
                    Image(systemName: "plus")
                        .font(.forma(.callout, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.systemGroupedBackground).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0,
            cornerRadius: 0
        )
    }
    
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer()
                    .frame(height: 80)
                
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.025),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 70 + CGFloat(index * 25)
                                )
                            )
                            .frame(width: 140 + CGFloat(index * 50), height: 140 + CGFloat(index * 50))
                            .scaleEffect(pulseAnimation + Double(index) * 0.06)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .overlay(
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.5),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.6)
                                        )
                                    )
                            )
                            .shadow(
                                color: themeManager.currentTheme.primaryColor.opacity(0.4),
                                radius: 20, x: 0, y: 10
                            )
                        
                        Image(systemName: "calendar.badge.minus")
                            .font(.forma(.title, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(spacing: 16) {
                    Text("No Breaks Added")
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Add breaks and holidays to help manage your schedule more effectively throughout the academic year.")
                        .font(.forma(.body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 32)
                }
                
                Button(action: { showingAddBreak = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.title3, weight: .bold))
                        
                        Text("Add First Break")
                            .font(.forma(.headline, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.primaryColor,
                                            themeManager.currentTheme.secondaryColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 16, x: 0, y: 8
                        )
                    )
                }
                .buttonStyle(EventsBounceButtonStyle())
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 20, x: 0, y: 10
                )
        )
        .padding(.horizontal, 24)
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.4 : 0,
            cornerRadius: 32
        )
    }
    
    private var breaksListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sortedBreaks, id: \.id) { academicBreak in
                    BreakCard(
                        academicBreak: academicBreak,
                        onEdit: {
                            breakToEdit = academicBreak
                        },
                        onDelete: {
                            breakToDelete = academicBreak
                            showingDeleteAlert = true
                        }
                    )
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    private func deleteBreak() {
        guard let breakToDelete = breakToDelete else { return }
        academicCalendar?.breaks.removeAll { $0.id == breakToDelete.id }
        if let updated = academicCalendar {
            academicCalendarManager.updateCalendar(updated)
        }
        self.breakToDelete = nil
    }
}

struct BreakCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    let academicBreak: AcademicBreak
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var durationText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if Calendar.current.isDate(academicBreak.startDate, inSameDayAs: academicBreak.endDate) {
            return formatter.string(from: academicBreak.startDate)
        } else {
            return "\(formatter.string(from: academicBreak.startDate)) - \(formatter.string(from: academicBreak.endDate))"
        }
    }
    
    private var daysCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: academicBreak.startDate)
        let end = calendar.startOfDay(for: academicBreak.endDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0 + 1
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: academicBreak.type.icon)
                        .font(.forma(.title3, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(academicBreak.name)
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(academicBreak.type.displayName)
                        .font(.forma(.caption2, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.15))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .clipShape(Capsule())
                }
                
                Text(durationText)
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                
                if daysCount > 1 {
                    Text("\(daysCount) days")
                        .font(.forma(.caption2))
                        .foregroundColor(.secondary)
                }
                
                if !academicBreak.description.isEmpty {
                    Text(academicBreak.description)
                        .font(.forma(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.red.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.05),
                    radius: 8, x: 0, y: 4
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0,
            cornerRadius: 16
        )
    }
}

struct AddEditAcademicBreakView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var calendar: AcademicCalendar?
    @Binding var breakToEdit: AcademicBreak?
    
    @State private var name: String = ""
    @State private var type: BreakType = .custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var description: String = ""
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    private var isEditing: Bool {
        breakToEdit != nil
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 32) {
                        basicDetailsSection
                        datesSection
                        actionButtonsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                setup()
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.12
        }
        
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.forma(.callout, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                
                Spacer()
                
                Text(isEditing ? "Edit Break" : "New Break")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Add") {
                    saveBreak()
                }
                .font(.forma(.callout, weight: .bold))
                .foregroundColor(isValid ? themeManager.currentTheme.primaryColor : .secondary)
                .disabled(!isValid)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            
            // Hero Section
            VStack(spacing: 24) {
                ZStack {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.12 - Double(index) * 0.04),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60 + CGFloat(index * 20)
                                )
                            )
                            .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                            .scaleEffect(pulseAnimation + Double(index) * 0.05)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.5),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.6)
                                        )
                                    )
                            )
                            .shadow(
                                color: themeManager.currentTheme.primaryColor.opacity(0.4),
                                radius: 16, x: 0, y: 8
                            )
                        
                        Image(systemName: type.icon)
                            .font(.forma(.title2, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(spacing: 8) {
                    Text(isEditing ? "Update Break" : "Add New Break")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Configure academic breaks and holidays")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.systemGroupedBackground).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0,
            cornerRadius: 0
        )
    }
    
    private var basicDetailsSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Break Name")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                TextField("e.g., Spring Break", text: $name)
                    .font(.forma(.body))
                    .textFieldStyle(EnhancedTextFieldStyle(themeManager: themeManager))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tag")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Type")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Picker("Type", selection: $type) {
                    ForEach(BreakType.allCases, id: \.self) { breakType in
                        HStack {
                            Image(systemName: breakType.icon)
                            Text(breakType.displayName)
                        }
                        .tag(breakType)
                    }
                }
                .pickerStyle(.menu)
                .font(.forma(.body))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "note.text")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Description")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("(Optional)")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                TextField("Add notes about this break", text: $description, axis: .vertical)
                    .font(.forma(.body))
                    .textFieldStyle(EnhancedTextFieldStyle(themeManager: themeManager))
                    .lineLimit(2...4)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 16, x: 0, y: 8
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.4 : 0,
            cornerRadius: 20
        )
    }
    
    private var datesSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("Start Date")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.forma(.body))
                    .labelsHidden()
                    .onChange(of: startDate) { _, newValue in
                        if endDate < newValue {
                            endDate = newValue
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 20)
                    
                    Text("End Date")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.forma(.body))
                    .labelsHidden()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.2),
                                    themeManager.currentTheme.secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 16, x: 0, y: 8
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.4 : 0,
            cornerRadius: 20
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: saveBreak) {
                HStack(spacing: 12) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.forma(.title3, weight: .bold))
                    
                    Text(isEditing ? "Save Changes" : "Add Break")
                        .font(.forma(.headline, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        isValid ? themeManager.currentTheme.primaryColor : .gray,
                                        isValid ? themeManager.currentTheme.secondaryColor.opacity(0.8) : .gray
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: isValid ? themeManager.currentTheme.primaryColor.opacity(0.4) : .gray.opacity(0.2),
                        radius: 16, x: 0, y: 8
                    )
                )
            }
            .disabled(!isValid)
            .buttonStyle(EventsBounceButtonStyle())
            
            Button("Cancel") {
                dismiss()
            }
            .font(.forma(.callout, weight: .semibold))
            .foregroundColor(.secondary)
        }
    }
    
    private func setup() {
        guard let breakToEdit = breakToEdit else { return }
        name = breakToEdit.name
        type = breakToEdit.type
        startDate = breakToEdit.startDate
        endDate = breakToEdit.endDate
        description = breakToEdit.description
    }
    
    private func saveBreak() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let breakToEdit = breakToEdit, let index = calendar?.breaks.firstIndex(where: { $0.id == breakToEdit.id }) {
            // Update existing break
            calendar?.breaks[index].name = trimmedName
            calendar?.breaks[index].type = type
            calendar?.breaks[index].startDate = startDate
            calendar?.breaks[index].endDate = endDate
            calendar?.breaks[index].description = description
        } else {
            // Add new break
            var newBreak = AcademicBreak(
                name: trimmedName,
                type: type,
                startDate: startDate,
                endDate: endDate
            )
            newBreak.description = description
            calendar?.breaks.append(newBreak)
        }
        
        if let updatedCalendar = calendar {
            academicCalendarManager.updateCalendar(updatedCalendar)
        }
        
        dismiss()
    }
}