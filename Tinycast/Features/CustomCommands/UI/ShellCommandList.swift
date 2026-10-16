import SwiftUI

struct ShellCommandList: View {
    @Environment(\.metrics) private var metrics
    let rows: [ShellCommandHistory.Row]
    let selectedID: String?
    let scroll: ScrollIntent
    let onSelect: (ShellCommandHistory.Row) -> Void
    let onActivate: () -> Void
    let onActions: (ShellCommandHistory.Row) -> Void

    private var firstHistoryID: String? {
        rows.first {
            if case .history(_, false) = $0 { return true }
            return false
        }?.id
    }

    private var firstPinnedID: String? {
        rows.first(where: \.isPinned)?.id
    }

    var body: some View {
        let firstHistoryID = firstHistoryID
        let firstPinnedID = firstPinnedID
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        if case .typed = row {
                            SectionHeader(title: String(localized: "Run Shell Command"), isFirst: true)
                        } else if row.id == firstPinnedID {
                            SectionHeader(title: String(localized: "Pinned Commands"), isFirst: row == rows.first)
                        } else if row.id == firstHistoryID {
                            SectionHeader(title: String(localized: "Shell History"), isFirst: row == rows.first)
                        }
                        CommandRow(row: row, selected: row.id == selectedID)
                            .selectionFrame(row.id == selectedID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(row)
                                if case .typed = row { onActivate() }
                            }
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
                                guard case .history = row else { return }
                                onSelect(row)
                                onActivate()
                            })
                            .onRightClick { onActions(row) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(row.command)
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
        let row: ShellCommandHistory.Row
        let selected: Bool
        @State private var hovered = false

        private var fill: Color {
            if selected { return Theme.Colors.selection }
            return hovered ? Theme.Colors.rowHover : .clear
        }

        var body: some View {
            IconCache.observeStyle()
            return HStack(spacing: metrics.spacing.lg) {
                Image(nsImage: IconCache.symbolIcon(named: "terminal"))
                    .resizable()
                    .frame(width: metrics.size.resultRowIcon, height: metrics.size.resultRowIcon)
                Text(verbatim: row.command)
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
