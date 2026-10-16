import SwiftUI

struct UtilityEditorPane: View {
    let title: String
    @Binding var text: String
    let editable: Bool
    var showsDiff = false
    var label: String?
    var detail = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Text(NSLocalizedString(title, comment: "Utility editor")).font(Theme.Typography.utilityPaneTitle)
                Spacer(minLength: Theme.Spacing.md)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xs)
            UtilityTextEditor(text: $text, editable: editable,
                              label: label ?? NSLocalizedString(title, comment: "Utility editor"), showsDiff: showsDiff)
        }
        .frame(minHeight: Theme.Size.utilityFocusPaneMinimum)
        .utilityCardSurface()
    }
}
