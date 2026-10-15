import XCTest
import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import Klapok

@MainActor
final class ReleaseImageExportTests: XCTestCase {
    private func image(width: Int = 1000, height: Int = 500) throws -> NSImage {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width,
            pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for y in 0..<height { for x in 0..<width {
            let offset = y * bitmap.bytesPerRow + x * 4
            let value: UInt8 = (x + y).isMultiple(of: 2) ? 0 : 255
            let bytes = try XCTUnwrap(bitmap.bitmapData)
            bytes[offset] = value; bytes[offset + 1] = value
            bytes[offset + 2] = value; bytes[offset + 3] = 255
        } }
        let result = NSImage(size: NSSize(width: width, height: height))
        result.addRepresentation(bitmap)
        return result
    }

    private func render(_ source: NSImage, manager: BackgroundManager, annotations: [Annotation] = [],
                        ratio: BackgroundAspectRatio = .auto, padding: CGFloat = 30,
                        shadow: CGFloat = 0, radius: CGFloat = 0) -> NSImage {
        ImageCompositeRenderer.render(image: source, backgroundManager: manager,
            annotations: annotations, padding: padding, aspectRatio: ratio,
            shadowIntensity: shadow, cornerRadius: radius)
    }

    func testUnchangedPNGPreservesNativePixelsIncludingRetinaPointSize() throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let source = try image()
        source.size = NSSize(width: 500, height: 250)
        let manager = BackgroundManager(forPreview: true)
        manager.collections.backgroundType = .none
        let output = render(source, manager: manager)
        XCTAssertTrue(output === source, "No rendering or resampling is needed for an unchanged image.")
        let url = folder.appendingPathComponent("native.png")
        XCTAssertTrue(CaptureFileStore.writeScreenshot(output, to: url))
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        XCTAssertEqual(decoded.pixelsWide, 1000)
        XCTAssertEqual(decoded.pixelsHigh, 500)
        let original = try XCTUnwrap(source.representations.first as? NSBitmapImageRep)
        for y in 0..<500 { for x in 0..<1000 {
            XCTAssertEqual(decoded.colorAt(x: x, y: y)?.redComponent,
                           original.colorAt(x: x, y: y)?.redComponent)
        } }
    }

    func testBackgroundRatiosMatchActualExportPixels() throws {
        let source = try image(width: 320, height: 180)
        let manager = BackgroundManager(forPreview: true)
        for ratio in BackgroundAspectRatio.allCases {
            for padding: CGFloat in [0, 30, 100] {
                let result = render(source, manager: manager, ratio: ratio, padding: padding, shadow: 25, radius: 12)
                XCTAssertEqual(result.pixelSize, ImageCompositeRenderer.calculateOutputSize(for: source,
                    backgroundManager: manager, padding: padding, aspectRatio: ratio))
                if ratio != .auto {
                    XCTAssertEqual(result.pixelSize.width / result.pixelSize.height, ratio.ratio,
                        accuracy: 0.005, "\(ratio), padding \(padding)")
                }
            }
        }
    }

    func testAllAnnotationKindsChangeExportWithoutScaling() throws {
        let source = try image(width: 200, height: 100)
        let manager = BackgroundManager(forPreview: true)
        manager.collections.backgroundType = .none
        for type in AnnotationType.allCases {
            let annotation = Annotation(type: type, startPoint: CGPoint(x: 20, y: 20),
                endPoint: CGPoint(x: 160, y: 70), text: "Export", color: ColorData(color: .red),
                strokeWidth: 5, pathPoints: [CGPoint(x: 20, y: 20), CGPoint(x: 160, y: 70)])
            let rendered = render(source, manager: manager, annotations: [annotation])
            XCTAssertEqual(rendered.pixelSize, source.pixelSize, "\(type)")
            XCTAssertNotEqual(rendered.tiffRepresentation, source.tiffRepresentation, "\(type)")
        }
    }

    func testRoundedCornersProduceTransparentCornerPixels() throws {
        let source = try image(width: 200, height: 100)
        let manager = BackgroundManager(forPreview: true)
        manager.collections.backgroundType = .none
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(render(source, manager: manager, radius: 20).tiffRepresentation)))
        XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
        XCTAssertEqual(bitmap.pixelsWide, 200)
        XCTAssertEqual(bitmap.pixelsHigh, 100)
    }

    func testImportedImageKeepsNativePixelsAndOriginalFile() throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let source = try image()
        source.size = NSSize(width: 500, height: 250)
        let url = folder.appendingPathComponent("source.png")
        XCTAssertTrue(CaptureFileStore.writeScreenshot(source, to: url))
        let before = try Data(contentsOf: url)
        let loaded = try MediaImportService.loadImage(from: url)
        XCTAssertEqual(loaded.pixelSize, CGSize(width: 1000, height: 500))
        XCTAssertEqual(loaded.size, loaded.pixelSize)
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testInvalidImageIsRejected() throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let url = folder.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: url)
        XCTAssertThrowsError(try MediaImportService.loadImage(from: url))
    }

    func testSaveAsJPEGProducesJPEGData() throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let url = folder.appendingPathComponent("export.jpg")
        XCTAssertTrue(CaptureFileStore.writeScreenshot(try image(width: 100, height: 50), to: url))
        let decoded = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetType(decoded) as String?, UTType.jpeg.identifier)
    }

    func testDecorativeCanvasKeepsEveryScreenshotPixelAtOneToOne() throws {
        let source = try image(width: 1001, height: 501)
        let manager = BackgroundManager(forPreview: true)
        for ratio in BackgroundAspectRatio.allCases {
            let rendered = render(source, manager: manager, ratio: ratio)
            let bitmap = try XCTUnwrap(CaptureFileStore.nativeBitmap(from: rendered))
            let xOffset = Int(floor((rendered.pixelSize.width - source.pixelSize.width) / 2))
            let yOffset = Int(ceil((rendered.pixelSize.height - source.pixelSize.height) / 2))
            var maximumError: CGFloat = 0
            for y in 0..<501 {
                for x in stride(from: 0, to: 1001, by: 17) {
                    let expected: CGFloat = (x + y).isMultiple(of: 2) ? 0 : 1
                    let actual = try XCTUnwrap(bitmap.colorAt(x: x + xOffset, y: y + yOffset)).redComponent
                    maximumError = max(maximumError, abs(actual - expected))
                }
            }
            XCTAssertLessThan(maximumError, 0.001, "\(ratio): no interpolated pixels allowed")
        }
    }

    func testCanvasCornersAreIncludedInRenderedOutput() throws {
        let manager = BackgroundManager(forPreview: true)
        let result = ImageCompositeRenderer.render(image: try image(width: 100, height: 50),
            backgroundManager: manager, annotations: [], padding: 30, aspectRatio: .auto,
            shadowIntensity: 0, canvasCornerRadius: 20)
        let bitmap = try XCTUnwrap(CaptureFileStore.nativeBitmap(from: result))
        XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
        XCTAssertEqual(bitmap.colorAt(x: 80, y: 0)?.alphaComponent, 1)
    }

    func testGradientOpacityIsIncludedInExport() throws {
        let manager = BackgroundManager(forPreview: true)
        let color = ColorData(color: Color.red.opacity(0.5))
        let gradient = CustomGradient(name: "Transparent", color1: color, color2: color, opacity: 0.5)
        manager.collections.customGradients = [gradient]
        manager.collections.selectedGradientId = gradient.id
        let result = render(try image(width: 100, height: 50), manager: manager)
        let bitmap = try XCTUnwrap(CaptureFileStore.nativeBitmap(from: result))
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 0, y: 55)).alphaComponent, 0.25, accuracy: 0.01)
    }

    func testGIFPaletteLimitsColorsAndDitheringChangesPixels() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for y in 0..<64 { for x in 0..<64 {
            let bytes = try XCTUnwrap(bitmap.bitmapData)
            let offset = y * bitmap.bytesPerRow + x * 4
            bytes[offset] = UInt8(x * 255 / 63)
            bytes[offset + 1] = UInt8(y * 255 / 63)
            bytes[offset + 2] = UInt8((x + y) * 255 / 126)
            bytes[offset + 3] = 255
        } }
        let source = try XCTUnwrap(bitmap.cgImage)
        for depth in GIFColorDepth.allCases {
            var results = Set<Data>()
            for dithering in GIFDithering.allCases {
                let rendered = try GIFPaletteRenderer.render(source, colors: depth, dithering: dithering)
                let pixels = NSBitmapImageRep(cgImage: rendered)
                var colors = Set<String>()
                for y in 0..<64 { for x in 0..<64 {
                    let color = try XCTUnwrap(pixels.colorAt(x: x, y: y))
                    colors.insert("\(color.redComponent),\(color.greenComponent),\(color.blueComponent)")
                } }
                XCTAssertLessThanOrEqual(colors.count, depth.colorCount)
                results.insert(try XCTUnwrap(pixels.representation(using: .png, properties: [:])))
            }
            XCTAssertEqual(results.count, 3, "\(depth): each dithering option should have a distinct effect")
        }
    }
}
