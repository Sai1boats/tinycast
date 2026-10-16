import Foundation

struct TranslationLanguage: Identifiable, Sendable {
    let id: String
    let name: String
    /// Apple's identifier for the same language; nil where Apple's translator has none.
    let apple: String?

    static let all: [Self] = [
        Self(id: "auto", name: "Auto Detect", apple: nil),
        Self(id: "zh", name: "Simplified Chinese", apple: "zh-Hans"),
        Self(id: "en", name: "English", apple: "en"), Self(id: "jp", name: "Japanese", apple: "ja"),
        Self(id: "kor", name: "Korean", apple: "ko"),
        Self(id: "cht", name: "Traditional Chinese", apple: "zh-Hant"),
        Self(id: "yue", name: "Cantonese", apple: nil), Self(id: "fra", name: "French", apple: "fr"),
        Self(id: "de", name: "German", apple: "de"), Self(id: "spa", name: "Spanish", apple: "es"),
        Self(id: "ru", name: "Russian", apple: "ru"), Self(id: "pt", name: "Portuguese", apple: "pt-BR"),
        Self(id: "it", name: "Italian", apple: "it"), Self(id: "th", name: "Thai", apple: "th"),
        Self(id: "ara", name: "Arabic", apple: "ar"), Self(id: "vie", name: "Vietnamese", apple: "vi")
    ]
    static let codes = Set(all.map(\.id))

    static func automaticTarget(detectedSource: String) -> String {
        ["zh", "cht", "yue"].contains(detectedSource) ? "en" : "zh"
    }

    static func apple(for code: String) -> String? {
        all.first { $0.id == code }?.apple
    }

    /// The panel speaks Baidu's codes, so an Apple or NaturalLanguage tag is read back into one.
    static func code(forLanguageTag tag: String) -> String {
        let lowered = tag.lowercased()
        if lowered.hasPrefix("zh") {
            return lowered.contains("hant") || lowered.hasSuffix("-tw") || lowered.hasSuffix("-hk") ? "cht" : "zh"
        }
        let base = lowered.split(separator: "-").first.map(String.init) ?? lowered
        return all.first { $0.apple?.lowercased().hasPrefix(base) == true }?.id ?? base
    }
}
