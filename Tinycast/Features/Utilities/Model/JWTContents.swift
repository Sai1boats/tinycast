import Foundation

enum JWTContents {
    enum Failure: Error { case tooLarge, encrypted, invalidToken, invalidJSON }
    enum TimeStatus: Sendable { case expired, notYetActive, withinWindow, unspecified }

    struct Claim: Sendable, Equatable {
        let name: String
        let date: Date
    }

    struct Result: Sendable {
        let header: String
        let payload: String
        let signature: String
        let claims: [Claim]
        let timeStatus: TimeStatus
    }

    static func inspect(_ source: String, now: Date) throws -> Result {
        guard source.utf8.count <= Base64Codec.maximumBytes else { throw Failure.tooLarge }
        var token = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") { token = String(token.dropFirst(7)) }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count != 5 else { throw Failure.encrypted }
        guard parts.count == 3, !parts[0].isEmpty, !parts[1].isEmpty,
            parts.allSatisfy({ !$0.contains("=") && !$0.contains(where: \.isWhitespace) })
        else { throw Failure.invalidToken }
        let header = try object(parts[0])
        let payload = try object(parts[1])
        guard let metadata = try? JSONDecoder().decode(Header.self, from: header.data),
            !metadata.alg.isEmpty, metadata.b64 != false,
            (try? Base64Codec.decodeData(parts[2], alphabet: .urlSafe, allowsWhitespace: false)) != nil
        else { throw Failure.invalidToken }
        let claims = try JSONDecoder().decode(TimeClaims.self, from: payload.data).values
        let expiry = claims.first { $0.name == "exp" }?.date
        let notBefore = claims.first { $0.name == "nbf" }?.date
        let status: TimeStatus
        if let expiry, expiry <= now {
            status = .expired
        } else if let notBefore, notBefore > now {
            status = .notYetActive
        } else {
            status = expiry == nil && notBefore == nil ? .unspecified : .withinWindow
        }
        return Result(header: header.text, payload: payload.text, signature: parts[2], claims: claims, timeStatus: status)
    }

    private struct Header: Decodable {
        let alg: String
        let b64: Bool?
    }

    private struct TimeClaims: Decodable {
        enum Key: String, CodingKey, CaseIterable { case iat, nbf, exp }
        let values: [Claim]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            values = Key.allCases.compactMap { key in
                guard let seconds = try? container.decode(Double.self, forKey: key), seconds.isFinite,
                    (-62_135_596_800..<253_402_300_800).contains(seconds)
                else { return nil }
                return Claim(name: key.rawValue, date: Date(timeIntervalSince1970: seconds))
            }
        }
    }

    private static func object(_ encoded: String) throws -> (text: String, data: Data) {
        let text: String
        do { text = try Base64Codec.decode(encoded, alphabet: .urlSafe) } catch { throw Failure.invalidToken }
        guard let formatted = try? JSONTool.process(text, operation: .format), formatted.hasPrefix("{")
        else { throw Failure.invalidJSON }
        return (formatted, Data(text.utf8))
    }
}
