import Foundation

@main
struct LocalizationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tinycast/Resources")
        let data = try Data(contentsOf: root.appendingPathComponent("Localizable.xcstrings"))
        let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = catalog?["strings"] as? [String: [String: Any]] ?? [:]
        for key in ["Quick Translate", "JSON Tools", "Run Shell Command", "Todos", "Planote"] {
            let localizations = strings[key]?["localizations"] as? [String: [String: Any]]
            let unit = localizations?["zh-Hans"]?["stringUnit"] as? [String: String]
            precondition(unit?["state"] == "translated", "Missing Chinese translation: \(key)")
            precondition(unit?["value"]?.isEmpty == false, "Empty translation: \(key)")
        }
        print("Fork commands retain Chinese translations in the string catalog")
    }
}
