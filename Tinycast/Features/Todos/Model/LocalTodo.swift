import Foundation

enum TodoPriority: String, Codable, CaseIterable, Sendable, Equatable {
    case none, low, medium, high

    var sortRank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        case .none: 3
        }
    }

    var next: TodoPriority {
        switch self {
        case .none: .low
        case .low: .medium
        case .medium: .high
        case .high: .none
        }
    }
}

enum TodoViewScope: Equatable, Hashable, Sendable {
    case inbox
    case today
    case scheduled
    case all
    case project(String)

    var projectName: String? {
        if case .project(let name) = self { return name }
        return nil
    }
}

enum TodoSortOrder: String, CaseIterable, Sendable {
    case manual, reminder, priority
}

enum TodoReminderPreset: CaseIterable, Sendable {
    case in30Minutes
    case tonight
    case tomorrowMorning
    case nextMonday

    func date(from now: Date, calendar: Calendar) -> Date {
        switch self {
        case .in30Minutes:
            return now.addingTimeInterval(30 * 60)
        case .tonight:
            let candidate = calendar.date(
                bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            if candidate > now { return candidate }
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? candidate
        case .tomorrowMorning:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        case .nextMonday:
            let start = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: start)
            // Weekday 2 is Monday in Gregorian; jump 1..7 days forward to the next Monday.
            let delta = ((9 - weekday) % 7) == 0 ? 7 : (9 - weekday) % 7
            let monday = calendar.date(byAdding: .day, value: delta, to: start) ?? start
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: monday) ?? monday
        }
    }
}

enum TodoProjectPalette {
    static let hexes = ["#38BDF8", "#A78BFA", "#34D399", "#FBBF24", "#FB7185", "#60A5FA"]

    static func hex(for name: String, stored: [String: String]?) -> String {
        if let saved = stored?[name], !saved.isEmpty { return saved }
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return hexes[abs(sum) % hexes.count]
    }
}

struct LocalTodo: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var project: String?
    var parentID: UUID?
    var reminder: Date?
    var notes: String?
    var priority: TodoPriority?
    var estimatedPomodoros: Int?
    var completedPomodoros: Int?
    var focusedMinutes: Int?

    init(
        id: UUID,
        title: String,
        isCompleted: Bool,
        project: String?,
        parentID: UUID?,
        reminder: Date?,
        notes: String? = nil,
        priority: TodoPriority? = nil,
        estimatedPomodoros: Int? = nil,
        completedPomodoros: Int? = nil,
        focusedMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.project = project
        self.parentID = parentID
        self.reminder = reminder
        self.notes = notes
        self.priority = priority
        self.estimatedPomodoros = estimatedPomodoros
        self.completedPomodoros = completedPomodoros
        self.focusedMinutes = focusedMinutes
    }

    var effectivePriority: TodoPriority { priority ?? .none }
    var effectiveEstimatedPomodoros: Int { max(0, estimatedPomodoros ?? 0) }
    var effectiveCompletedPomodoros: Int { max(0, completedPomodoros ?? 0) }
    var effectiveFocusedMinutes: Int { max(0, focusedMinutes ?? 0) }
}

struct TodoBoard: Codable, Equatable, Sendable {
    var projects: [String] = []
    var items: [LocalTodo] = []
    var projectColors: [String: String]?

    init(
        projects: [String] = [],
        items: [LocalTodo] = [],
        projectColors: [String: String]? = nil
    ) {
        self.projects = projects
        self.items = items
        self.projectColors = projectColors
    }

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

enum TodoListFilter {
    static func rootItems(
        in items: [LocalTodo],
        scope: TodoViewScope,
        query: String,
        sort: TodoSortOrder,
        now: Date,
        calendar: Calendar
    ) -> [LocalTodo] {
        let endOfToday = endOfDay(for: now, calendar: calendar)
        var roots = items.filter { item in
            guard item.parentID == nil else { return false }
            return matchesScope(item, scope: scope, endOfToday: endOfToday)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            roots = roots.filter { root in
                if root.title.localizedStandardContains(trimmed) { return true }
                if let notes = root.notes, notes.localizedStandardContains(trimmed) { return true }
                return items.contains {
                    $0.parentID == root.id && $0.title.localizedStandardContains(trimmed)
                }
            }
        }
        switch sort {
        case .manual:
            return roots
        case .reminder:
            return roots.sorted { lhs, rhs in
                switch (lhs.reminder, rhs.reminder) {
                case let (left?, right?) where left != right: return left < right
                case (.some, .none): return true
                case (.none, .some): return false
                default: return false
                }
            }
        case .priority:
            return roots.sorted {
                $0.effectivePriority.sortRank < $1.effectivePriority.sortRank
            }
        }
    }

    static func openCount(
        for scope: TodoViewScope,
        in items: [LocalTodo],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let endOfToday = endOfDay(for: now, calendar: calendar)
        return items.count { item in
            item.parentID == nil && !item.isCompleted
                && matchesScope(item, scope: scope, endOfToday: endOfToday)
        }
    }

    static func isOverdueReminder(_ item: LocalTodo, now: Date) -> Bool {
        guard !item.isCompleted, let reminder = item.reminder else { return false }
        return reminder < now
    }

    private static func matchesScope(
        _ item: LocalTodo, scope: TodoViewScope, endOfToday: Date
    ) -> Bool {
        switch scope {
        case .inbox: return item.project == nil
        case .today:
            guard let reminder = item.reminder else { return false }
            return reminder <= endOfToday
        case .scheduled: return item.reminder != nil
        case .all: return true
        case .project(let name): return item.project == name
        }
    }

    private static func endOfDay(for date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
}
