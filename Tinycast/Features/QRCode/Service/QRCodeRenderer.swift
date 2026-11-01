import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

enum QRCodeRenderer {
    @concurrent static func png(for content: String) async throws -> Data {
        try Task.checkCancellation()
        try QRCodeHistory.validate(content)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let code = filter.outputImage else { throw QRCodeHistory.Failure.rendering }
        let quietZone = 4
        let scale = 8
        let side = (Int(code.extent.width) + quietZone * 2) * scale
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let image = context.createCGImage(code, from: code.extent),
            let canvas = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw QRCodeHistory.Failure.rendering }
        canvas.setFillColor(CGColor(gray: 1, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: side, height: side))
        canvas.interpolationQuality = .none
        canvas.draw(image, in: CGRect(
            x: quietZone * scale, y: quietZone * scale,
            width: side - quietZone * scale * 2, height: side - quietZone * scale * 2))
        let data = NSMutableData()
        guard let output = canvas.makeImage(),
            let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw QRCodeHistory.Failure.rendering }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else { throw QRCodeHistory.Failure.rendering }
        try Task.checkCancellation()
        return data as Data
    }
}
