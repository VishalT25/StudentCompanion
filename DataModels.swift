//
//  DataModels.swift
//  StudentCompanion
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Grade Model
struct Grade: Identifiable, Codable {
    let id = UUID()
    var courseName: String
    var assignmentName: String
    var grade: String  // Could be "95%" or "A+" etc.
    var weight: String?
    var dateAdded: Date
    
    init(courseName: String, assignmentName: String, grade: String, weight: String? = nil) {
        self.courseName = courseName
        self.assignmentName = assignmentName
        self.grade = grade
        self.weight = weight
        self.dateAdded = Date()
    }
}

struct Event: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var title: String
    var categoryId: UUID
    var reminderTime: ReminderTime = .none
    var isCompleted: Bool = false
    var externalIdentifier: String? = nil
    var sourceName: String? = nil
    var syncToAppleCalendar: Bool = false
    var syncToGoogleCalendar: Bool = false
    var appleCalendarIdentifier: String? = nil
    var googleCalendarIdentifier: String? = nil
    
    func category(from categories: [Category]) -> Category {
        categories.first { $0.id == categoryId } ?? Category(name: "Unknown", color: .gray)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, title, categoryId, reminderTime, isCompleted, externalIdentifier, sourceName, syncToAppleCalendar, syncToGoogleCalendar, appleCalendarIdentifier, googleCalendarIdentifier
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        categoryId = try container.decode(UUID.self, forKey: .categoryId)
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        externalIdentifier = try container.decodeIfPresent(String.self, forKey: .externalIdentifier)
        sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName)
        syncToAppleCalendar = try container.decodeIfPresent(Bool.self, forKey: .syncToAppleCalendar) ?? false
        syncToGoogleCalendar = try container.decodeIfPresent(Bool.self, forKey: .syncToGoogleCalendar) ?? false
        appleCalendarIdentifier = try container.decodeIfPresent(String.self, forKey: .appleCalendarIdentifier)
        googleCalendarIdentifier = try container.decodeIfPresent(String.self, forKey: .googleCalendarIdentifier)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(externalIdentifier, forKey: .externalIdentifier)
        try container.encodeIfPresent(sourceName, forKey: .sourceName)
        try container.encode(syncToAppleCalendar, forKey: .syncToAppleCalendar)
        try container.encode(syncToGoogleCalendar, forKey: .syncToGoogleCalendar)
        try container.encodeIfPresent(appleCalendarIdentifier, forKey: .appleCalendarIdentifier)
        try container.encodeIfPresent(googleCalendarIdentifier, forKey: .googleCalendarIdentifier)
    }
    
    init(id: UUID = UUID(), date: Date, title: String, categoryId: UUID, reminderTime: ReminderTime = .none, isCompleted: Bool = false, externalIdentifier: String? = nil, sourceName: String? = nil, syncToAppleCalendar: Bool = false, syncToGoogleCalendar: Bool = false, appleCalendarIdentifier: String? = nil, googleCalendarIdentifier: String? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.categoryId = categoryId
        self.reminderTime = reminderTime
        self.isCompleted = isCompleted
        self.externalIdentifier = externalIdentifier
        self.sourceName = sourceName
        self.syncToAppleCalendar = syncToAppleCalendar
        self.syncToGoogleCalendar = syncToGoogleCalendar
        self.appleCalendarIdentifier = appleCalendarIdentifier
        self.googleCalendarIdentifier = googleCalendarIdentifier
    }
}

struct ScheduleItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var daysOfWeek: Set<DayOfWeek>
    var color: Color
    var skippedInstanceIdentifiers: Set<String> = []
    var reminderTime: ReminderTime = .none
    var isLiveActivityEnabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, daysOfWeek, color, skippedInstanceIdentifiers, reminderTime, isLiveActivityEnabled
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(Array(daysOfWeek), forKey: .daysOfWeek)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(Array(skippedInstanceIdentifiers), forKey: .skippedInstanceIdentifiers)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        daysOfWeek = Set(try container.decode([DayOfWeek].self, forKey: .daysOfWeek))
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
             color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color(UIColor(red: components[0], green: components[0], blue: components[0], alpha: components.count > 1 ? components[1] : 1.0))
        }
        skippedInstanceIdentifiers = Set(try container.decodeIfPresent([String].self, forKey: .skippedInstanceIdentifiers) ?? [])
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
    }
    
    init(title: String, startTime: Date, endTime: Date, daysOfWeek: Set<DayOfWeek>, color: Color = .blue, reminderTime: ReminderTime = .none, isLiveActivityEnabled: Bool = true) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.color = color
        self.skippedInstanceIdentifiers = []
        self.reminderTime = reminderTime
        self.isLiveActivityEnabled = isLiveActivityEnabled
    }
    
    static func instanceIdentifier(for itemID: UUID, onDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(itemID.uuidString)_\(dateFormatter.string(from: onDate))"
    }

    func isSkipped(onDate: Date) -> Bool {
        let identifier = ScheduleItem.instanceIdentifier(for: self.id, onDate: onDate)
        return skippedInstanceIdentifiers.contains(identifier)
    }
}
