import SwiftUI

struct ShellCommandList: View {
    @Environment(\.metrics) private var metrics
    typealias Row = ShellCommandScreen.Row
    let rows: [Row]
    let directory: String
    let selectedID: String?
    let scroll: ScrollIntent
    let onSelect: (Row) -> Void
    let onActivate: () -> Void
    let onActions: (Row) -> Void

    private var firstHistoryID: String? {
        rows.first {
            if case .command(.history(_, false)) = $0 { return true }
            return false
        }?.id
    }

    private var firstPinnedID: String? {
        rows.first {
            if case .command(let row) = $0 { return row.isPinned }
            return false
        }?.id
    }

    private var firstCompletionID: String? {
        guard case .completion? = rows.first else { return nil }
        return rows.first?.id
    }

    var body: some View {
        let firstHistoryID = firstHistoryID
        let firstPinnedID = firstPinnedID
        let firstCompletionID = firstCompletionID
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    SectionHeader(title: String(localized: "Working Directory: \(directory)"), isFirst: true)
                    if rows.isEmpty {
                        Text("No shell commands yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, metrics.spacing.sectionSpacing)
                    }
                    ForEach(rows) { row in
                        if row.id == firstCompletionID {
                            SectionHeader(title: String(localized: "Completions"))
                        } else if case .command(.typed) = row {
                            SectionHeader(title: String(localized: "Run Shell Command"))
                        } else if row.id == firstPinnedID {
                            SectionHeader(title: String(localized: "Pinned Commands"))
                        } else if row.id == firstHistoryID {
                            SectionHeader(title: String(localized: "Shell History"))
                        }
                        CommandRow(row: row, selected: row.id == selectedID)
                            .selectionFrame(row.id == selectedID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(row)
                                if case .command(.history) = row { return }
                                onActivate()
                            }
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
                                guard case .command(.history) = row else { return }
                                onSelect(row)
                                onActivate()
                            })
                            .onRightClick { onActions(row) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(row.title)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAddTraits(row.id == selectedID ? .isSelected : [])
                            .accessibilityAction {
                                onSelect(row)
                                onActivate()
                            }
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.top, metrics.spacing.xs)
                .padding(.bottom, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID, atOrigin: selectedID == rows.first?.id, proxy: proxy)
        }
    }

    private struct CommandRow: View {
        @Environment(\.metrics) private var metrics
        let row: Row
        let selected: Bool
        @State private var hovered = false

        private var fill: Color {
            if selected { return Theme.Colors.selection }
            return hovered ? Theme.Colors.rowHover : .clear
        }

        var body: some View {
            IconCache.observeStyle()
            return HStack(spacing: metrics.spacing.lg) {
                Image(nsImage: IconCache.symbolIcon(named: row.symbol))
                    .resizable()
                    .frame(width: metrics.size.resultRowIcon, height: metrics.size.resultRowIcon)
                Text(verbatim: row.title)
                    .font(metrics.typography.rowTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: metrics.spacing.sm)
                if row.isPinned {
                    SymbolImage(name: "pin.fill", size: metrics.size.menuIcon)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, metrics.spacing.md)
            .padding(.vertical, metrics.spacing.sm)
            .background(RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous).fill(fill))
            .armedHover($hovered)
        }
    }
}

private extension ShellCommandScreen.Row {
    var title: String {
        switch self {
        case .completion(let candidate): candidate.title
        case .command(let row): row.command
        }
    }

    var symbol: String {
        switch self {
        case .completion(let candidate): candidate.isDirectory ? "folder" : "text.cursor"
        case .command: "terminal"
        }
    }

    var isPinned: Bool {
        if case .command(let row) = self { return row.isPinned }
        return false
    }
}
