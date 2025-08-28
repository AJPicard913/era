import Foundation
import Combine
import CoreData

final class AnalyticsViewModel: ObservableObject {
    @Published var todaysSessions: Int = 0
    @Published var weeklySessions: Int = 0
    @Published var monthlySessions: Int = 0
    @Published var avgIntervalText: String = "—"
    @Published var dominantTimeOfDay: String = "—"
    @Published var dailyGoal: Int = DailyBreathingGoalStore.goal
    @Published var goalProgress: String = "0 / 0"

    private let service: AnalyticsService

    init(context: NSManagedObjectContext) {
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
        } catch {
            todaysSessions = 0
            weeklySessions = 0
            monthlySessions = 0
            avgIntervalText = "—"
            dominantTimeOfDay = "—"
            goalProgress = "\(todaysSessions) / \(dailyGoal)"
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
}