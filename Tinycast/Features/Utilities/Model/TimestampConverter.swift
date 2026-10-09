import Foundation

enum TimestampConverter {
    enum Unit: String, CaseIterable, Sendable { case automatic, seconds, milliseconds }
    enum Failure: Error { case invalidTimestamp, invalidDate, outOfRange, ambiguousDate }
    struct Result: Sendable {
        let seconds: String
        let milliseconds: String
        let localDate: String
        let utcDate: String
    }

    static func fromTimestamp(_ input: String, unit: Unit, timeZone: TimeZone) throws -> Result {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[+-]?[0-9]+(?:\.[0-9]{1,3})?$"#, options: .regularExpression) != nil,
            let number = Double(value), number.isFinite
        else { throw Failure.invalidTimestamp }
        let isMilliseconds = unit == .milliseconds || (unit == .automatic && abs(number) >= 100_000_000_000)
        guard !isMilliseconds || !value.contains(".") else { throw Failure.invalidTimestamp }
        let seconds = isMilliseconds ? number / 1000 : number
        guard seconds >= -62_135_596_800, seconds < 253_402_300_800 else { throw Failure.outOfRange }
        return try result(for: Date(timeIntervalSince1970: seconds), timeZone: timeZone)
    }

    static func fromDate(_ input: String, timeZone: TimeZone) throws -> Result {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{3})?$"#,
            options: .regularExpression) != nil else { throw Failure.invalidDate }
        let formatter = formatter(timeZone: timeZone, milliseconds: text.contains("."))
        guard let date = formatter.date(from: text), formatter.string(from: date) == text else { throw Failure.invalidDate }
        let calendar = formatter.calendar!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let start = calendar.startOfDay(for: date).addingTimeInterval(-1)
        let first = calendar.nextDate(after: start, matching: components, matchingPolicy: .strict, repeatedTimePolicy: .first)
        let last = calendar.nextDate(after: start, matching: components, matchingPolicy: .strict, repeatedTimePolicy: .last)
        if let first, let last, first != last { throw Failure.ambiguousDate }
        return try result(for: date, timeZone: timeZone)
    }

    static func result(for date: Date, timeZone: TimeZone) throws -> Result {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, seconds >= -62_135_596_800, seconds < 253_402_300_800 else { throw Failure.outOfRange }
        let milliseconds = Int64((seconds * 1000).rounded())
        let whole = abs(milliseconds) / 1000
        var fraction = String(format: "%03lld", abs(milliseconds) % 1000)
        while fraction.last == "0" { fraction.removeLast() }
        let sign = milliseconds < 0 ? "-" : ""
        let value = sign + String(whole) + (fraction.isEmpty ? "" : "." + fraction)
        return Result(
            seconds: value, milliseconds: String(milliseconds),
            localDate: formatter(timeZone: timeZone, milliseconds: true).string(from: date),
            utcDate: formatter(timeZone: TimeZone(secondsFromGMT: 0)!, milliseconds: true).string(from: date) + " UTC")
    }

    private static func formatter(timeZone: TimeZone, milliseconds: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = milliseconds ? "yyyy-MM-dd HH:mm:ss.SSS" : "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        return formatter
    }
}
