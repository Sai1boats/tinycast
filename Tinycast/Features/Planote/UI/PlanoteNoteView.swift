import AppKit
import SwiftUI

struct PlanoteNoteView: View {
    @Environment(PlanoteCoordinator.self) private var planote
    @State private var rendersMarkdown = true

    var body: some View {
        VStack(spacing: 0) {
            if let session = planote.session {
                editor(session)
            } else {
                ContentUnavailableView(
                    "Planote", systemImage: "text.page",
                    description: Text(planote.errorMessage ?? String(localized: "Select a note from the launcher.")))
            }
        }
        .padding(.top, 28)
        .background(Theme.Colors.windowSurface)
    }

    private func editor(_ session: PlanoteNoteSession) -> some View {
        @Bindable var session = session
        return VStack(spacing: Theme.Spacing.md) {
            HStack {
                TextField(String(localized: "Title"), text: $session.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .semibold))
                    .accessibilityIdentifier("planote-note-title")
                Button(action: planote.openPlanote) {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help(String(localized: "Open Planote"))
                .accessibilityLabel(String(localized: "Open Planote"))
            }
            .padding(.horizontal, Theme.Size.noteEditorInset)
            if let error = session.errorMessage ?? planote.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Size.noteEditorInset)
            }
            if session.base.summary.attachmentCount > 0 {
                Text("Attachments are preserved. Open Planote to view them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            NoteEditorView(
                input: session.input, rendersMarkdown: rendersMarkdown,
                onSourceChange: { session.markdown = $0 },
                onCharacterCountChange: { _, _ in }, onFormattingChange: { _, _ in },
                onReady: { _ in })
                .accessibilityIdentifier("planote-note-editor")
            HStack(spacing: Theme.Spacing.md) {
                Text(saveStatus(session)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                Toggle("Markdown", isOn: $rendersMarkdown).toggleStyle(.button)
                if session.hasConflict {
                    Button("Keep Draft & Reload") { Task { await session.reloadKeepingDraft() } }
                } else {
                    Button("Save") { session.scheduleSave(immediately: true) }
                        .disabled(session.isSaving || !session.isDirty)
                }
                Button("Drafts") { NSWorkspace.shared.open(planote.repository.drafts) }
            }
            .controlSize(.small)
            .padding([.horizontal, .bottom], Theme.Size.noteEditorInset)
        }
    }

    private func saveStatus(_ session: PlanoteNoteSession) -> String {
        if session.isSaving { return String(localized: "Saving…") }
        if session.isDirty { return String(localized: "Unsaved draft") }
        return String(localized: "Saved to Planote")
    }
}
