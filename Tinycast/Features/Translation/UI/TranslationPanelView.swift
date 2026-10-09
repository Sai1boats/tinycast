import SwiftUI

struct TranslationPanelView: View {
    @Environment(TranslationCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            header
            if coordinator.showsSettings {
                TranslationCredentialsView()
            } else {
                ZStack(alignment: .topLeading) {
                    if coordinator.text.isEmpty {
                        Text("Enter text and press Return · Shift-Return for a new line")
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(.top, Theme.Spacing.sm)
                            .allowsHitTesting(false)
                    }
                    TranslationTextEditor(
                        text: $coordinator.text, onSubmit: coordinator.translate,
                        onHistory: coordinator.browseHistory)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                sourceTools
                languages
                resultView
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
        HStack(spacing: Theme.Spacing.xl) {
            Text("Quick Translate").font(.title3.weight(.medium))
            if coordinator.isLoading || coordinator.isTranslating {
                ProgressView().controlSize(.small)
            }
            Spacer()
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

    private var sourceTools: some View {
        HStack(spacing: Theme.Spacing.xl) {
            TranslationToolButton(title: "Previous Translation", symbol: "arrow.up") {
                coordinator.browseHistory(older: true)
            }
            TranslationToolButton(title: "Next Translation", symbol: "arrow.down") {
                coordinator.browseHistory(older: false)
            }
            Text("⌥↑ / ⌥↓ History").font(.caption).foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
            TranslationToolButton(title: "Clear Source", symbol: "eraser") { coordinator.text = "" }
            TranslationToolButton(title: "Read Clipboard", symbol: "clipboard", action: coordinator.readClipboard)
            TranslationToolButton(title: "Copy Source", symbol: "doc.on.doc") { coordinator.copy(coordinator.text) }
                .disabled(coordinator.text.isEmpty)
            Button("Translate", action: coordinator.translate)
                .buttonStyle(.modalAction(.primary, fillsWidth: false))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(coordinator.isLoading || coordinator.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var languages: some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Theme.Spacing.lg) {
            TranslationLanguageMenu(value: $coordinator.source, isTarget: false)
            TranslationToolButton(title: "Swap Languages", symbol: "arrow.left.arrow.right", action: coordinator.swapLanguages)
            TranslationLanguageMenu(value: $coordinator.destination, isTarget: true)
        }
    }

    private var resultView: some View {
        ScrollView {
            Text(coordinator.result?.text ?? String(localized: "Your translation appears here."))
                .font(.title3)
                .foregroundStyle(coordinator.result == nil ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "translate").foregroundStyle(Theme.Colors.primaryAction)
            Text("Baidu Translate").foregroundStyle(Theme.Colors.textSecondary)
            if let result = coordinator.result {
                Text("\(result.source) → \(result.target)").font(.caption).foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            TranslationToolButton(title: "Copy Translation", symbol: "doc.on.doc") {
                coordinator.copy(coordinator.result?.text ?? "")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(coordinator.result == nil)
            TranslationToolButton(title: "Paste Translation", symbol: "arrow.up.doc", action: coordinator.pasteResult)
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(coordinator.result == nil)
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
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.controlSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .menuIndicator(.hidden)
        .accessibilityLabel(isTarget ? String(localized: "Target Language") : String(localized: "Source Language"))
    }
}
