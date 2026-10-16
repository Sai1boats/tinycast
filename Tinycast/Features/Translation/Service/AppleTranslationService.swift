import Foundation

/// The on-device stand-in when Baidu cannot answer; it speaks the panel's Baidu language codes.
enum AppleTranslationService {
    enum Failure: String, Error {
        case unsupportedLanguage = "Apple Translation does not support the selected language."
    }

    @concurrent static func translate(text: String, source: String, target: String) async throws -> TranslationResult {
        let resolvedSource = source == "auto" ? TranslationLanguageDetector.detect(text) : source
        let resolvedTarget = TranslationLanguageDetector.resolvedTarget(for: text, source: source, target: target)
        guard let targetIdentifier = TranslationLanguage.apple(for: resolvedTarget) else {
            throw Failure.unsupportedLanguage
        }
        let sourceLanguage: Locale.Language?
        if let resolvedSource {
            guard let identifier = TranslationLanguage.apple(for: resolvedSource) else {
                throw Failure.unsupportedLanguage
            }
            sourceLanguage = Locale.Language(identifier: identifier)
        } else {
            sourceLanguage = nil
        }
        let lines = text.components(separatedBy: "\n")
        let translated = try await TextTranslator.translate(
            lines, from: sourceLanguage, to: Locale.Language(identifier: targetIdentifier))
        try Task.checkCancellation()
        let paragraphs = zip(lines, translated).map { line, output in
            line.trimmingCharacters(in: .whitespaces).isEmpty
                ? TranslationResult.Paragraph(source: "", text: "")
                : TranslationResult.Paragraph(source: line, text: output)
        }
        return TranslationResult(
            original: text, paragraphs: paragraphs, source: resolvedSource ?? source,
            target: resolvedTarget, provider: .apple)
    }
}
