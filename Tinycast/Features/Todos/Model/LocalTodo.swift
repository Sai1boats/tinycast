import Foundation

struct LocalTodo: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var project: String?
    var parentID: UUID?
    var reminder: Date?
}

struct TodoBoard: Codable, Equatable, Sendable {
    var projects: [String] = []
    var items: [LocalTodo] = []

    func validated() throws -> Self {
        let ids = Set(items.map(\.id))
        let roots = Dictionary(grouping: items.filter { $0.parentID == nil }, by: \.id)
        let names = Set(projects)
        guard names.count == projects.count, ids.count == items.count,
            projects.allSatisfy({ !$0.isEmpty }),
            items.allSatisfy({ item in
                guard !item.title.isEmpty, item.project.map(names.contains) ?? true else { return false }
                guard let parentID = item.parentID else { return true }
                guard let parent = roots[parentID]?.first else { return false }
                return parent.project == item.project && (!parent.isCompleted || item.isCompleted)
            })
        else { throw CocoaError(.fileReadCorruptFile) }
        return self
    }
}
