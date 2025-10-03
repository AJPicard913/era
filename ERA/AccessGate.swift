import Foundation
import SwiftUI

@MainActor
final class AccessGate: ObservableObject {
    // Change this at runtime to test (e.g., set to 0 to force paywall)
    @AppStorage("freeSessionQuota") var freeSessionQuota: Int = 0

    func canStartSession(completedSessions: Int, isPro: Bool) -> Bool {
        if isPro { return true }
        return completedSessions < freeSessionQuota
    }
}
