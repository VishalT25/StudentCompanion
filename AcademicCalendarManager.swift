import Foundation
import SwiftUI

@MainActor
class AcademicCalendarManager: ObservableObject {
    @Published var academicCalendars: [AcademicCalendar] = []
    
    private let calendarsKey = "savedAcademicCalendars"
    
    init() {
        loadAcademicCalendars()
    }
    
    func loadAcademicCalendars() {
        if let data = UserDefaults.standard.data(forKey: calendarsKey) {
            do {
                let decoder = JSONDecoder()
                academicCalendars = try decoder.decode([AcademicCalendar].self, from: data)
            } catch {
                 ("Error loading academic calendars: \(error)")
                academicCalendars = []
            }
        }
    }
    
    func saveAcademicCalendars() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(academicCalendars)
            UserDefaults.standard.set(data, forKey: calendarsKey)
        } catch {
             ("Error saving academic calendars: \(error)")
        }
    }
    
    func addCalendar(_ calendar: AcademicCalendar) {
        academicCalendars.append(calendar)
        saveAcademicCalendars()
    }
    
    func updateCalendar(_ calendar: AcademicCalendar) {
        guard let index = academicCalendars.firstIndex(where: { $0.id == calendar.id }) else { return }
        academicCalendars[index] = calendar
        saveAcademicCalendars()
    }
    
    func deleteCalendar(_ calendar: AcademicCalendar) {
        academicCalendars.removeAll { $0.id == calendar.id }
        saveAcademicCalendars()
    }
    
    func calendar(withID id: UUID) -> AcademicCalendar? {
        return academicCalendars.first { $0.id == id }
    }
    
    func createDefaultCalendar(for year: String) -> AcademicCalendar {
        let components = year.split(separator: "-")
        let startYear = Int(components.first ?? "2024") ?? 2024
        
        let startDate = Calendar.current.date(from: DateComponents(year: startYear, month: 8, day: 15)) ?? Date()
        let endDate = Calendar.current.date(from: DateComponents(year: startYear + 1, month: 6, day: 15)) ?? Date()
        
        return AcademicCalendar(
            name: "Academic Year \(year)",
            academicYear: year,
            termType: .semester,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    func getUsageCount(for calendar: AcademicCalendar, in scheduleManager: ScheduleManager) -> Int {
        return scheduleManager.scheduleCollections.filter { schedule in
            schedule.academicCalendarID == calendar.id
        }.count
    }
    
    func getSchedulesUsing(_ calendar: AcademicCalendar, from scheduleManager: ScheduleManager) -> [ScheduleCollection] {
        return scheduleManager.scheduleCollections.filter { schedule in
            schedule.academicCalendarID == calendar.id
        }
    }
    
    func canDelete(_ calendar: AcademicCalendar, in scheduleManager: ScheduleManager) -> (canDelete: Bool, reason: String?) {
        let usageCount = getUsageCount(for: calendar, in: scheduleManager)
        if usageCount > 0 {
            return (false, "Calendar is being used by \(usageCount) schedule\(usageCount == 1 ? "" : "s")")
        }
        return (true, nil)
    }
}
