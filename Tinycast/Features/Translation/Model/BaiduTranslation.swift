import Foundation

struct BaiduTranslation: Equatable, Sendable {
    let original: String
    let text: String
    let source: String
    let target: String

    enum Failure: String, Error {
        case empty = "Enter text to translate."
        case tooLong = "Use no more than 6000 UTF-8 bytes per translation."
        case credentials = "Configure your Baidu APP ID and secret first."
        case language = "Choose a supported translation language."
        case malformed = "Baidu returned an invalid translation response."
        case authentication = "Check your Baidu APP ID and secret."
        case rateLimit = "Too many translation requests. Try again shortly."
        case balance = "Check your Baidu translation account balance."
        case unavailable = "Baidu translation is unavailable. Check service activation and network access."
    }

    static func validate(_ text: String, source: String, target: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.empty }
        guard text.utf8.count <= 6000 else { throw Failure.tooLong }
        guard TranslationLanguage.codes.contains(source),
            TranslationLanguage.codes.contains(target), target != "auto"
        else { throw Failure.language }
    }

    static func decode(_ data: Data, original: String) throws -> Self {
        struct Response: Decodable {
            struct Segment: Decodable { let dst: String }
            let from: String?
            let to: String?
            let segments: [Segment]?
            let errorCode: String?
            enum CodingKeys: String, CodingKey {
                case from, to
                case segments = "trans_result"
                case errorCode = "error_code"
            }
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw Failure.malformed
        }
        if let code = response.errorCode, code != "52000" {
            switch code {
            case "52003", "54001": throw Failure.authentication
            case "54003", "54005": throw Failure.rateLimit
            case "54004": throw Failure.balance
            default: throw Failure.unavailable
            }
        }
        guard let source = response.from, !source.isEmpty,
            let target = response.to, target != "auto", !target.isEmpty,
            let segments = response.segments, !segments.isEmpty
        else { throw Failure.malformed }
        return Self(original: original, text: segments.map(\.dst).joined(separator: "\n"), source: source, target: target)
    }
}
