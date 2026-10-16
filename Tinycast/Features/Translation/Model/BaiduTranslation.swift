import Foundation

enum BaiduTranslation {
    enum Failure: String, Error {
        case empty = "Enter text to translate."
        case tooLong = "Use no more than 60000 UTF-8 bytes per translation."
        case credentials = "Baidu credentials are not configured."
        case language = "Choose a supported translation language."
        case malformed = "Baidu returned an invalid translation response."
        case authentication = "Check your Baidu APP ID and secret."
        case rateLimit = "Too many translation requests. Try again shortly."
        case balance = "Check your Baidu translation account balance."
        case unavailable = "Baidu translation is unavailable. Check service activation and network access."

        /// What the reader did wrong is not fixed by asking another translator.
        var allowsFallback: Bool { self != .empty && self != .language }
    }

    /// Cancellation is the reader's own doing; anything else Baidu or the network did is not.
    static func allowsFallback(after error: any Error) -> Bool {
        if error is CancellationError { return false }
        if let failure = error as? Failure { return failure.allowsFallback }
        return (error as? URLError)?.code != .cancelled
    }

    static func validateDocument(_ text: String, source: String, target: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.empty }
        guard TranslationLanguage.codes.contains(source), TranslationLanguage.codes.contains(target) else {
            throw Failure.language
        }
        guard text.utf8.count <= TranslationChunks.totalLimit else { throw Failure.tooLong }
    }

    static func validate(_ text: String, source: String, target: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.empty }
        guard text.utf8.count <= TranslationChunks.requestLimit else { throw Failure.tooLong }
        guard TranslationLanguage.codes.contains(source),
            TranslationLanguage.codes.contains(target), target != "auto"
        else { throw Failure.language }
    }

    static func decode(_ data: Data, original: String) throws -> TranslationResult {
        struct Response: Decodable {
            struct Segment: Decodable {
                let src: String?
                let dst: String
            }
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
        let paragraphs = TranslationResult.paragraphs(
            original: original, translations: segments.map { ($0.src ?? "", $0.dst) })
        return TranslationResult(
            original: original, paragraphs: paragraphs, source: source, target: target, provider: .baidu)
    }
}
