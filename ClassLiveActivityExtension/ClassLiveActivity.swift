import ActivityKit
import WidgetKit
import SwiftUI

struct ClassLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            // Lock screen/banner UI - ENHANCED (from previous iteration, ensuring it's applied)
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .font(.title3.weight(.medium))
                        .foregroundColor(context.state.eventColor())
                    Text(context.state.eventName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(context.state.themePrimaryColor())
                        .lineLimit(1)
                    Spacer()
                    Text("Ends in \(Text(context.state.endTime, style: .timer))")
                         .font(.subheadline.weight(.medium))
                         .foregroundColor(context.state.themePrimaryColor().opacity(0.9))
                         .monospacedDigit()
                }

                let totalDuration = context.state.endTime.timeIntervalSince(context.attributes.creationDate)
                let elapsedTime = Date().timeIntervalSince(context.attributes.creationDate)
                let progress = max(0, min(1, elapsedTime / totalDuration))
                
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(context.state.eventColor())
                    .frame(height: 5)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    .padding(.top, 2)
            }
            .padding(12)
            .activityBackgroundTint(context.state.themePrimaryColor().opacity(0.15))
            .activitySystemActionForegroundColor(context.state.themePrimaryColor())

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "graduationcap.fill")
                        .font(.title3)
                        .foregroundColor(context.state.themePrimaryColor())
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(context.state.endTime, style: .timer)
                            .monospacedDigit()
                            .font(.title3.weight(.semibold))
                            .foregroundColor(context.state.themePrimaryColor())
                    } icon: {
                        Image(systemName: "clock.fill")
                            .foregroundColor(context.state.themePrimaryColor())
                    }
                    .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.eventName)
                        .lineLimit(1)
                        .font(.headline.weight(.medium))
                        .foregroundColor(context.state.themePrimaryColor())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EVENT ONGOING")
                             .font(.caption.weight(.bold))
                             .foregroundColor(context.state.themePrimaryColor().opacity(0.7))
                             .padding(.leading, 4)

                        let totalDuration = context.state.endTime.timeIntervalSince(context.attributes.creationDate)
                        let elapsedTime = Date().timeIntervalSince(context.attributes.creationDate)
                        let progress = max(0, min(1, elapsedTime / totalDuration))
                        
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(context.state.eventColor()) 
                            .frame(height: 5)
                            .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 5)
                }
            } compactLeading: {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.callout)
                        .imageScale(.small)
                        .foregroundColor(context.state.eventColor())
                        .background(Circle().fill(context.state.themePrimaryColor().opacity(0.2)))
                        .padding(.leading, 8)
                    
                    let totalDuration = context.state.endTime.timeIntervalSince(context.attributes.creationDate)
                    let elapsedTime = Date().timeIntervalSince(context.attributes.creationDate)
                    let progress = max(0, min(1, elapsedTime / totalDuration))
                    
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(context.state.eventColor())
                        .frame(width: 20, height: 2)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
            } compactTrailing: {
                Text(context.state.endTime, style: .timer)
                    .monospacedDigit()
                    .font(.caption2.weight(.medium))
                    .foregroundColor(context.state.themePrimaryColor())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 0)
                    .padding(.vertical, 0)
            } minimal: {
                Image(systemName: "graduationcap.fill") // Or "calendar.badge.clock"
                    .foregroundColor(context.state.eventColor())
                    .padding(5)
                    .background(Circle().fill(context.state.themePrimaryColor().opacity(0.2)))
            }
            .widgetURL(URL(string: "studentcompanion://openevent/\(context.state.eventName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            .keylineTint(context.state.eventColor())
        }
    }
}
