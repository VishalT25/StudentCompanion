import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State private var showingAddSchedule = false
    @State private var selectedSchedule: ScheduleItem?
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Schedule")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    showingAddSchedule = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            
            let schedule = viewModel.todaysSchedule()
            let events = viewModel.todaysEvents()
            
            if schedule.isEmpty && events.isEmpty {
                Text("Nothing scheduled for today")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !schedule.isEmpty {
                        ForEach(schedule) { item in
                            Button {
                                selectedSchedule = item
                                showingAddSchedule = true
                            } label: {
                                CompactScheduleItemView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if !events.isEmpty {
                        if !schedule.isEmpty {
                            Divider()
                                .background(.white.opacity(0.3))
                                .padding(.vertical, 2)
                        }
                        
                        Text("Today's Events")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        ForEach(events) { event in
                            CompactEventItemView(event: event)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primaryGreen.gradient.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingAddSchedule) {
            if let schedule = selectedSchedule {
                ScheduleEditView(schedule: schedule)
            } else {
                ScheduleEditView()
            }
        }
    }
}

struct CompactScheduleItemView: View {
    let item: ScheduleItem
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(timeFormatter.string(from: item.startTime))
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
            
            Text(item.title)
                .font(.callout)
                .foregroundColor(.white)
            
            Spacer()
            
            ForEach(Array(item.daysOfWeek).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { day in
                Text(day.shortName)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.15))
                    .cornerRadius(4)
            }
            
            RoundedRectangle(cornerRadius: 2)
                .fill(item.color)
                .frame(width: 3, height: 20)
        }
        .padding(.vertical, 4)
    }
}

struct CompactEventItemView: View {
    let event: Event
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(timeFormatter.string(from: event.date))
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
            
            Text(event.title)
                .font(.callout)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
