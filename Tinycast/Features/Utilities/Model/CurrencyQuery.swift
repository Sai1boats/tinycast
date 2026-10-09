import Foundation

struct CurrencyQuery: Equatable, Sendable {
    enum Failure: Error { case invalid, unknownCurrency }
    let amount: String
    let source: String
    let target: String?

    static let popular = ["CNY", "USD", "EUR", "GBP", "JPY", "HKD", "CAD", "AUD", "SGD", "CHF"]

    static func parse(_ input: String, defaultSource: String, target: String?) throws -> Self {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= 160 else { throw Failure.invalid }
        let parts = text.components(separatedBy: try NSRegularExpression(pattern: #"\s*(?:->|→|(?i:\bto\b)|兑换|换成)\s*"#))
        guard parts.count <= 2 else { throw Failure.invalid }
        let pattern = #"^\s*([^0-9+\-.]*?)\s*([+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+))\s*([^0-9]*?)\s*$"#
        let expression = try NSRegularExpression(pattern: pattern)
        let amountText = parts[0]
        guard let match = expression.firstMatch(in: amountText, range: NSRange(amountText.startIndex..., in: amountText))
        else { throw Failure.invalid }
        func capture(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: amountText) else { return "" }
            return String(amountText[range]).trimmingCharacters(in: .whitespaces)
        }
        let prefix = capture(1), suffix = capture(3)
        guard prefix.isEmpty || suffix.isEmpty else { throw Failure.invalid }
        let source = try code(prefix.isEmpty ? suffix : prefix, fallback: defaultSource)
        let destination = parts.count == 2 ? try code(parts[1], fallback: nil) : target
        var amount = capture(2)
        if amount.hasPrefix(".") { amount = "0" + amount }
        if amount.hasPrefix("-.") { amount = amount.replacingOccurrences(of: "-.", with: "-0.") }
        if amount.hasPrefix("+.") { amount = amount.replacingOccurrences(of: "+.", with: "+0.") }
        guard amount.filter(\.isNumber).count <= 28 else { throw Failure.invalid }
        return Self(amount: amount, source: source, target: destination)
    }

    private static func code(_ text: String, fallback: String?) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.isEmpty, let fallback { return fallback }
        let aliases = ["￥": "CNY", "¥": "CNY", "人民币": "CNY", "元": "CNY", "$": "USD", "美元": "USD",
                       "€": "EUR", "欧元": "EUR", "£": "GBP", "英镑": "GBP", "日元": "JPY", "港币": "HKD"]
        if let code = aliases[value] ?? CalcCurrency.byName[value]?.code { return code }
        throw Failure.unknownCurrency
    }
}

private extension String {
    func components(separatedBy expression: NSRegularExpression) -> [String] {
        let matches = expression.matches(in: self, range: NSRange(startIndex..., in: self))
        var cursor = startIndex
        var result: [String] = []
        for match in matches {
            guard let range = Range(match.range, in: self) else { continue }
            result.append(String(self[cursor..<range.lowerBound]))
            cursor = range.upperBound
        }
        result.append(String(self[cursor...]))
        return result
    }
}
