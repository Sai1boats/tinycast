import SwiftUI

struct UtilityCard<Content: View>: View {
    let title: Text
    var detail = ""
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack(spacing: Theme.Spacing.md) {
                title.font(Theme.Typography.utilityPaneTitle)
                Spacer(minLength: Theme.Spacing.md)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
                        .help(detail)
                }
            }
            content
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .utilityCardSurface()
    }
}

extension View {
    func utilityCardSurface() -> some View {
        background(Theme.Colors.utilityEditor,
                   in: RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous)
                    .strokeBorder(Theme.Colors.cardStroke, lineWidth: Theme.Size.hairline)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
    }
}
