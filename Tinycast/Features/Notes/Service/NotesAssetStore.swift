import Foundation
import ImageIO
import UniformTypeIdentifiers

struct NotesAssetStore: Sendable {
    enum Input: Sendable {
        case file(URL)
        case bitmap(Data)
    }

    let notesDirectory: URL
    private static let extensions = ["png", "jpg", "jpeg", "webp", "gif", "heic"]

    static func isImportedName(_ name: String) -> Bool {
        name.wholeMatch(of: /\d{8}-\d{6}-[0-9a-f]{4}(-\d+)?\.[a-z]+/) != nil
    }

    func validatedAssetURL(_ path: String) throws -> URL {
        let parts = path.components(separatedBy: "/")
        guard parts.count >= 2, parts.first == "assets",
            parts.allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") && !$0.contains("\0") }),
            Self.extensions.contains((path as NSString).pathExtension.lowercased())
        else { throw CocoaError(.fileReadInvalidFileName) }
        var url = notesDirectory.standardizedFileURL.resolvingSymlinksInPath()
        for part in parts {
            url.appendPathComponent(part)
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isHiddenKey])
            guard values?.isSymbolicLink != true, values?.isHidden != true,
                url.resolvingSymlinksInPath().path == url.path
            else { throw CocoaError(.fileReadNoPermission) }
        }
        return url
    }

    @concurrent
    func importImage(_ input: Input) async throws -> String {
        let data: Data
        let ext: String
        switch input {
        case .file(let file):
            ext = file.pathExtension.lowercased()
            guard file.isFileURL, Self.extensions.contains(ext) else {
                throw CocoaError(.fileReadUnsupportedScheme)
            }
            data = try Data(contentsOf: file)
        case .bitmap(let bytes):
            guard let image = CGImageSourceCreateWithData(bytes as CFData, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(image, 0, nil)
            else { throw CocoaError(.fileReadCorruptFile) }
            let png = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(
                    png, UTType.png.identifier as CFString, 1, nil)
            else { throw CocoaError(.fileWriteUnknown) }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
            data = png as Data
            ext = "png"
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source), UTType(type as String)?.conforms(to: .image) == true,
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil
        else { throw CocoaError(.fileReadCorruptFile) }
        let directory = try validatedAssetURL("assets/image.png").deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try NoteFileAccess.coordinatedWrite(at: directory, options: .forMerging) { _ in
            if let existing = try duplicate(of: data, ext: ext, in: directory) { return existing }
            return try write(data, ext: ext)
        }
    }

    private func duplicate(of data: Data, ext: String, in directory: URL) throws -> String? {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        for url in contents where url.pathExtension.lowercased() == ext && Self.isImportedName(url.lastPathComponent) {
            try Task.checkCancellation()
            let path = "assets/" + url.lastPathComponent
            guard let asset = try? validatedAssetURL(path),
                let values = try? asset.resourceValues(forKeys: keys),
                values.isRegularFile == true, values.fileSize == data.count,
                let bytes = try? Data(contentsOf: asset, options: .mappedIfSafe), bytes == data
            else { continue }
            return path
        }
        return nil
    }

    private func write(_ data: Data, ext: String) throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stem = formatter.string(from: Date()) + "-" + UUID().uuidString.prefix(4).lowercased()
        var suffix = 0
        while true {
            try Task.checkCancellation()
            let name = suffix == 0 ? stem : "\(stem)-\(suffix)"
            let path = "assets/\(name).\(ext)"
            let url = try validatedAssetURL(path)
            do {
                try NoteFileAccess.writeNewFileAtomically(data, to: url)
                return path
            } catch CocoaError.fileWriteFileExists { suffix += 1 }
        }
    }

}
