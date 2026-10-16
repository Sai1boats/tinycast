import SwiftUI

struct UtilityWindowView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    let tool: UtilityTool
    var developerSession: DeveloperToolSession?

    private var symbol: String {
        switch tool {
        case .json: "curlybraces"
        case .timestamp: "clock.arrow.2.circlepath"
        case .currency: "dollarsign.arrow.circlepath"
        case .urlCodec: "link"
        case .base64: "arrow.left.arrow.right"
        case .uuid: "number"
        case .hash: "number.square"
        case .jwt: "key.horizontal"
        case .textDiff: "doc.text.magnifyingglass"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack(spacing: Theme.Spacing.md) {
                SymbolImage(name: symbol, size: Theme.Size.utilityGlyph)
                    .frame(width: Theme.Size.utilityGlyph, height: Theme.Size.utilityGlyph)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(NSLocalizedString(tool.title, comment: "Utility title"))
                    .font(Theme.Typography.utilityTitle)
                Spacer()
                Button { coordinator.close(tool) } label: {
                    SymbolImage(name: "xmark", size: Theme.Size.utilityCloseGlyph, monochrome: true)
                }
                .buttonStyle(UtilityCloseButtonStyle())
                .help(String(localized: "Close"))
                .accessibilityLabel(String(localized: "Close"))
            }
            .accessibilityIdentifier("utility-title")
            switch tool {
            case .json: JSONToolView()
            case .timestamp: TimestampToolView()
            case .currency: CurrencyToolView()
            case .urlCodec, .base64, .uuid, .hash, .jwt, .textDiff:
                if let developerSession { DeveloperToolView(tool: tool).environment(developerSession) }
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Theme.Colors.textPrimary)
        .background(Theme.Colors.utilitySurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.utilityWindow, style: .continuous))
        .ignoresSafeArea()
        .onDisappear { if !tool.isDeveloperTool { coordinator.disappear(tool) } }
    }
}
