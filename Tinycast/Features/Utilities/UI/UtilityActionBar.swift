import SwiftUI

struct UtilityActionBar<Operations: View, Actions: View>: View {
    @ViewBuilder let operations: Operations
    @ViewBuilder let actions: Actions

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
                operations
                actions
            }
            .fixedSize()
            VStack(spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) { operations }
                HStack(spacing: Theme.Spacing.xs) { actions }
            }
            .fixedSize()
        }
        .buttonStyle(.utilityAction)
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.controlSurface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.utilityActions, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Actions"))
        .accessibilityIdentifier("utility-actions")
    }
}
