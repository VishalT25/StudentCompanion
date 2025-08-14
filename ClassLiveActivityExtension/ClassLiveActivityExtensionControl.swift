//
//  ClassLiveActivityExtensionControl.swift
//  ClassLiveActivityExtension
//
//  Created by Vishal Thamaraimanalan on 2025-06-10.
//

import WidgetKit
import SwiftUI

struct ClassLiveActivityExtensionControlProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClassLiveActivityExtensionControlEntry {
        ClassLiveActivityExtensionControlEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassLiveActivityExtensionControlEntry) -> Void) {
        let entry = ClassLiveActivityExtensionControlEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassLiveActivityExtensionControlEntry>) -> Void) {
        let entries = [ClassLiveActivityExtensionControlEntry(date: Date())]
        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
}

struct ClassLiveActivityExtensionControlEntry: TimelineEntry {
    let date: Date
}

struct ClassLiveActivityExtensionControlView: View {
    var entry: ClassLiveActivityExtensionControlEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "graduationcap.fill")
                .imageScale(.large)
            Text("StuCo")
                .font(.caption)
        }
        .padding(8)
    }
}

struct ClassLiveActivityExtensionControl: Widget {
    let kind: String = "com.vishal.StuCo.ClassLiveActivityExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClassLiveActivityExtensionControlProvider()) { entry in
            if #available(iOS 17.0, *) {
                ClassLiveActivityExtensionControlView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ClassLiveActivityExtensionControlView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("StuCo Quick Access")
        .description("Quick access widget for StuCo.")
    }
}