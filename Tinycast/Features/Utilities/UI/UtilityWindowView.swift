import SwiftUI

struct UtilityWindowView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    let tool: UtilityTool
    @State private var closeHovered = false

    private var symbol: String {
        switch tool {
        case .json: "curlybraces"
        case .timestamp: "clock.arrow.2.circlepath"
        case .currency: "dollarsign.arrow.circlepath"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch tool {
        case .json: "Clean, readable JSON. Every digit preserved."
        case .timestamp: "Move between Unix time and calendar dates."
        case .currency: "One amount. Currencies around the world."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                SymbolImage(name: symbol, size: Theme.Size.rowIcon).font(.title2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(Theme.Spacing.xl)
                    .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(NSLocalizedString(tool.title, comment: "Utility title")).font(.title2.weight(.semibold))
                    Text(subtitle).font(.callout).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Button { coordinator.close(tool) } label: {
                    SymbolImage(name: "xmark", size: Theme.Size.menuIcon)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: Theme.Size.menuButton, height: Theme.Size.menuButton)
                        .background(closeHovered ? Theme.Colors.controlHover : Theme.Colors.cardFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { closeHovered = $0 }
                .help(String(localized: "Close"))
                .accessibilityLabel(String(localized: "Close"))
            }
            switch tool {
            case .json: JSONToolView()
            case .timestamp: TimestampToolView()
            case .currency: CurrencyToolView()
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Theme.Colors.textPrimary)
        .background(Theme.Colors.panelScrim)
        .background(GlassEffectView())
        .onDisappear { coordinator.disappear(tool) }
    }
}
