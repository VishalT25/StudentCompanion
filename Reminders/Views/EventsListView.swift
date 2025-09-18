import SwiftUI

struct EventsListView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var bulkSelectionManager = BulkSelectionManager()
    @State private var showingAddEvent = false
    @State private var showingAddCategory = false
    @State private var selectedDate = Date()
    @State private var showCalendarView = false
    @State private var pendingEventDeletion: Event?
    @State private var showDeleteEventAlert = false
    @State private var showBulkDeleteAlert = false
    @State private var editingEvent: Event?
    @State private var editingCategory: Category?
    
    @State private var showAllUpcoming = false
    @State private var showAllPast = false
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @Environment(\.colorScheme) var colorScheme
    
    var sortedUpcomingEvents: [Event] {
        viewModel.upcomingEvents()
    }
    
    var sortedPastEvents: [Event] {
        viewModel.pastEvents()
    }
    
    var upcomingVisible: [Event] {
        showAllUpcoming ? sortedUpcomingEvents : Array(sortedUpcomingEvents.prefix(5))
    }
    
    var pastVisible: [Event] {
        showAllPast ? sortedPastEvents : Array(sortedPastEvents.prefix(5))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if showCalendarView {
                calendarView
            } else {
                if sortedUpcomingEvents.isEmpty && sortedPastEvents.isEmpty {
                    ScrollView {
                        spectacularEmptyState
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                    }
                } else {
                    listView
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !bulkSelectionManager.isSelecting {
                magicalFloatingButton
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if bulkSelectionManager.isSelecting && bulkSelectionManager.selectionContext == .events {
                    Button(selectionAllButtonTitle()) {
                        toggleSelectAll()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)

                    Button(role: .destructive) {
                        showBulkDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(bulkSelectionManager.selectedCount() == 0)
                    .foregroundColor(bulkSelectionManager.selectedCount() == 0 ? .secondary : .red)
                }
            }
            ToolbarItemGroup(placement: .navigationBarLeading) {
                if bulkSelectionManager.isSelecting && bulkSelectionManager.selectionContext == .events {
                    Button("Cancel") {
                        bulkSelectionManager.endSelection()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .alert("Delete Selected Reminders?", isPresented: $showBulkDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.bulkDeleteEvents(bulkSelectionManager.selectedEventIDs)
                bulkSelectionManager.endSelection()
            }
        } message: {
            Text("This will permanently delete \(bulkSelectionManager.selectedCount()) reminder(s).")
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(isPresented: $showingAddEvent)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(isPresented: $showingAddCategory)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(item: $editingEvent) { event in
            EventEditView(event: event, isNew: false)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(item: $editingCategory) { category in
            AddCategoryView(isPresented: .constant(true), existingCategory: category)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }

        .alert("Delete Reminder", isPresented: $showDeleteEventAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let event = pendingEventDeletion {
                    viewModel.deleteEvent(event)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.15
        }
        
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }

    var headerView: some View {
        VStack(spacing: 20) {
            // Title and View Switcher Row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Reminders")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
                
                viewTypeSelector
            }
            .padding(.horizontal, 20)
            
            // Categories Filter Section
            if !bulkSelectionManager.isSelecting {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Categories Button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedCategoryFilter = nil
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.forma(.subheadline, weight: .medium))
                                Text("All")
                                    .font(.forma(.subheadline, weight: .medium))
                            }
                            .foregroundColor(viewModel.selectedCategoryFilter == nil ? .white : themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedCategoryFilter == nil ? 
                                          themeManager.currentTheme.primaryColor : 
                                          Color(.systemGray6))
                                    .overlay(
                                        Capsule()
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                            .opacity(viewModel.selectedCategoryFilter == nil ? 0 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Category Filter Buttons
                        ForEach(viewModel.categories) { category in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.selectedCategoryFilter = viewModel.selectedCategoryFilter == category.id ? nil : category.id
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(category.color)
                                        .frame(width: 12, height: 12)
                                    Text(category.name)
                                        .font(.forma(.subheadline, weight: .medium))
                                }
                                .foregroundColor(viewModel.selectedCategoryFilter == category.id ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedCategoryFilter == category.id ? 
                                              category.color : 
                                              Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(category.color.opacity(0.4), lineWidth: 1)
                                                .opacity(viewModel.selectedCategoryFilter == category.id ? 0 : 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.6)
                                    .onEnded { _ in
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        editingCategory = category
                                    }
                            )
                        }
                        
                        // Add Category Button
                        Button {
                            showingAddCategory = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.forma(.caption, weight: .bold))
                                Text("Category")
                                    .font(.forma(.caption, weight: .semibold))
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        Capsule()
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .scrollClipDisabled(false) // ensure content doesn't bleed out of bounds
                .clipped() // hard-clip to the padded scroll bounds
            } else {
                HStack {
                    Text("\(bulkSelectionManager.selectedCount()) selected")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.selectedCount())
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(Color.clear) 
    }
    
    private var viewTypeSelector: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCalendarView = false
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.forma(.callout, weight: .medium))
                    .foregroundColor(!showCalendarView ? .white : themeManager.currentTheme.primaryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(!showCalendarView ? themeManager.currentTheme.primaryColor : .clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                            .opacity(!showCalendarView ? 0 : 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCalendarView = true
                }
            }) {
                Image(systemName: "calendar")
                    .font(.forma(.callout, weight: .medium))
                    .foregroundColor(showCalendarView ? .white : themeManager.currentTheme.primaryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(showCalendarView ? themeManager.currentTheme.primaryColor : .clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                            .opacity(showCalendarView ? 0 : 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    var calendarView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Enhanced Calendar Container
                VStack(spacing: 0) {
                    CalendarMonthView(selectedDate: $selectedDate)
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .padding(20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.primaryColor.opacity(0.2),
                                            themeManager.currentTheme.secondaryColor.opacity(0.15),
                                            themeManager.currentTheme.primaryColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.08),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
                .padding(.horizontal, 20)
                .background(
                    // Custom dark mode hue effect without outline
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.15 : 0),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .opacity(colorScheme == .dark ? 1 : 0)
                )

                // Events for Selected Date
                let dayEvents = viewModel.events(for: selectedDate)
                if dayEvents.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.forma(.largeTitle, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 8) {
                            Text("No reminders")
                                .font(.forma(.title3, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("on \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Add Reminder") {
                            showingAddEvent = true
                        }
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                                .overlay(
                                    Capsule()
                                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.primaryColor.opacity(0.2),
                                                themeManager.currentTheme.secondaryColor.opacity(0.15),
                                                themeManager.currentTheme.primaryColor.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, 20)
                    .background(
                        // Custom dark mode hue effect without outline for empty state
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.15 : 0),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .opacity(colorScheme == .dark ? 1 : 0)
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(dayEvents) { event in
                            Button {
                                editingEvent = event
                            } label: {
                                EnhancedEventRow(event: event, isPast: event.date < Date())
                                    .environmentObject(viewModel)
                                    .environmentObject(themeManager)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    var spectacularEmptyState: some View {
        VStack(spacing: 32) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 3.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                Image(systemName: "bell.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseAnimation * 0.95 + 0.05)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to Your Reminders")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Create your first reminder to stay organized and never miss important tasks or deadlines.")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            VStack(spacing: 16) {
                Button("Create Your First Reminder") {
                    showingAddEvent = true
                }
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        Capsule()
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
                        
                        Capsule()
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
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.2),
                        radius: 8, x: 0, y: 4
                    )
                )
                .buttonStyle(EventsBounceButtonStyle())
                
                Button {
                    showingAddCategory = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tag")
                            .font(.forma(.subheadline, weight: .semibold))
                        Text("Add Category")
                            .font(.forma(.subheadline, weight: .semibold))
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.primaryColor.opacity(0.5),
                                                themeManager.currentTheme.secondaryColor.opacity(0.3)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                }
                .buttonStyle(EventsBounceButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.1),
                    radius: 24, x: 0, y: 12
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity : 0,
            cornerRadius: 32
        )
    }
    
    var listView: some View {
        List {
            if !sortedUpcomingEvents.isEmpty {
                Section {
                    ForEach(upcomingVisible) { event in
                        if bulkSelectionManager.selectionContext == .events {
                            HStack {
                                EnhancedEventRow(event: event)
                                Spacer()
                                Image(systemName: bulkSelectionManager.isSelected(event.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.forma(.title3, weight: .semibold))
                                    .foregroundColor(bulkSelectionManager.isSelected(event.id) ? themeManager.currentTheme.primaryColor : .secondary)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: bulkSelectionManager.isSelected(event.id))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                bulkSelectionManager.toggleSelection(event.id)
                            }
                        } else {
                            Button {
                                editingEvent = event
                            } label: {
                                EnhancedEventRow(event: event)
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.6)
                                            .onEnded { _ in
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                bulkSelectionManager.startSelection(.events, initialID: event.id)
                                            }
                                    )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingEventDeletion = event
                                    showDeleteEventAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    bulkSelectionManager.startSelection(.events, initialID: event.id)
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                                .tint(themeManager.currentTheme.primaryColor)
                            }
                        }
                    }
                    
                    if sortedUpcomingEvents.count > 5 {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showAllUpcoming.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(showAllUpcoming ? "Show less" : "Show all (\(sortedUpcomingEvents.count))")
                                        .font(.forma(.caption, weight: .semibold))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                    Image(systemName: showAllUpcoming ? "chevron.up" : "chevron.down")
                                        .font(.forma(.caption, weight: .bold))
                                }
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(themeManager.currentTheme.primaryColor.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Upcoming Reminders")
                            .font(.forma(.subheadline, weight: .semibold))
                        Spacer()
                        Text("\(sortedUpcomingEvents.count)")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !sortedPastEvents.isEmpty {
                Section {
                    ForEach(pastVisible) { event in
                        if bulkSelectionManager.selectionContext == .events {
                            HStack {
                                EnhancedEventRow(event: event, isPast: true)
                                Spacer()
                                Image(systemName: bulkSelectionManager.isSelected(event.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.forma(.title3, weight: .semibold))
                                    .foregroundColor(bulkSelectionManager.isSelected(event.id) ? themeManager.currentTheme.primaryColor : .secondary)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: bulkSelectionManager.isSelected(event.id))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                bulkSelectionManager.toggleSelection(event.id)
                            }
                        } else {
                            Button {
                                editingEvent = event
                            } label: {
                                EnhancedEventRow(event: event, isPast: true)
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.6)
                                            .onEnded { _ in
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                bulkSelectionManager.startSelection(.events, initialID: event.id)
                                            }
                                    )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingEventDeletion = event
                                    showDeleteEventAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    bulkSelectionManager.startSelection(.events, initialID: event.id)
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                                .tint(themeManager.currentTheme.primaryColor)
                            }
                        }
                    }
                    
                    if sortedPastEvents.count > 5 {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showAllPast.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(showAllPast ? "Show less" : "Show all (\(sortedPastEvents.count))")
                                        .font(.forma(.caption, weight: .semibold))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                    Image(systemName: showAllPast ? "chevron.up" : "chevron.down")
                                        .font(.forma(.caption, weight: .bold))
                                }
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(themeManager.currentTheme.primaryColor.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Past Reminders")
                            .font(.forma(.subheadline, weight: .semibold))
                        Spacer()
                        Text("\(sortedPastEvents.count)")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden) 
        .refreshable {
            await viewModel.refreshLiveData()
        }
        .alert("Delete Reminder", isPresented: $showDeleteEventAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let event = pendingEventDeletion {
                    viewModel.deleteEvent(event)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    var magicalFloatingButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.primaryColor,
                                                themeManager.currentTheme.primaryColor.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                themeManager.currentTheme.darkModeAccentHue.opacity(0.6),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 40
                                        )
                                    )
                                    .scaleEffect(pulseAnimation * 0.3 + 0.7)
                                    .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.3)
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.4),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                            .compositingGroup()
                            .shadow(
                                color: themeManager.currentTheme.primaryColor.opacity(0.4),
                                radius: 20, x: 0, y: 10
                            )
                            .shadow(
                                color: themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.2),
                                radius: 12, x: 0, y: 6
                            )
                        )
                }
                .buttonStyle(EventsBounceButtonStyle())
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }

    private var allEventsForSelection: [Event] {
        viewModel.upcomingEvents() + viewModel.pastEvents()
    }

    private func selectionAllButtonTitle() -> String {
        let total = allEventsForSelection.count
        let selected = bulkSelectionManager.selectedCount()
        return selected == total && total > 0 ? "Deselect All" : "Select All"
    }
    
    private func toggleSelectAll() {
        let total = allEventsForSelection.count
        let selected = bulkSelectionManager.selectedCount()
        
        if selected == total && total > 0 {
            bulkSelectionManager.deselectAll()
        } else {
            bulkSelectionManager.selectAll(items: allEventsForSelection)
        }
    }
}