import SwiftUI

struct TodoStatusCaption: View {
    @Environment(TodosCoordinator.self) private var todos

    var body: some View {
        if todos.pendingCount > 0 {
            HStack(spacing: Theme.Spacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "Syncing…"))
            }
            .font(Theme.Typography.todosMetadata)
            .foregroundStyle(Theme.Colors.textTertiary)
            .lineLimit(1)
        } else {
            Text(caption)
                .font(Theme.Typography.todosMetadata)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private var caption: String {
        if todos.isShowingEditor {
            return todos.editorDraft?.isNew == true
                ? String(localized: "Not created yet")
                : String(localized: "Save to apply changes")
        }
        switch todos.connection {
        case .live: return String(localized: "Up to date")
        case .offline: return String(localized: "Saved tasks")
        case .checking: return String(localized: "Checking…")
        case .notInstalled: return String(localized: "Not Installed")
        case .syncing: return String(localized: "Syncing…")
        }
    }
}
