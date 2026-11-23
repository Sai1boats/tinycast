import Foundation

enum NoteSidebarFilter: Equatable, Sendable {
    case all, pinned, tasks, tag(String)

    func apply(to summaries: [NoteSummary], pins: Set<NoteID>) -> [NoteSummary] {
        summaries.filter { summary in
            switch self {
            case .all: true
            case .pinned: pins.contains(summary.id)
            case .tasks: summary.pendingTaskCount > 0
            case .tag(let tag): summary.tags.contains(tag)
            }
        }.sorted { lhs, rhs in
            if pins.contains(lhs.id) != pins.contains(rhs.id) { return pins.contains(lhs.id) }
            if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
            return lhs.id.rawValue.localizedStandardCompare(rhs.id.rawValue) == .orderedAscending
        }
    }
}
