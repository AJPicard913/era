import Foundation
import Combine
import CoreData

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var todaysSessions: Int = 0
    @Published var weeklySessions: Int = 0
    @Published var monthlySessions: Int = 0
    @Published var totalMinutes: Int = 0
    @Published var weeklyTrendNormalized: [Double] = []
    @Published var monthlyTrendNormalized: [Double] = []
    @Published var avgIntervalText: String = "—"
    @Published var dominantTimeOfDay: String = "—"
    @Published var dailyGoal: Int = DailyBreathingGoalStore.goal
    @Published var goalProgress: String = "0 / 0"

    private let service: AnalyticsService
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        self.service = AnalyticsService(context: context)
        self.dailyGoal = service.dailyGoal()
        refresh()
    }

    func refresh() {
        do {
            todaysSessions = try service.countSessionsToday()
            weeklySessions = try service.countSessionsThisWeek()
            monthlySessions = try service.countSessionsThisMonth()

            if let avg = try service.averageIntervalBetweenSessions(daysBack: 60) {
                avgIntervalText = format(interval: avg)
            } else {
                avgIntervalText = "—"
            }

            if let bucket = try service.dominantTimeOfDay(daysBack: 30) {
                dominantTimeOfDay = bucket.rawValue
            } else {
                dominantTimeOfDay = "—"
            }

            goalProgress = "\(todaysSessions) / \(dailyGoal)"
            // All-time total minutes
            totalMinutes = computeTotalMinutesAllTime()
            // Weekly & monthly series (oldest → newest), normalized 0...1
            let weekSeries = dailyCounts(lastNDays: 7)
            weeklySessions = weekSeries.reduce(0, +)
            weeklyTrendNormalized = normalize(weekSeries)
            let monthSeries = dailyCounts(lastNDays: 30)
            monthlySessions = monthSeries.reduce(0, +)
            monthlyTrendNormalized = normalize(monthSeries)
        } catch {
            todaysSessions = 0
            weeklySessions = 0
            monthlySessions = 0
            avgIntervalText = "—"
            dominantTimeOfDay = "—"
            goalProgress = "\(todaysSessions) / \(dailyGoal)"
            totalMinutes = 0
            weeklyTrendNormalized = []
            monthlyTrendNormalized = []
        }
    }

    func updateDailyGoal(_ value: Int) {
        let v = max(1, value)
        service.setDailyGoal(v)
        dailyGoal = v
        goalProgress = "\(todaysSessions) / \(dailyGoal)"
    }

    private func format(interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 {
            let remH = hours % 24
            return "\(days)d \(remH)h"
        } else if hours > 0 {
            let remM = minutes % 60
            return "\(hours)h \(remM)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Helpers (Core Data aggregation)
    private func computeTotalMinutesAllTime() -> Int {
        // Prefer a 'duration' field if present; otherwise compute from startedAt/endedAt
        let request = NSFetchRequest<NSManagedObject>(entityName: "BreathingSession")
        request.returnsObjectsAsFaults = false
        do {
            let sessions = try context.fetch(request)
            var totalSeconds: Double = 0
            for s in sessions {
                if let dur = s.value(forKey: "duration") as? Double {
                    totalSeconds += max(0, dur)
                } else if let durInt = s.value(forKey: "duration") as? Int {
                    totalSeconds += max(0, Double(durInt))
                } else {
                    let start = s.value(forKey: "startedAt") as? Date
                    let end = s.value(forKey: "endedAt") as? Date
                    if let st = start, let en = end {
                        totalSeconds += max(0, en.timeIntervalSince(st))
                    }
                }
            }
            return Int((totalSeconds / 60.0).rounded())
        } catch {
            return 0
        }
    }

    private func dailyCounts(lastNDays n: Int) -> [Int] {
        guard n > 0 else { return [] }
        var counts: [Int] = []
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        for i in stride(from: n - 1, through: 0, by: -1) { // oldest → newest
            guard let dayStart = cal.date(byAdding: .day, value: -i, to: todayStart),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: dayStart)) else {
                counts.append(0)
                continue
            }
            counts.append(countSessions(between: dayStart, and: dayEnd))
        }
        return counts
    }

    private func countSessions(between start: Date, and end: Date) -> Int {
        // Count sessions where either startedAt OR endedAt falls within [start, end)
        let req = NSFetchRequest<NSFetchRequestResult>(entityName: "BreathingSession")
        let p1 = NSPredicate(format: "startedAt >= %@ AND startedAt < %@", start as NSDate, end as NSDate)
        let p2 = NSPredicate(format: "endedAt >= %@ AND endedAt < %@", start as NSDate, end as NSDate)
        req.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [p1, p2])
        do {
            return try context.count(for: req)
        } catch {
            return 0
        }
    }

    private func normalize(_ series: [Int]) -> [Double] {
        guard let maxVal = series.max(), maxVal > 0 else { return Array(repeating: 0, count: series.count) }
        return series.map { Double($0) / Double(maxVal) }
    }
}