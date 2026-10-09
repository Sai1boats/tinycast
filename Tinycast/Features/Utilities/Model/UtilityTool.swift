import Foundation

enum UtilityTool: String, CaseIterable, Identifiable {
    case json, timestamp, currency
    var id: Self { self }
    var title: String {
        switch self {
        case .json: "JSON Tools"
        case .timestamp: "Timestamp Converter"
        case .currency: "Currency Converter"
        }
    }
}
