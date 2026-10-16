import Foundation

/// Which tool a pasted value plainly belongs to; nil whenever it could reasonably be anything.
enum UtilityInputDetector {
    /// The tools that can name their own input; Hash, Diff, UUID and Currency take any text.
    static let detectableTools: Set<UtilityTool> = [.jwt, .json, .timestamp, .urlCodec, .base64]
    static let minimumBase64Length = 16

    static func tool(for text: String, limit: Int = Base64Codec.maximumBytes) -> UtilityTool? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= limit else { return nil }
        if isJWT(value) { return .jwt }
        if isJSON(value) { return .json }
        if isTimestamp(value) { return .timestamp }
        if isPercentEncoded(value) { return .urlCodec }
        if base64Alphabet(for: value) != nil { return .base64 }
        return nil
    }

    static func isJWT(_ value: String) -> Bool {
        let token = value.lowercased().hasPrefix("bearer ") ? String(value.dropFirst(7)) : value
        guard token.hasPrefix("eyJ"), token.filter({ $0 == "." }).count == 2 else { return false }
        return (try? JWTContents.inspect(token, now: Date(timeIntervalSince1970: 0))) != nil
    }

    /// Objects and arrays only: a bare number or string is valid JSON but rarely meant as such.
    static func isJSON(_ value: String) -> Bool {
        guard let first = value.first, let last = value.last,
            first == "{" && last == "}" || first == "[" && last == "]"
        else { return false }
        return (try? JSONTool.process(value, operation: .compact)) != nil
    }

    /// Ten-digit seconds or thirteen-digit milliseconds, the two spellings tools actually emit.
    static func isTimestamp(_ value: String) -> Bool {
        guard value.count == 10 || value.count == 13, value.allSatisfy(\.isASCII), value.allSatisfy(\.isNumber),
            let utc = TimeZone(identifier: "UTC")
        else { return false }
        return (try? TimestampConverter.fromTimestamp(value, unit: .automatic, timeZone: utc)) != nil
    }

    static func isPercentEncoded(_ value: String) -> Bool {
        guard value.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) != nil,
            let decoded = try? URLCodec.decode(value, mode: .component)
        else { return false }
        return decoded != value
    }

    /// Readable UTF-8 only, so a hex digest or a random word never passes for Base64.
    static func base64Alphabet(for value: String) -> Base64Codec.Alphabet? {
        guard value.count >= minimumBase64Length, !value.contains(where: \.isWhitespace) else { return nil }
        for alphabet in Base64Codec.Alphabet.allCases {
            guard let decoded = try? Base64Codec.decode(value, alphabet: alphabet), isReadable(decoded) else { continue }
            return alphabet
        }
        return nil
    }

    private static func isReadable(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { scalar in
            scalar == "\n" || scalar == "\r" || scalar == "\t"
                || !CharacterSet.controlCharacters.contains(scalar) && scalar.properties.generalCategory != .unassigned
        }
    }
}
