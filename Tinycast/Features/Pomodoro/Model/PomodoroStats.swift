import Foundation

/// One local day of pomodoro results; the day key rolls it when the date changes.
struct PomodoroStats: Codable, Sendable, Equatable {
    var day: String
    var completedFocusCount: Int
    var focusSeconds: Int

    static let empty = PomodoroStats(day: "", completedFocusCount: 0, focusSeconds: 0)

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// A day change discards the old bucket rather than merging into it.
    func rolled(to day: String) -> PomodoroStats {
        self.day == day ? self : PomodoroStats(day: day, completedFocusCount: 0, focusSeconds: 0)
    }

    func countingFocusCompletion(on day: String) -> PomodoroStats {
        var stats = rolled(to: day)
        stats.completedFocusCount += 1
        return stats
    }

    /// A completed focus counts on the day it completes, even when the session began the day before.
    func recording(_ phase: PomodoroPhase, at completion: Date, calendar: Calendar) -> PomodoroStats {
        let day = Self.dayKey(for: completion, calendar: calendar)
        return phase == .focus ? countingFocusCompletion(on: day) : rolled(to: day)
    }

    func addingFocusSeconds(_ seconds: Int, on day: String) -> PomodoroStats {
        guard seconds > 0 else { return rolled(to: day) }
        var stats = rolled(to: day)
        stats.focusSeconds += seconds
        return stats
    }
}

extension PomodoroStats {
    /// Whole seconds from 500 ms ticks, carrying the fraction so it is not truncated away.
    struct FocusAccumulator: Sendable, Equatable {
        private(set) var pending: TimeInterval = 0

        mutating func record(_ interval: TimeInterval) -> Int {
            pending += Swift.max(0, interval)
            let whole = Int(pending)
            pending -= TimeInterval(whole)
            return whole
        }
    }
}
