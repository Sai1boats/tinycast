import SwiftUI

/// Names what the clipboard holds; only Load reads it into the window.
struct UtilityClipboardBanner: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    let tool: UtilityTool

    private var message: String {
        switch tool {
        case .jwt: String(localized: "The clipboard contains a JWT. Load it?")
        case .json: String(localized: "The clipboard contains JSON. Load it?")
        case .timestamp: String(localized: "The clipboard contains a Unix timestamp. Load it?")
        case .urlCodec: String(localized: "The clipboard contains percent-encoded text. Load it?")
        case .base64: String(localized: "The clipboard contains Base64 text. Load it?")
        case .currency, .uuid, .hash, .textDiff: ""
        }
    }

    var body: some View {
        if coordinator.clipboardSuggestions[tool] != nil, !message.isEmpty {
            HStack(spacing: Theme.Spacing.md) {
                SymbolImage(name: "doc.on.clipboard", size: Theme.Size.utilityGlyph)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Load") { coordinator.acceptClipboardSuggestion(for: tool) }
                    .buttonStyle(.utilityAction)
                Button { coordinator.declineClipboardSuggestion(for: tool) } label: {
                    SymbolImage(name: "xmark", size: Theme.Size.utilityCloseGlyph, monochrome: true)
                }
                .buttonStyle(UtilityCloseButtonStyle())
                .help(String(localized: "Dismiss"))
                .accessibilityLabel(String(localized: "Dismiss"))
            }
            .padding(.leading, Theme.Spacing.xl)
            .padding(.trailing, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.controlSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.utilityActions, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("utility-clipboard-suggestion")
        }
    }
}
