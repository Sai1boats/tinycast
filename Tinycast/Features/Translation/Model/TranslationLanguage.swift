import Foundation

struct TranslationLanguage: Identifiable, Sendable {
    let id: String
    let name: String

    static let all: [Self] = [
        Self(id: "auto", name: "Auto Detect"), Self(id: "zh", name: "Simplified Chinese"),
        Self(id: "en", name: "English"), Self(id: "jp", name: "Japanese"),
        Self(id: "kor", name: "Korean"), Self(id: "cht", name: "Traditional Chinese"),
        Self(id: "yue", name: "Cantonese"), Self(id: "fra", name: "French"),
        Self(id: "de", name: "German"), Self(id: "spa", name: "Spanish"),
        Self(id: "ru", name: "Russian"), Self(id: "pt", name: "Portuguese"),
        Self(id: "it", name: "Italian"), Self(id: "th", name: "Thai"),
        Self(id: "ara", name: "Arabic"), Self(id: "vie", name: "Vietnamese")
    ]
    static let codes = Set(all.map(\.id))

    static func automaticTarget(detectedSource: String) -> String {
        ["zh", "cht", "yue"].contains(detectedSource) ? "en" : "zh"
    }
}
