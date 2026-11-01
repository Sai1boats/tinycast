import SwiftUI

struct QRCodeView: View {
    @Environment(QRCodeCoordinator.self) private var coordinator
    @Environment(\.metrics) private var metrics
    let entries: [QRCodeEntry]
    let selected: QRCodeEntry?
    let scroll: ScrollIntent
    let onSelect: (QRCodeEntry) -> Void
    let onActions: (QRCodeEntry) -> Void

    var body: some View {
        HStack(spacing: 0) {
            history
                .frame(width: metrics.size.clipboardListWidth)
            Rectangle().fill(Theme.Colors.separator).frame(width: Theme.Size.hairline)
            QRCodePreview(entry: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if entries.isEmpty {
                        SectionHeader(title: String(localized: "History"), isFirst: true)
                        Text(coordinator.isBusy ? String(localized: "Loading…") : String(localized: "No QR codes yet"))
                            .font(metrics.typography.menuRow)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(metrics.spacing.md)
                    }
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let date = entry.createdAt.formatted(date: .abbreviated, time: .omitted)
                        if index == 0 || date != entries[index - 1].createdAt.formatted(date: .abbreviated, time: .omitted) {
                            SectionHeader(title: date, isFirst: index == 0)
                        }
                        QRCodeRow(entry: entry, selected: entry.id == selected?.id)
                            .id(entry.id.uuidString)
                            .selectionFrame(entry.id == selected?.id)
                            .contentShape(Rectangle())
                            .onRowClick(select: { onSelect(entry) }, activate: { coordinator.copy(entry) })
                            .onRightClick { onActions(entry) }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAddTraits(entry.id == selected?.id ? .isSelected : [])
                            .accessibilityAction { onSelect(entry) }
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
                scroll, row: selected?.id.uuidString,
                atOrigin: selected?.id == entries.first?.id, proxy: proxy)
        }
    }
}

private struct QRCodeRow: View {
    @Environment(\.metrics) private var metrics
    @State private var hovered = false
    let entry: QRCodeEntry
    let selected: Bool

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            SymbolImage(name: "qrcode", size: metrics.size.headerIconSlot)
                .font(metrics.typography.headerIcon)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: metrics.size.resultRowIcon, height: metrics.size.resultRowIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: metrics.spacing.xs) {
                Text(entry.title).font(metrics.typography.rowTitle).lineLimit(1)
                Text(entry.content)
                    .font(metrics.typography.keyCap)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(entry.createdAt, format: .dateTime.hour().minute())
                .font(metrics.typography.keyCap)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(metrics.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(selected ? Theme.Colors.selection : hovered ? Theme.Colors.rowHover : .clear))
        .armedHover($hovered)
    }
}
