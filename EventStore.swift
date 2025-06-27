//
//  EventStore.swift
//  StudentCompanion
//
//  Created by Vishal Thamaraimanalan on 2025-06-27.
//


///  EventStore.swift  (create a new file)
import Foundation

struct EventStore {
    static func setGoogleId(_ id: String, forLocalId localId: UUID,
                            in viewModel: EventViewModel) {
        if let idx = viewModel.events.firstIndex(where: { $0.id == localId }) {
            viewModel.events[idx].googleCalendarIdentifier = id
            viewModel.events[idx].externalIdentifier       = id   // keep them identical
            viewModel.saveData()
        }
    }
}
