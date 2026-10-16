import Foundation
import NaturalLanguage

enum TranslationLanguageDetector {
    /// Baidu's code for the text's dominant language, or nil when NaturalLanguage cannot tell.
    static func detect(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage, dominant != .undetermined else { return nil }
        return TranslationLanguage.code(forLanguageTag: dominant.rawValue)
    }

    static func resolvedTarget(for text: String, source: String, target: String) -> String {
        guard target == "auto" else { return target }
        let detected = source == "auto" ? detect(text) ?? "en" : source
        return TranslationLanguage.automaticTarget(detectedSource: detected)
    }
}
