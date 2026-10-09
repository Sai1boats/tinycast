import Foundation

@main
struct UtilitiesTests {
    static func main() throws {
        try json()
        try timestamps()
        try currencies()
        print("JSON preservation and validation, timestamp units and DST, and decimal currency conversion passed")
    }

    static func json() throws {
        let source = #" { "id": 123456789012345678901234567890, "n": 1.234567890123456789e+999, "#
            + #""a": [true,null,{}], "s":"你好\n\"世界\"" } "#
        let compact = try JSONTool.process(source, operation: .compact)
        check(compact.contains("123456789012345678901234567890"))
        check(compact.contains("1.234567890123456789e+999"))
        let pretty = try JSONTool.process(compact, operation: .format)
        check(pretty.contains("\n  \"id\": "))
        check(try JSONTool.process(pretty, operation: .compact) == compact)
        check(try JSONTool.process(#"{"a":1,"a":2}"#, operation: .compact) == #"{"a":1,"a":2}"#)
        for value in ["{}", "[]", "null", "true", "-0.25e-2", #""abc""#] {
            check(try JSONTool.process(value, operation: .compact) == value)
        }
        check(try JSONTool.process(#""{\"a\":1}""#, operation: .unescape) == #"{"a":1}"#)
        check(try JSONTool.process(#"{\"a\":1}"#, operation: .unescape) == #"{"a":1}"#)
        check(try JSONTool.process(#""a\nb\\c""#, operation: .unescape) == "a\nb\\c")
        for invalid in ["", "01", "1.", "1e", "+1", "NaN", "[1,]", "{\"a\":}", "{} false", "{a:1}",
                        #""\x20""#, #""\uXYZ0""#, "\"line\nline\""] {
            rejects { _ = try JSONTool.process(invalid, operation: .format) }
        }
        rejects { _ = try JSONTool.process(String(repeating: "[", count: 130), operation: .format) }
        rejects { _ = try JSONTool.process(String(repeating: " ", count: 1_048_577), operation: .compact) }
        let expanded = String(repeating: "[", count: 120) + Array(repeating: "0", count: 18000).joined(separator: ",")
            + String(repeating: "]", count: 120)
        rejects { _ = try JSONTool.process(expanded, operation: .format) }
    }

    static func timestamps() throws {
        let utc = TimeZone(secondsFromGMT: 0)!
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let epoch = try TimestampConverter.fromTimestamp("0", unit: .seconds, timeZone: shanghai)
        check(epoch.localDate == "1970-01-01 08:00:00.000")
        check(epoch.utcDate == "1970-01-01 00:00:00.000 UTC")
        let negative = try TimestampConverter.fromTimestamp("-0.001", unit: .seconds, timeZone: utc)
        check(negative.milliseconds == "-1" && negative.seconds == "-0.001")
        let tiny = try TimestampConverter.fromTimestamp("1", unit: .milliseconds, timeZone: utc)
        check(tiny.seconds == "0.001")
        let seconds = try TimestampConverter.fromTimestamp("1700000000.123", unit: .automatic, timeZone: utc)
        let millis = try TimestampConverter.fromTimestamp("1700000000123", unit: .automatic, timeZone: utc)
        check(seconds.milliseconds == millis.milliseconds)
        let back = try TimestampConverter.fromDate(seconds.localDate, timeZone: utc)
        check(back.milliseconds == seconds.milliseconds)
        _ = try TimestampConverter.fromDate("2024-02-29 12:30:45", timeZone: utc)
        for date in ["2023-02-29 00:00:00", "2024-04-31 00:00:00", "2024-01-01 25:00:00", "2024-1-1 01:00:00"] {
            rejects { _ = try TimestampConverter.fromDate(date, timeZone: utc) }
        }
        let newYork = TimeZone(identifier: "America/New_York")!
        rejects { _ = try TimestampConverter.fromDate("2026-03-08 02:30:00", timeZone: newYork) }
        rejects { _ = try TimestampConverter.fromDate("2026-11-01 01:30:00", timeZone: newYork) }
        for number in ["nan", "inf", "1e100", "253402300800", "1.1234", "123 trailing"] {
            rejects { _ = try TimestampConverter.fromTimestamp(number, unit: .seconds, timeZone: utc) }
        }
        rejects { _ = try TimestampConverter.fromTimestamp("1.1", unit: .milliseconds, timeZone: utc) }
    }

    static func currencies() throws {
        for input in ["100￥", "￥100", "CNY100", "100 cny", "人民币100", "100¥"] {
            let query = try CurrencyQuery.parse(input, defaultSource: "USD", target: nil)
            check(query == CurrencyQuery(amount: "100", source: "CNY", target: nil))
        }
        check(try CurrencyQuery.parse("$200", defaultSource: "CNY", target: nil).source == "USD")
        check(try CurrencyQuery.parse(".5 EUR to JPY", defaultSource: "CNY", target: nil)
              == CurrencyQuery(amount: "0.5", source: "EUR", target: "JPY"))
        check(try CurrencyQuery.parse("100 CNY → USD", defaultSource: "EUR", target: "GBP").target == "USD")
        check(try CurrencyQuery.parse("100", defaultSource: "CNY", target: "EUR").target == "EUR")
        for input in ["", "$", "100 XYZ", "USD100CNY", "100 to", "100 to USD to EUR", "1.2.3 CNY", "1,000$"] {
            rejects { _ = try CurrencyQuery.parse(input, defaultSource: "CNY", target: nil) }
        }
        let rates = CurrencyRates(base: "USD", rates: ["CNY": 7.25, "EUR": 0.8], fetchedAt: Date(timeIntervalSince1970: 0))
        check(try CurrencyConversion.convert("10", from: "USD", to: "CNY", rates: rates) == "72.5")
        check(try CurrencyConversion.convert("7.25", from: "CNY", to: "USD", rates: rates) == "1")
        check(try CurrencyConversion.convert("-0.1", from: "USD", to: "EUR", rates: rates) == "-0.08")
        check(try CurrencyConversion.convert("0.1", from: "CNY", to: "CNY", rates: nil) == "0.1")
        for amount in ["", "NaN", "1,000", "1.2abc", "1e2", String(repeating: "9", count: 29)] {
            rejects { _ = try CurrencyConversion.convert(amount, from: "USD", to: "CNY", rates: rates) }
        }
        rejects { _ = try CurrencyConversion.convert("1", from: "USD", to: "CNY", rates: nil) }
        rejects { _ = try CurrencyConversion.convert("1", from: "USD", to: "JPY", rates: rates) }
    }

    static func check(_ condition: Bool) { precondition(condition) }

    static func rejects(_ operation: () throws -> Void) {
        do { try operation(); preconditionFailure("Invalid input was accepted") } catch { }
    }
}
