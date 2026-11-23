import AppKit
import ImageIO
import Synchronization

final class NoteImageThumbnail: NSObject, Sendable {
    let width: Int
    let height: Int
    let pixels: @Sendable () -> CGImage?
    var aspectRatio: CGFloat { CGFloat(width) / CGFloat(height) }

    init(width: Int, height: Int, pixels: @escaping @Sendable () -> CGImage?) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

@MainActor
final class NoteImageCache {
    let directory: URL
    let scale: CGFloat
    private let changed: (String) -> Void
    private struct Decoded: Sendable {
        let image: CGImage
        let width: Int
        let height: Int
    }

    private let cache = Mutex(NSCache<NSString, CGImage>())
    private var cards: [String: NoteImageThumbnail] = [:]
    private var dimensions: [String: CGSize] = [:]
    private var unavailable = Set<String>()
    private var pending: [String: Task<Void, Never>] = [:]

    init(directory: URL, scale: CGFloat, changed: @escaping (String) -> Void) {
        self.directory = directory
        self.scale = scale
        self.changed = changed
        cache.withLock { $0.totalCostLimit = 64 * 1024 * 1024 }
    }

    func reset() {
        for task in pending.values { task.cancel() }
        pending.removeAll()
        cards.removeAll()
        unavailable.removeAll()
    }

    func thumbnail(for path: String) -> NoteImageThumbnail? {
        if let card = cards[path] { return card }
        request(path)
        return nil
    }

    private func request(_ path: String) {
        guard pending[path] == nil, !unavailable.contains(path) else { return }
        let store = NotesAssetStore(notesDirectory: directory)
        let pixels = Int(Theme.Size.noteImageMaxWidth * scale)
        pending[path] = Task { [weak self] in
            let entry = try? await Self.entry(for: path, store: store, pixels: pixels)
            guard let self, !Task.isCancelled else { return }
            if let (url, key) = entry {
                if cache.withLock({ $0.object(forKey: key as NSString) }) == nil {
                    let decoded = await Self.decode(url, pixels: pixels)
                    guard !Task.isCancelled else { return }
                    if let decoded {
                        cache.withLock {
                            $0.setObject(
                                decoded.image, forKey: key as NSString,
                                cost: decoded.image.bytesPerRow * decoded.image.height)
                        }
                        dimensions[key] = CGSize(width: decoded.width, height: decoded.height)
                    }
                }
                if let size = dimensions[key] {
                    cards[path] = NoteImageThumbnail(width: Int(size.width), height: Int(size.height)) { [weak self] in
                        guard let self else { return nil }
                        if let hit = cache.withLock({ $0.object(forKey: key as NSString) }) { return hit }
                        Task { @MainActor [weak self] in self?.request(path) }
                        return nil
                    }
                }
            }
            pending[path] = nil
            if cards[path] == nil { unavailable.insert(path) }
            changed(path)
        }
    }

    @concurrent
    private static func entry(
        for path: String, store: NotesAssetStore, pixels: Int
    ) async throws -> (URL, String) {
        let url = try store.validatedAssetURL(path)
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadCorruptFile) }
        return (url, "\(url.path)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(pixels)")
    }

    @concurrent
    private static func decode(_ url: URL, pixels: Int) async -> Decoded? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = info[kCGImagePropertyPixelWidth] as? Int,
            let height = info[kCGImagePropertyPixelHeight] as? Int,
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let rotated = (info[kCGImagePropertyOrientation] as? Int ?? 1) >= 5
        return Decoded(image: image, width: rotated ? height : width, height: rotated ? width : height)
    }
}
