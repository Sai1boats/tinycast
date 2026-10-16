import SwiftUI

struct CurrencyResultCard: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    let code: String
    let value: String?

    var body: some View {
        UtilityCard(title: Text(verbatim: code), detail: Locale.current.localizedString(forCurrencyCode: code) ?? code) {
            HStack(spacing: Theme.Spacing.xl) {
                Text(value ?? String(localized: "Rate unavailable"))
                    .font(.title3.monospacedDigit())
                    .textSelection(.enabled)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(value == nil ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                Spacer(minLength: 0)
                Button { if let value { coordinator.copy(value) } } label: {
                    SymbolImage(name: "doc.on.doc", size: Theme.Size.utilityGlyph)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain).disabled(value == nil)
                .help(String(localized: "Copy Result"))
                .accessibilityLabel(String(localized: "Copy Result") + " " + code)
            }
        }
    }
}
