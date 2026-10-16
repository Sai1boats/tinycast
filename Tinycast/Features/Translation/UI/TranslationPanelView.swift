import SwiftUI

struct TranslationPanelView: View {
    @Environment(TranslationCoordinator.self) private var coordinator
    @State private var isWide = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            header
            if coordinator.showsSettings {
                TranslationCredentialsView()
            } else {
                languages
                let layout = isWide
                    ? AnyLayout(HStackLayout(spacing: Theme.Spacing.xl))
                    : AnyLayout(VStackLayout(spacing: Theme.Spacing.xl))
                layout {
                    sourcePane
                    resultPane
                }
                footer
            }
            if !coordinator.message.isEmpty {
                Text(coordinator.message)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.destructive)
                    .textSelection(.enabled)
            }
        }
        .padding(Theme.Spacing.xxl)
        .onGeometryChange(for: Bool.self) { $0.size.width >= Theme.Size.translationSideBySideWidth } action: {
            isWide = $0
        }
        .background(Theme.Colors.panelScrim)
        .background(GlassEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.panel)
                .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("Quick Translate").font(.title3.weight(.medium))
            if coordinator.isLoading || coordinator.isTranslating {
                ProgressView().controlSize(.small)
            }
            Spacer()
            TranslationToolButton(title: "Smaller Text", symbol: "textformat.size.smaller") {
                coordinator.adjustTextSize(by: -Theme.Size.translationTextStep)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(coordinator.textSize <= Theme.Size.translationTextMinimum)
            TranslationToolButton(title: "Larger Text", symbol: "textformat.size.larger") {
                coordinator.adjustTextSize(by: Theme.Size.translationTextStep)
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(coordinator.textSize >= Theme.Size.translationTextMaximum)
            TranslationToolButton(
                title: coordinator.isExpanded ? "Restore Size" : "Expand",
                symbol: coordinator.isExpanded
                    ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                action: coordinator.toggleExpanded)
            TranslationToolButton(title: "Translation Settings", symbol: "gearshape") {
                coordinator.showsSettings.toggle()
            }
            .disabled(coordinator.isLoading || coordinator.isSaving)
            TranslationToolButton(title: "Keep on Top", symbol: coordinator.isPinned ? "pin.fill" : "pin") {
                coordinator.isPinned.toggle()
            }
            .accessibilityValue(coordinator.isPinned ? String(localized: "On") : String(localized: "Off"))
            TranslationToolButton(title: "Close", symbol: "xmark", action: coordinator.close)
        }
    }

    private var languages: some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Theme.Spacing.lg) {
            TranslationLanguageMenu(value: $coordinator.source, isTarget: false)
            TranslationToolButton(title: "Swap Languages", symbol: "arrow.left.arrow.right", action: coordinator.swapLanguages)
            TranslationLanguageMenu(value: $coordinator.destination, isTarget: true)
            Button("Translate", action: coordinator.translate)
                .buttonStyle(.modalAction(.primary, fillsWidth: false))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(coordinator.isLoading || coordinator.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var sourcePane: some View {
        @Bindable var coordinator = coordinator
        return TranslationPane {
            Text("Source").font(Theme.Typography.utilityPaneTitle).foregroundStyle(Theme.Colors.textSecondary)
            if !coordinator.text.isEmpty {
                Text(TranslationPanelView.summary(of: coordinator.text))
                    .font(.caption).foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.sm)
            TranslationToolButton(title: "Previous Translation", symbol: "arrow.up") {
                coordinator.browseHistory(older: true)
            }
            TranslationToolButton(title: "Next Translation", symbol: "arrow.down") {
                coordinator.browseHistory(older: false)
            }
            TranslationToolButton(title: "Clear Source", symbol: "eraser") { coordinator.text = "" }
                .disabled(coordinator.text.isEmpty)
            TranslationToolButton(title: "Read Clipboard", symbol: "clipboard", action: coordinator.readClipboard)
            TranslationToolButton(title: "Copy Source", symbol: "doc.on.doc") { coordinator.copy(coordinator.text) }
                .disabled(coordinator.text.isEmpty)
        } content: {
            ZStack(alignment: .topLeading) {
                if coordinator.text.isEmpty {
                    Text("Enter text and press Return · Shift-Return for a new line")
                        .font(.system(size: coordinator.textSize))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.top, Theme.Spacing.sm)
                        .allowsHitTesting(false)
                }
                TranslationTextEditor(
                    text: $coordinator.text, fontSize: coordinator.textSize, onSubmit: coordinator.translate,
                    onHistory: coordinator.browseHistory)
            }
        }
    }

    private var resultPane: some View {
        @Bindable var coordinator = coordinator
        return TranslationPane {
            Text("Translation").font(Theme.Typography.utilityPaneTitle).foregroundStyle(Theme.Colors.textSecondary)
            if let progress = coordinator.progress, progress.total > 1 {
                Text("Translating part \(min(progress.completed + 1, progress.total)) of \(progress.total)")
                    .font(.caption).foregroundStyle(Theme.Colors.textTertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: Theme.Spacing.sm)
            TranslationToolButton(
                title: coordinator.showsBilingual ? "Show Translation Only" : "Show Side by Side",
                symbol: coordinator.showsBilingual ? "text.alignleft" : "rectangle.split.1x2"
            ) {
                coordinator.showsBilingual.toggle()
            }
            .disabled(coordinator.displayedResult == nil)
            TranslationToolButton(title: "Copy Translation", symbol: "doc.on.doc") {
                coordinator.copy(coordinator.result?.text ?? "")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(coordinator.result == nil)
            TranslationToolButton(title: "Paste Translation", symbol: "arrow.up.doc", action: coordinator.pasteResult)
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(coordinator.result == nil)
        } content: {
            ZStack(alignment: .topLeading) {
                if coordinator.displayedResult == nil {
                    Text(coordinator.isTranslating
                         ? String(localized: "Translating…") : String(localized: "Your translation appears here."))
                        .font(.system(size: coordinator.textSize))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.top, Theme.Spacing.sm)
                        .allowsHitTesting(false)
                }
                TranslationResultText(
                    paragraphs: coordinator.displayedResult?.paragraphs ?? [],
                    bilingual: coordinator.showsBilingual, fontSize: coordinator.textSize)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "translate").foregroundStyle(Theme.Colors.primaryAction)
            Text(providerName).foregroundStyle(Theme.Colors.textSecondary)
            if let result = coordinator.result {
                Text("\(result.source) → \(result.target)").font(.caption).foregroundStyle(Theme.Colors.textTertiary)
            }
            if !coordinator.fallbackReason.isEmpty {
                Text(coordinator.fallbackReason)
                    .font(.caption).foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1).truncationMode(.tail)
                    .help(coordinator.fallbackReason)
            }
            if !coordinator.hasCredentials {
                Button("Set Up Baidu…") { coordinator.showsSettings = true }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            Spacer(minLength: Theme.Spacing.md)
            Text("⌥↑ / ⌥↓ History · ⌘− / ⌘= Text Size")
                .font(.caption).foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private var providerName: String {
        let provider = coordinator.result?.provider ?? (coordinator.hasCredentials ? .baidu : .apple)
        return provider == .apple ? String(localized: "Apple Translation") : String(localized: "Baidu Translate")
    }

    static func summary(of text: String) -> String {
        let characters = text.count
        let paragraphs = text.split(separator: "\n").filter { !$0.allSatisfy(\.isWhitespace) }.count
        let parts = text.utf8.count > TranslationChunks.requestLimit ? TranslationChunks.split(text).count : 1
        let base = String(localized: "\(characters) characters · \(paragraphs) paragraphs")
        guard text.utf8.count <= TranslationChunks.totalLimit else {
            return base + " · " + String(localized: "Too long for Baidu, uses Apple Translation")
        }
        return parts > 1 ? base + " · " + String(localized: "Sent in \(parts) parts") : base
    }
}

private struct TranslationPane<Tools: View, Content: View>: View {
    @ViewBuilder let tools: Tools
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) { tools }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct TranslationToolButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        let label = NSLocalizedString(title, comment: "Translation toolbar")
        Button(action: action) {
            Image(systemName: symbol)
                .frame(minWidth: Theme.Size.translationTool, minHeight: Theme.Size.translationTool)
        }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.textSecondary)
            .contentShape(Rectangle())
            .help(label)
            .accessibilityLabel(label)
    }
}

private struct TranslationLanguageMenu: View {
    @Binding var value: String
    let isTarget: Bool

    private var title: String {
        if isTarget && value == "auto" { return String(localized: "Auto · Chinese ↔ English") }
        let name = TranslationLanguage.all.first { $0.id == value }?.name ?? "Auto Detect"
        return NSLocalizedString(name, comment: "Translation language")
    }

    var body: some View {
        Menu {
            ForEach(TranslationLanguage.all) { language in
                Button {
                    value = language.id
                } label: {
                    let name = isTarget && language.id == "auto" ? "Auto · Chinese ↔ English" : language.name
                    if value == language.id {
                        Label(NSLocalizedString(name, comment: "Translation language"), systemImage: "checkmark")
                    } else {
                        Text(NSLocalizedString(name, comment: "Translation language"))
                    }
                }
            }
        } label: {
            HStack {
                Spacer()
                Text(title)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.xl)
            .background(Theme.Colors.controlSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .menuIndicator(.hidden)
        .accessibilityLabel(isTarget ? String(localized: "Target Language") : String(localized: "Source Language"))
    }
}
