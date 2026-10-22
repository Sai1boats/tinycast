import Foundation

/// How a due date sits relative to now, judged on calendar days rather than on instants.
enum TodoDueLabel: Equatable, Sendable {
    case overdue(Date)
    case today
    case tomorrow
    case date(Date)
}

struct TodoSectionGroup: Identifiable, Equatable {
    let id: String
    let sectionID: UUID?
    let title: String?
    let tasks: [TodoBridgeTask]
}

/// Pure grouping, ordering and date semantics over one bridge snapshot.
struct TodoListModel {
    static let inboxGroupID = "inbox"

    private let snapshot: TodoBridgeSnapshot

    init(snapshot: TodoBridgeSnapshot) {
        self.snapshot = snapshot
    }

    /// One group per board section in snapshot order with the inbox first, empty groups omitted.
    func groups(includingCompleted: Bool, now: Date, calendar: Calendar) -> [TodoSectionGroup] {
        let visible = includingCompleted
            ? snapshot.tasks
            : snapshot.tasks.filter { !$0.isCompleted }
        let inbox = snapshot.boardSections.first(where: \.isInbox)
        var slots: [(key: String, sectionID: UUID?, title: String?)] = []
        if let inbox {
            slots.append((inbox.id.uuidString, inbox.id, inbox.name))
        }
        for section in snapshot.boardSections where !section.isInbox {
            slots.append((section.id.uuidString, section.id, section.name))
        }
        if inbox == nil {
            slots.append((Self.inboxGroupID, nil, nil))
        }

        var assigned: [String: [TodoBridgeTask]] = [:]
        for task in visible {
            assigned[groupKey(for: task, inbox: inbox), default: []].append(task)
        }
        return slots.compactMap { slot in
            guard let tasks = assigned[slot.key], !tasks.isEmpty else { return nil }
            return TodoSectionGroup(
                id: slot.key, sectionID: slot.sectionID, title: slot.title,
                tasks: tasks.sorted(by: Self.precedes))
        }
    }

    func task(id: UUID) -> TodoBridgeTask? {
        snapshot.tasks.first { $0.id == id }
    }

    /// A nil id names the inbox, the bucket a task without a section lands in.
    func section(id: UUID?) -> TodoBridgeBoardSection? {
        guard let id else { return snapshot.boardSections.first(where: \.isInbox) }
        return snapshot.boardSections.first { $0.id == id }
    }

    func label(id: UUID?) -> TodoBridgeLabel? {
        guard let id else { return nil }
        return snapshot.labels.first { $0.id == id }
    }

    static func dueLabel(for dueDate: Date?, now: Date, calendar: Calendar) -> TodoDueLabel? {
        guard let dueDate else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        if dueDate < startOfToday { return .overdue(dueDate) }
        if calendar.isDate(dueDate, inSameDayAs: now) { return .today }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              calendar.isDate(dueDate, inSameDayAs: tomorrow) else {
            return .date(dueDate)
        }
        return .tomorrow
    }

    /// Past due, but only an incomplete task can *be* past due.
    static func isOverdue(task: TodoBridgeTask, now: Date, calendar: Calendar) -> Bool {
        guard !task.isCompleted, let dueDate = task.dueDate else { return false }
        return dueDate < calendar.startOfDay(for: now)
    }

    static func subtaskSummary(task: TodoBridgeTask) -> (completed: Int, total: Int) {
        (task.subtasks.filter(\.isCompleted).count, task.subtasks.count)
    }

    /// Incomplete before completed, then due dates with undated last, then the title.
    private static func precedes(_ lhs: TodoBridgeTask, _ rhs: TodoBridgeTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none), (.some, .some):
            break
        }
        let order = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        return order != .orderedSame ? order == .orderedAscending : lhs.title < rhs.title
    }

    private func groupKey(for task: TodoBridgeTask, inbox: TodoBridgeBoardSection?) -> String {
        if let sectionID = task.boardSectionID,
           let section = snapshot.boardSections.first(where: { $0.id == sectionID }) {
            return section.id.uuidString
        }
        return inbox?.id.uuidString ?? Self.inboxGroupID
    }
}

extension TodoBridgeTask {
    /// Title-only: a task carries a label id, never the label name.
    func matches(query: String) -> Bool {
        query.isEmpty || title.localizedStandardContains(query)
    }
}
