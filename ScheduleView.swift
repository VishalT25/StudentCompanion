import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddSchedule = false
    @State private var selectedDay: DayOfWeek = DayOfWeek(rawValue: Calendar.current.component(.weekday, from: Date())) ?? .monday
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Enhanced Day Selector
                daySelector
                
                // Schedule Items
                scheduleContent
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSchedule = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingAddSchedule) {
            ScheduleEditView(schedule: nil)
        }
    }
    
    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Day")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        DayButton(
                            day: day,
                            isSelected: selectedDay == day,
                            themeColor: themeManager.currentTheme.primaryColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDay = day
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var scheduleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Schedule for \(selectedDay.shortName)")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                let scheduleCount = viewModel.scheduleItems
                    .filter { $0.daysOfWeek.contains(selectedDay) }.count
                
                Text("\(scheduleCount) item\(scheduleCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            
            let schedules = viewModel.scheduleItems
                .filter { $0.daysOfWeek.contains(selectedDay) }
                .sorted { $0.startTime < $1.startTime }
            
            if schedules.isEmpty {
                EmptyScheduleView(day: selectedDay.shortName)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(schedules) { item in
                        NavigationLink {
                            ScheduleEditView(schedule: item)
                        } label: {
                            EnhancedScheduleRow(item: item)
                                .environmentObject(themeManager)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct DayButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(day.shortName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? themeColor.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct EnhancedScheduleRow: View {
    let item: ScheduleItem
    @EnvironmentObject var themeManager: ThemeManager
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(spacing: 16) {
            // Time section
            VStack(alignment: .leading, spacing: 4) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.title3.weight(.bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                Text(timeFormatter.string(from: item.endTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)
            
            // Content section
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(item.daysOfWeek).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { day in
                            Text(day.shortName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(themeManager.currentTheme.secondaryColor.opacity(0.2))
                                .foregroundColor(themeManager.currentTheme.secondaryColor)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Color indicator
            RoundedRectangle(cornerRadius: 6)
                .fill(item.color)
                .frame(width: 6, height: 60)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct EmptyScheduleView: View {
    let day: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No classes on \(day)")
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("Tap the + button to add your first class")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
