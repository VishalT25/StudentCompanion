import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State private var showingAddSchedule = false
    @State private var selectedDay: DayOfWeek = DayOfWeek(rawValue: Calendar.current.component(.weekday, from: Date())) ?? .monday
    
    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            VStack {
                                Text(day.shortName)
                                    .font(.caption)
                                    .foregroundColor(selectedDay == day ? .white : .primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedDay == day ? Color.primaryGreen : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture {
                                withAnimation {
                                    selectedDay = day
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                let schedules = viewModel.scheduleItems
                    .filter { $0.daysOfWeek.contains(selectedDay) }
                    .sorted { $0.startTime < $1.startTime }
                
                if schedules.isEmpty {
                    Text("No schedule items for \(selectedDay.shortName)")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(schedules) { item in
                        NavigationLink {
                            ScheduleEditView(schedule: item)
                        } label: {
                            ScheduleRow(item: item)
                        }
                    }
                    .onDelete { indices in
                        indices.forEach { index in
                            viewModel.deleteScheduleItem(schedules[index])
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Schedule")
                    Spacer()
                    Button {
                        showingAddSchedule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.primaryGreen)
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .sheet(isPresented: $showingAddSchedule) {
            ScheduleEditView(schedule: nil)
        }
    }
}

struct ScheduleRow: View {
    let item: ScheduleItem
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.headline)
                Text(timeFormatter.string(from: item.endTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    ForEach(Array(item.daysOfWeek).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { day in
                        Text(day.shortName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondaryGreen.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 3)
                .fill(item.color)
                .frame(width: 4, height: 40)
        }
        .padding(.vertical, 4)
    }
}