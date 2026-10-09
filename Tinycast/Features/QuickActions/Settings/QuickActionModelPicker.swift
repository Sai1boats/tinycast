import SwiftUI

/// One action's own route, staged by the editor panel that presents it until Save.
struct QuickActionModelPicker: View {
    @Binding var selection: AIModelSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(String(localized: "Model"))
                .font(.callout.weight(.medium))
            HStack(spacing: Theme.Spacing.lg) {
                AIModelSelectionRows(
                    selection: selection,
                    inheritedTitle: String(localized: "Same as Quick Actions"),
                    select: { selection = $0 },
                    modelLabel: { Text(String(localized: "Model")) },
                    effortLabel: { Text(String(localized: "Reasoning effort")) })
            }
            .labelsHidden()
        }
    }
}
