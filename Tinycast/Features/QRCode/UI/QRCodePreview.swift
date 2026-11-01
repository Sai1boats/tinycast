import SwiftUI

struct QRCodePreview: View {
    @Environment(QRCodeCoordinator.self) private var coordinator
    @Environment(\.metrics) private var metrics
    let entry: QRCodeEntry?
    @State private var image: NSImage?
    @State private var imageID: UUID?
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(spacing: metrics.spacing.xl) {
                if let entry {
                    if imageID == entry.id, let image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: metrics.size.qrCodePreview)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.radius.card, style: .continuous))
                            .accessibilityLabel(String(localized: "QR Code"))
                    } else if let failure {
                        Text(failure).foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        ProgressView().frame(height: metrics.size.qrCodePreview)
                    }
                    Text(entry.title).font(metrics.typography.panelTitle).lineLimit(2)
                    Text(entry.content)
                        .font(metrics.typography.keyCap)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                    Text(entry.createdAt, format: .dateTime.year().month().day().hour().minute())
                        .font(metrics.typography.keyCap)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    HStack(spacing: metrics.spacing.sm) {
                        Button("Copy Image") { coordinator.copy(entry) }
                        Button("Save Image…") { coordinator.save(entry) }
                    }
                    .buttonStyle(.borderless)
                    .font(metrics.typography.bar)
                    .disabled(coordinator.isBusy || imageID != entry.id)
                } else {
                    SymbolImage(name: "qrcode", size: metrics.size.dialogSymbol)
                        .font(.system(size: metrics.size.dialogSymbol))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .accessibilityHidden(true)
                    Text("Enter text or a URL, then press Return.")
                        .font(metrics.typography.menuRow)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(metrics.spacing.xxl)
        }
        .edgeDissolve()
        .task(id: entry?.id) {
            image = nil
            imageID = nil
            failure = nil
            guard let entry else { return }
            do {
                let data = try await QRCodeRenderer.png(for: entry.content)
                try Task.checkCancellation()
                guard let rendered = NSImage(data: data) else { throw QRCodeHistory.Failure.rendering }
                image = rendered
                imageID = entry.id
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                failure = error.localizedDescription
            }
        }
    }
}
