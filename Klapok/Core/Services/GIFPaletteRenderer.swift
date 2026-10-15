import CoreGraphics
import Foundation

enum GIFPaletteRenderer {
    static func render(_ image: CGImage, colors: GIFColorDepth, dithering: GIFDithering) throws -> CGImage {
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space, bitmapInfo: info) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw VideoExportService.ExportError.gifFrameGenerationFailed }
        let levels: [Int]
        switch colors {
        case .colors16: levels = [2, 4, 2]
        case .colors32: levels = [4, 4, 2]
        case .colors64: levels = [4, 4, 4]
        case .colors128: levels = [4, 8, 4]
        case .colors256: levels = [8, 8, 4]
        }
        let bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
        var current = [Double](repeating: 0, count: (width + 2) * 3)
        var next = current
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                for channel in 0..<3 {
                    let step = 255.0 / Double(levels[channel] - 1)
                    let errorIndex = (x + 1) * 3 + channel
                    var value = Double(pixels[offset + channel])
                    if dithering == .floydSteinberg { value += current[errorIndex] }
                    if dithering == .bayer { value += (Double(bayer[(y % 4) * 4 + x % 4]) / 16 - 0.5) * step }
                    let clamped = min(255, max(0, value))
                    let quantized = (clamped / step).rounded() * step
                    pixels[offset + channel] = UInt8(quantized.rounded())
                    if dithering == .floydSteinberg {
                        let error = clamped - quantized
                        current[errorIndex + 3] += error * 7 / 16
                        next[errorIndex - 3] += error * 3 / 16
                        next[errorIndex] += error * 5 / 16
                        next[errorIndex + 3] += error / 16
                    }
                }
                pixels[offset + 3] = 255
            }
            swap(&current, &next)
            next = [Double](repeating: 0, count: next.count)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(width: width, height: height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: space,
                bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw VideoExportService.ExportError.gifFrameGenerationFailed
        }
        return output
    }
}
