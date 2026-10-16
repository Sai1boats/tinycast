import Foundation

enum Base64Codec {
    enum Alphabet: String, CaseIterable, Sendable {
        case standard, urlSafe
        var title: String { self == .standard ? "Standard Base64" : "Base64url" }
    }

    enum Failure: Error { case tooLarge, invalidEncoding, nonUTF8 }
    static let maximumBytes = 1_048_576

    static func encode(_ source: String, alphabet: Alphabet) throws -> String {
        guard source.utf8.count <= maximumBytes else { throw Failure.tooLarge }
        return encode(Data(source.utf8), alphabet: alphabet)
    }

    static func decode(_ source: String, alphabet: Alphabet) throws -> String {
        let data = try decodeData(source, alphabet: alphabet)
        guard let text = String(data: data, encoding: .utf8) else { throw Failure.nonUTF8 }
        return text
    }

    static func encode(_ data: Data, alphabet: Alphabet) -> String {
        let encoded = data.base64EncodedString()
        guard alphabet == .urlSafe else { return encoded }
        return encoded.replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decodeData(_ source: String, alphabet: Alphabet, allowsWhitespace: Bool = true) throws -> Data {
        guard source.utf8.count <= maximumBytes else { throw Failure.tooLarge }
        let input = allowsWhitespace ? source.filter { !$0.isWhitespace } : source
        let bytes = Array(input.utf8)
        let content = bytes.prefix { $0 != 61 }
        let padding = bytes.count - content.count
        guard padding <= 2, bytes.suffix(padding).allSatisfy({ $0 == 61 }),
            content.allSatisfy({ isAlphabet($0, alphabet: alphabet) }),
            content.count % 4 != 1,
            padding == 0 || bytes.count.isMultiple(of: 4),
            alphabet == .urlSafe || bytes.count.isMultiple(of: 4)
        else { throw Failure.invalidEncoding }
        guard let unpadded = String(bytes: content, encoding: .utf8) else { throw Failure.invalidEncoding }
        let standard = unpadded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let normalized = standard + String(repeating: "=", count: (4 - standard.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: normalized),
            encode(data, alphabet: alphabet).replacingOccurrences(of: "=", with: "") == unpadded
        else { throw Failure.invalidEncoding }
        return data
    }

    private static func isAlphabet(_ byte: UInt8, alphabet: Alphabet) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
            || (alphabet == .standard ? byte == 43 || byte == 47 : byte == 45 || byte == 95)
    }
}
