import SwiftUI

struct UtilityResultRow: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            Text(NSLocalizedString(title, comment: "Utility result"))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value).monospaced().textSelection(.enabled)
            Button {
                coordinator.copy(value)
            } label: {
                SymbolImage(name: "doc.on.doc", size: Theme.Size.menuIcon)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Copy"))
            .accessibilityLabel(String(localized: "Copy") + " " + NSLocalizedString(title, comment: "Utility result"))
        }
    }
}
