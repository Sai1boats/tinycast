import Foundation
import NaturalLanguage
import Translation

/// `TranslationError` is macOS 26.4 against a 26.0 floor, so failures stay plain `Error` here.
enum TextTranslator {
    enum Failure: LocalizedError, Equatable {
        case undetectableSource
        case unsupported
        case notInstalled(language: String)
        case failed

        var errorDescription: String? {
            switch self {
            case .undetectableSource:
                return String(localized: "The language of the selected text could not be identified.")
            case .unsupported:
                return String(localized: "Apple's translator does not support this language pair.")
            case .notInstalled(let language):
                return String(localized: "\(language) needs to be downloaded before it can be used.")
            case .failed:
                return String(localized: "The text could not be translated.")
            }
        }
    }

    /// `TranslationSession(installedSource:)` needs a language; availability reports only a status.
    static func sourceLanguage(of text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage, dominant != .undetermined else {
            return nil
        }
        return Locale.Language(identifier: dominant.rawValue)
    }

    /// Installed pairs only: a missing language is downloaded in System Settings, never from here.
    static func translate(
        _ paragraphs: [String], from source: Locale.Language? = nil, to target: Locale.Language
    ) async throws -> [String] {
        guard let source = source ?? sourceLanguage(of: paragraphs.joined(separator: "\n")) else {
            throw Failure.undetectableSource
        }
        guard !source.isEquivalent(to: target) else { return paragraphs }
        switch await LanguageAvailability().status(from: source, to: target) {
        case .installed:
            break
        case .supported:
            throw Failure.notInstalled(language: displayName(of: target))
        case .unsupported:
            throw Failure.unsupported
        @unknown default:
            throw Failure.unsupported
        }
        let requests = paragraphs.indices.filter { !paragraphs[$0].trimmingCharacters(in: .whitespaces).isEmpty }
            .map { TranslationSession.Request(sourceText: paragraphs[$0], clientIdentifier: String($0)) }
        guard !requests.isEmpty else { return paragraphs }
        let responses: [TranslationSession.Response]
        do {
            responses = try await TranslationSession(installedSource: source, target: target)
                .translations(from: requests)
        } catch {
            throw Failure.failed
        }
        var translated = paragraphs
        for response in responses {
            guard let index = response.clientIdentifier.flatMap(Int.init), translated.indices.contains(index)
            else { continue }
            translated[index] = response.targetText
        }
        return translated
    }

    /// Minimal, not maximal: the maximal form would spell `es` "Spanish (Latin, Spain)" in a menu.
    static func displayName(of language: Locale.Language) -> String {
        Locale.current.localizedString(forIdentifier: language.minimalIdentifier)
            ?? language.minimalIdentifier
    }

    /// The framework's own list, so the picker cannot offer a pair that only fails at press time.
    static func supportedLanguages() async -> [Locale.Language] {
        await LanguageAvailability().supportedLanguages
            .sorted { displayName(of: $0) < displayName(of: $1) }
    }
}
