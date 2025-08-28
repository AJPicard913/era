import Foundation
import CoreData

enum DaytimeBucket: String {
    case morning = "Morning"
    case lunch = "Lunch"
    case dinner = "Dinner"
}

struct DailyBreathingGoalStore {
    private static let key = "dailyBreathingGoal"
    private static let defaultGoal = 3

    static var goal: Int {
        get {
            let g = UserDefaults.standard.integer(forKey: key)
            return g == 0 ? defaultGoal : g
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

struct AnalyticsService {
    let context: NSManagedObjectContext
    private let calendar: Calendar = .current

    func sessions(on date: Date) throws -> [BreathingSession] {
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return [] }
        return try fetchSessions(in: interval)
    }

    func countSessionsToday() throws -> Int {
        try sessions(on: Date()).count
    }

    func countSessionsThisWeek(reference date: Date = Date()) throws -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return try fetchCount(in: interval)
    }

    func countSessionsThisMonth(reference date: Date = Date()) throws -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        return try fetchCount(in: interval)
    }

    func averageIntervalBetweenSessions(daysBack: Int? = nil) throws -> TimeInterval? {
        let sessions = try fetchSessionsSorted(daysBack: daysBack)
        guard sessions.count >= 2 else { return nil }
        var intervals: [TimeInterval] = []
        for i in 1..<sessions.count {
            let prev = sessions[i - 1].startedAt ?? sessions[i - 1].endedAt ?? Date()
            let curr = sessions[i].startedAt ?? sessions[i].endedAt ?? Date()
            let delta = curr.timeIntervalSince(prev)
            if delta > 0 { intervals.append(delta) }
        }
        guard !intervals.isEmpty else { return nil }
        let sum = intervals.reduce(0, +)
        return sum / Double(intervals.count)
    }

    func dominantTimeOfDay(daysBack: Int? = 30) throws -> DaytimeBucket? {
        let sessions = try fetchSessionsSorted(daysBack: daysBack)
        guard !sessions.isEmpty else {
            let all = try fetchSessionsSorted(daysBack: nil)
            guard !all.isEmpty else { return nil }
            return dominantBucket(for: all)
        }
        return dominantBucket(for: sessions)
    }

    func dailyGoal() -> Int {
        DailyBreathingGoalStore.goal
    }

    func setDailyGoal(_ value: Int) {
        DailyBreathingGoalStore.goal = max(1, value)
    }

    private func dominantBucket(for sessions: [BreathingSession]) -> DaytimeBucket? {
        var counts: [DaytimeBucket: Int] = [.morning: 0, .lunch: 0, .dinner: 0]
        for s in sessions {
            let t = s.startedAt ?? s.endedAt ?? Date()
            let hour = calendar.component(.hour, from: t)
            let bucket = categorizeHour(hour)
            counts[bucket, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func categorizeHour(_ hour: Int) -> DaytimeBucket {
        switch hour {
        case 5...10: return .morning
        case 11...15: return .lunch
        case 16...21: return .dinner
        default: return .dinner
        }
    }

    private func fetchCount(in interval: DateInterval) throws -> Int {
        let req: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "BreathingSession")
        req.predicate = NSPredicate(format: "startedAt >= %@ AND startedAt < %@", interval.start as NSDate, interval.end as NSDate)
        req.resultType = .countResultType
        return try context.count(for: req as! NSFetchRequest<BreathingSession>)
    }

    private func fetchSessions(in interval: DateInterval) throws -> [BreathingSession] {
        let req: NSFetchRequest<BreathingSession> = BreathingSession.fetchRequest()
        req.predicate = NSPredicate(format: "startedAt >= %@ AND startedAt < %@", interval.start as NSDate, interval.end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
        return try context.fetch(req)
    }

    private func fetchSessionsSorted(daysBack: Int?) throws -> [BreathingSession] {
        let req: NSFetchRequest<BreathingSession> = BreathingSession.fetchRequest()
        if let days = daysBack, let start = calendar.date(byAdding: .day, value: -days, to: Date()) {
            req.predicate = NSPredicate(format: "startedAt >= %@", start as NSDate)
        }
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
        return try context.fetch(req)
    }
}