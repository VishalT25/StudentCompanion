import SwiftUI

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