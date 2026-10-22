import AppKit
import Observation
import SwiftUI

@MainActor @Observable final class AppSettings {}

@MainActor @Observable final class PlanoteCoordinator {
    var session: PlanoteNoteSession?
    var errorMessage: String?
    let repository: PlanoteNoteRepository
    init(repository: PlanoteNoteRepository) { self.repository = repository }
    func ensureService() async throws { throw CocoaError(.userCancelled) }
    func refresh() {}
    func openPlanote() {}
}

@main
@MainActor
struct PlanoteUITests {
    static func main() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = PlanoteNoteRepository(directory: root, drafts: root.appending(path: "drafts"))
        let coordinator = PlanoteCoordinator(repository: repository)
        let note = PlanoteNote(
            summary: PlanoteNoteSummary(
                id: UUID(), title: "产品设计与本周计划", version: "1", modifiedAt: .now, attachmentCount: 0),
            markdown: "# 本周重点\n\n把想法写下来，让工作更清晰。支持 **粗体**、*斜体* 和快捷键。\n\n"
                + "## 待办清单\n\n- [x] 整理调研资料\n- [ ] 完善产品方案\n\n"
                + "> 保留原始 Markdown，随时编辑。\n")
        let session = PlanoteNoteSession(note: note, draft: nil, repository: repository, coordinator: coordinator)
        coordinator.session = session
        let hosting = NSHostingView(rootView: PlanoteNoteView().environment(coordinator).environment(AppSettings()))
        hosting.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 660, height: 580),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        for (appearance, name) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            window.appearance = NSAppearance(named: appearance)
            for (size, label) in [(NSSize(width: 660, height: 580), "default"), (NSSize(width: 440, height: 350), "minimum")] {
                window.setContentSize(size)
                try await Task.sleep(for: .milliseconds(120))
                hosting.layoutSubtreeIfNeeded()
                let editors = descendants(hosting).compactMap { $0 as? NoteTextView }
                precondition(editors.count == 1 && editors[0].string == note.markdown)
                if let path = ProcessInfo.processInfo.environment["TINYCAST_PLANOTE_PREVIEW_DIRECTORY"] {
                    let folder = URL(filePath: path)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
                    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!
                        .write(to: folder.appending(path: "planote-\(name)-\(label).png"))
                }
            }
        }
        let editor = descendants(hosting).compactMap { $0 as? NoteTextView }.first!
        editor.string = "# 直接编辑 📝\n\n- [x] 完成"
        editor.didChangeText()
        precondition(session.markdown == editor.string)
        await session.flush()
        let recovered = try await repository.loadDraft(note.summary.id)
        precondition(recovered?.markdown == editor.string)
        print("Planote UI: both appearances, both sizes, native editor and draft retention passed")
    }

    static func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
}
