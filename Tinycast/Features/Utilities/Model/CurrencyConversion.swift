import Foundation

enum CurrencyConversion {
    enum Failure: Error { case amount, unavailable, missingRate, overflow }

    static func convert(_ input: String, from: String, to: String, rates: CurrencyRates?) throws -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
            text.filter(\.isNumber).count <= 28,
            var amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
        else { throw Failure.amount }
        if from == to { return NSDecimalNumber(decimal: amount).stringValue }
        guard let rates else { throw Failure.unavailable }
        guard let source = rates.rate(for: from), let target = rates.rate(for: to),
            var sourceDecimal = Decimal(string: String(source), locale: Locale(identifier: "en_US_POSIX")),
            var targetDecimal = Decimal(string: String(target), locale: Locale(identifier: "en_US_POSIX"))
        else { throw Failure.missingRate }
        var base = Decimal()
        var output = Decimal()
        let division = NSDecimalDivide(&base, &amount, &sourceDecimal, .bankers)
        let multiplication = NSDecimalMultiply(&output, &base, &targetDecimal, .bankers)
        guard [division, multiplication].allSatisfy({ $0 == .noError || $0 == .lossOfPrecision }) else {
            throw Failure.overflow
        }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &output, 8, .bankers)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}
