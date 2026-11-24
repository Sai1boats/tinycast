import Foundation

enum PomodoroTimeText {
    /// `24:31` — minutes and seconds, for the countdown.
    static func minutesSeconds(_ interval: TimeInterval) -> String {
        let total = Swift.max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// `1:15` — hours and minutes, for accumulated focus time.
    static func hoursMinutes(_ interval: TimeInterval) -> String {
        let total = Swift.max(0, Int(interval))
        return String(format: "%d:%02d", total / 3600, (total % 3600) / 60)
    }
}
