import SwiftUI

struct CurrencyResultCard: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    let code: String
    let value: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(code).font(.subheadline.weight(.semibold))
                    Text(Locale.current.localizedString(forCurrencyCode: code) ?? code)
                        .font(.caption).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
                }
                Text(value ?? String(localized: "Rate unavailable"))
                    .font(.title2.monospacedDigit())
                    .textSelection(.enabled)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(value == nil ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
            }
            Spacer(minLength: 0)
            Button { if let value { coordinator.copy(value) } } label: {
                SymbolImage(name: "doc.on.doc", size: Theme.Size.menuIcon).foregroundStyle(Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain).disabled(value == nil)
            .help(String(localized: "Copy Result"))
            .accessibilityLabel(String(localized: "Copy Result") + " " + code)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}
