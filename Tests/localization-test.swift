import Foundation

@main
struct LocalizationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tinycast/Resources")
        let english = try bundle(root, language: "en")
        let chinese = try bundle(root, language: "zh-Hans")
        precondition(english.localizedString(forKey: "Settings", value: nil, table: nil) == "Settings")
        precondition(chinese.localizedString(forKey: "Settings", value: nil, table: nil) == "设置")
        precondition(chinese.localizedString(forKey: "Clipboard History", value: nil, table: nil) == "剪贴板历史")
        precondition(chinese.localizedString(forKey: "Language", value: nil, table: nil) == "语言")
        precondition(chinese.localizedString(forKey: "user-authored title", value: nil, table: nil) == "user-authored title")
        let format = chinese.localizedString(forKey: "After %lld seconds", value: nil, table: nil)
        precondition(String(format: format, 15) == "15 秒后")
        let named = chinese.localizedString(forKey: "Delete “%@”?", value: nil, table: nil)
        precondition(String(format: named, "Notes 100%") == "删除「Notes 100%」？")
        let permission = chinese.localizedString(forKey: "NSMicrophoneUsageDescription", value: nil, table: "InfoPlist")
        precondition(permission.contains("听写"))
        try switchingLanguages()
        print("Localization resources, formatting, and language preference passed")
    }

    static func bundle(_ root: URL, language: String) throws -> Bundle {
        let url = root.appendingPathComponent("\(language).lproj")
        guard let bundle = Bundle(url: url) else { throw CocoaError(.fileReadNoSuchFile) }
        return bundle
    }

    static func switchingLanguages() throws {
        let name = "com.tinycast.tests.localization.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else { throw CocoaError(.coderInvalidValue) }
        defer { defaults.removePersistentDomain(forName: name) }
        AppLanguage.simplifiedChinese.apply(to: defaults)
        precondition(defaults.persistentDomain(forName: name)?["AppleLanguages"] as? [String] == ["zh-Hans"])
        AppLanguage.english.apply(to: defaults)
        precondition(defaults.persistentDomain(forName: name)?["AppleLanguages"] as? [String] == ["en"])
        AppLanguage.system.apply(to: defaults)
        precondition(defaults.persistentDomain(forName: name)?["AppleLanguages"] == nil)
        precondition(AppLanguage(rawValue: "invalid") == nil)
        precondition(AppLanguage.allCases.count == 3)
    }
}
