//
//  ClassLiveActivityExtensionLiveActivity.swift
//  ClassLiveActivityExtension
//
//  Created by Vishal Thamaraimanalan on 2025-06-10.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ClassLiveActivityExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ClassLiveActivityExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassLiveActivityExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ClassLiveActivityExtensionAttributes {
    fileprivate static var preview: ClassLiveActivityExtensionAttributes {
        ClassLiveActivityExtensionAttributes(name: "World")
    }
}

extension ClassLiveActivityExtensionAttributes.ContentState {
    fileprivate static var smiley: ClassLiveActivityExtensionAttributes.ContentState {
        ClassLiveActivityExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClassLiveActivityExtensionAttributes.ContentState {
         ClassLiveActivityExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClassLiveActivityExtensionAttributes.preview) {
   ClassLiveActivityExtensionLiveActivity()
} contentStates: {
    ClassLiveActivityExtensionAttributes.ContentState.smiley
    ClassLiveActivityExtensionAttributes.ContentState.starEyes
}
