import SwiftUI

/// The clipboard header's type filter control: it states the active filter and toggles its menu.
struct ClipboardFilterButton: View {
    let filter: ClipboardFilter
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        HeaderMenuButton(
            title: NSLocalizedString(filter.title, comment: "Built-in label"),
            systemImage: filter.systemImage,
            isOpen: isOpen,
            help: String(localized: "Filter by type  ⌘P"),
            action: action)
    }
}
