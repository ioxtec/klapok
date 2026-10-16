//
//  ImageCompositeRenderer.swift
//  Klapok
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit

enum ImageCompositeRenderer {
    static func calculateBackgroundSize(
        for imageSize: CGSize,
        in availableSize: CGSize,
        padding: CGFloat,
        aspectRatio: BackgroundAspectRatio
    ) -> CGSize {
        let availableWidth = availableSize.width - (padding * 2)
        let availableHeight = availableSize.height - (padding * 2)

        switch aspectRatio {
        case .auto:
            return CGSize(width: availableWidth, height: availableHeight)

        default:
            let ratio = aspectRatio.ratio
            let width = availableWidth
            let height = width / ratio

            if height > availableHeight {
                return CGSize(width: availableHeight * ratio, height: availableHeight)
            }

            return CGSize(width: width, height: height)
        }
    }

    static func calculateOutputSize(
        for image: NSImage,
        backgroundManager: BackgroundManager,
        padding: CGFloat,
        aspectRatio: BackgroundAspectRatio
    ) -> CGSize {
        let sourceSize = image.pixelSize

        guard backgroundManager.collections.backgroundType != .none else {
            return roundedPixelSize(sourceSize)
        }

        return calculateExportSize(for: sourceSize, padding: padding, aspectRatio: aspectRatio)
    }

    static func render(
        image originalImage: NSImage,
        backgroundManager: BackgroundManager,
        annotations: [Annotation],
        padding: CGFloat,
        aspectRatio: BackgroundAspectRatio,
        shadowIntensity: CGFloat,
        cornerRadius: CGFloat = 0,
        canvasCornerRadius: CGFloat = 0
    ) -> NSImage {
        let imageSize = originalImage.pixelSize

        guard backgroundManager.collections.backgroundType != .none else {
            guard !annotations.isEmpty || cornerRadius > 0 else { return originalImage }
            guard let bitmap = bitmap(for: imageSize), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return originalImage }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            NSBezierPath(roundedRect: NSRect(origin: .zero, size: imageSize), xRadius: cornerRadius, yRadius: cornerRadius).addClip()
            drawNativeImage(originalImage, in: NSRect(origin: .zero, size: imageSize))
            drawAnnotations(annotations, in: NSRect(origin: .zero, size: imageSize), imageSize: imageSize)
            NSGraphicsContext.restoreGraphicsState()
            let rendered = NSImage(size: imageSize)
            rendered.addRepresentation(bitmap)
            return rendered
        }

        let backgroundSize = calculateExportSize(for: imageSize, padding: padding, aspectRatio: aspectRatio)
        let scale: CGFloat = 1
        let finalImageSize = imageSize
        guard let bitmap = bitmap(for: backgroundSize), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return originalImage }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        if canvasCornerRadius > 0 {
            NSBezierPath(roundedRect: NSRect(origin: .zero, size: backgroundSize),
                xRadius: canvasCornerRadius, yRadius: canvasCornerRadius).addClip()
        }

        if let context = NSGraphicsContext.current?.cgContext {
            drawBackground(
                in: context,
                size: backgroundSize,
                backgroundManager: backgroundManager
            )
        }

        let imageRect = NSRect(
            x: floor((backgroundSize.width - finalImageSize.width) / 2),
            y: floor((backgroundSize.height - finalImageSize.height) / 2),
            width: finalImageSize.width,
            height: finalImageSize.height
        )

        drawShadow(intensity: shadowIntensity)
        NSGraphicsContext.saveGraphicsState()
        if cornerRadius > 0 {
            NSBezierPath(roundedRect: imageRect, xRadius: cornerRadius * scale, yRadius: cornerRadius * scale).addClip()
        }
        drawNativeImage(originalImage, in: imageRect)

        if !annotations.isEmpty {
            drawAnnotations(annotations, in: imageRect, imageSize: imageSize)
        }

        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.restoreGraphicsState()
        let compositeImage = NSImage(size: backgroundSize)
        compositeImage.addRepresentation(bitmap)
        return compositeImage
    }

    private static func bitmap(for size: CGSize) -> NSBitmapImageRep? {
        NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: max(1, Int(size.width.rounded())),
            pixelsHigh: max(1, Int(size.height.rounded())), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    }

    private static func drawNativeImage(_ image: NSImage, in rect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let source = CaptureFileStore.nativeBitmap(from: image)?.cgImage else {
            image.draw(in: rect)
            return
        }
        context.saveGState()
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.draw(source, in: rect)
        context.restoreGState()
    }

    private static func calculateExportSize(
        for imageSize: CGSize,
        padding: CGFloat,
        aspectRatio: BackgroundAspectRatio
    ) -> CGSize {
        let padded = CGSize(width: imageSize.width + 2 * max(0, padding),
                            height: imageSize.height + 2 * max(0, padding))
        let units: CGSize
        switch aspectRatio {
        case .auto:
            return roundedPixelSize(padded)
        case .ratio16_9:
            units = CGSize(width: 16, height: 9)
        case .ratio4_3:
            units = CGSize(width: 4, height: 3)
        case .ratio3_2:
            units = CGSize(width: 3, height: 2)
        case .ratio1_1:
            units = CGSize(width: 1, height: 1)
        }
        let multiplier = ceil(max(padded.width / units.width, padded.height / units.height))
        return CGSize(width: units.width * multiplier, height: units.height * multiplier)
    }

    private static func roundedPixelSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: max(1, size.width.rounded()),
            height: max(1, size.height.rounded())
        )
    }

    private static func drawBackground(
        in context: CGContext,
        size: CGSize,
        backgroundManager: BackgroundManager
    ) {
        switch backgroundManager.collections.backgroundType {
        case .gradient:
            drawGradientBackground(
                backgroundManager.collections.selectedGradient,
                in: context,
                size: size
            )

        case .image:
            drawImageBackground(
                backgroundManager.collections.selectedImage,
                backgroundManager: backgroundManager,
                in: context,
                size: size
            )

        case .none:
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0))
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func drawGradientBackground(
        _ selectedGradient: CustomGradient?,
        in context: CGContext,
        size: CGSize
    ) {
        guard let selectedGradient else {
            drawFallbackBackground(in: context, size: size)
            return
        }

        let gradientColors = selectedGradient.sortedStops.map {
            $0.color.toNSColor().withAlphaComponent(selectedGradient.opacity * $0.color.alpha).cgColor
        }
        let locations = selectedGradient.sortedStops.map { CGFloat($0.location) }
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors as CFArray,
            locations: locations
        )

        guard let gradient else {
            drawFallbackBackground(in: context, size: size)
            return
        }

        let points = selectedGradient.direction.cgPoints(in: size)
        context.drawLinearGradient(
            gradient,
            start: points.start,
            end: points.end,
            options: []
        )
    }

    private static func drawImageBackground(
        _ selectedImage: BackgroundImage?,
        backgroundManager: BackgroundManager,
        in context: CGContext,
        size: CGSize
    ) {
        guard let selectedImage,
              let backgroundImage = backgroundManager.renderedImage(for: selectedImage)
        else {
            drawFallbackBackground(in: context, size: size)
            return
        }

        drawBackgroundImage(
            backgroundImage,
            in: context,
            size: size,
            scaleMode: selectedImage.scaleMode,
            opacity: selectedImage.opacity
        )
    }

    private static func drawFallbackBackground(in context: CGContext, size: CGSize) {
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))
    }

    private static func drawShadow(intensity: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 0, height: -intensity / 2)
        shadow.shadowBlurRadius = intensity
        shadow.shadowColor = NSColor.black.withAlphaComponent(intensity / 100.0)
        shadow.set()
    }

    static func drawAnnotations(
        _ annotations: [Annotation],
        in imageRect: NSRect,
        imageSize: CGSize
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height

        for annotation in annotations {
            let transformedStart = CGPoint(
                x: imageRect.minX + annotation.startPoint.x * scaleX,
                y: imageRect.minY + (imageSize.height - annotation.startPoint.y) * scaleY
            )
            let transformedEnd = CGPoint(
                x: imageRect.minX + annotation.endPoint.x * scaleX,
                y: imageRect.minY + (imageSize.height - annotation.endPoint.y) * scaleY
            )
            let color = annotation.color.toNSColor()

            switch annotation.type {
            case .text:
                drawTextAnnotation(annotation, atTopLeft: transformedStart, scale: scaleX)

            case .arrow:
                drawArrowAnnotation(annotation, from: transformedStart, to: transformedEnd, color: color, context: context)

            case .rectangle:
                drawRectangleAnnotation(annotation, from: transformedStart, to: transformedEnd, color: color, context: context)

            case .circle:
                drawCircleAnnotation(annotation, from: transformedStart, to: transformedEnd, color: color, context: context)

            case .line:
                drawLineAnnotation(annotation, from: transformedStart, to: transformedEnd, color: color, context: context)

            case .highlight:
                drawHighlightAnnotation(annotation, from: transformedStart, to: transformedEnd, color: color, context: context)

            case .freeDraw:
                drawFreeDrawAnnotation(annotation, color: color, context: context, scale: scaleX, imageRect: imageRect)
            }
        }
    }

    private static func drawTextAnnotation(_ annotation: Annotation, atTopLeft point: CGPoint, scale: CGFloat) {
        guard let text = annotation.text else { return }

        let font = NSFont.systemFont(ofSize: annotation.fontSize * scale, weight: annotation.fontWeight.nsWeight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: annotation.color.toNSColor()
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let baselinePoint = CGPoint(x: point.x, y: point.y - font.ascender)
        attributedString.draw(at: baselinePoint)
    }

    private static func drawArrowAnnotation(
        _ annotation: Annotation,
        from start: CGPoint,
        to end: CGPoint,
        color: NSColor,
        context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let geometry = ArrowGeometry(start: start, end: end, style: annotation.arrowStyle ?? .open,
            headSize: annotation.arrowheadSize, strokeWidth: annotation.strokeWidth)
        context.addPath(geometry.stroke)
        context.strokePath()
        context.setFillColor(color.cgColor)
        context.addPath(geometry.fill)
        context.fillPath()
        context.restoreGState()
    }

    private static func drawRectangleAnnotation(
        _ annotation: Annotation,
        from start: CGPoint,
        to end: CGPoint,
        color: NSColor,
        context: CGContext
    ) {
        context.saveGState()
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        if annotation.fillOpacity > 0 {
            context.setFillColor(color.withAlphaComponent(annotation.fillOpacity).cgColor)
            context.fill(rect)
        }

        if annotation.strokeWidth > 0 {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(annotation.strokeWidth)
            context.stroke(rect)
        }

        context.restoreGState()
    }

    private static func drawCircleAnnotation(
        _ annotation: Annotation,
        from start: CGPoint,
        to end: CGPoint,
        color: NSColor,
        context: CGContext
    ) {
        context.saveGState()
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        let diameter = max(width, height)
        let centerX = (start.x + end.x) / 2
        let centerY = (start.y + end.y) / 2
        let rect = CGRect(
            x: centerX - diameter / 2,
            y: centerY - diameter / 2,
            width: diameter,
            height: diameter
        )

        if annotation.fillOpacity > 0 {
            context.setFillColor(color.withAlphaComponent(annotation.fillOpacity).cgColor)
            context.fillEllipse(in: rect)
        }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.strokeEllipse(in: rect)
        context.restoreGState()
    }

    private static func drawLineAnnotation(
        _ annotation: Annotation,
        from start: CGPoint,
        to end: CGPoint,
        color: NSColor,
        context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawHighlightAnnotation(
        _ annotation: Annotation,
        from start: CGPoint,
        to end: CGPoint,
        color: NSColor,
        context: CGContext
    ) {
        context.saveGState()
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        context.setFillColor(color.withAlphaComponent(annotation.fillOpacity).cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    private static func drawFreeDrawAnnotation(
        _ annotation: Annotation,
        color: NSColor,
        context: CGContext,
        scale: CGFloat,
        imageRect: NSRect
    ) {
        guard annotation.pathPoints.count > 1 else { return }

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let firstPoint = annotation.pathPoints[0]
        let transformedFirst = CGPoint(
            x: imageRect.minX + firstPoint.x * scale,
            y: imageRect.minY + (imageRect.height - firstPoint.y * scale)
        )
        context.move(to: transformedFirst)

        for point in annotation.pathPoints.dropFirst() {
            let transformedPoint = CGPoint(
                x: imageRect.minX + point.x * scale,
                y: imageRect.minY + (imageRect.height - point.y * scale)
            )
            context.addLine(to: transformedPoint)
        }

        context.strokePath()
        context.restoreGState()
    }

    private static func drawBackgroundImage(
        _ image: NSImage,
        in context: CGContext,
        size: CGSize,
        scaleMode: BackgroundScaleMode,
        opacity: Double
    ) {
        let imageSize = image.size
        let targetRect = CGRect(origin: .zero, size: size)

        context.setAlpha(opacity)

        switch scaleMode {
        case .fit:
            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let rect = CGRect(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            image.draw(in: rect)

        case .fill:
            let scale = max(size.width / imageSize.width, size.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let rect = CGRect(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            image.draw(in: rect)

        case .stretch:
            image.draw(in: targetRect)

        case .tile:
            guard imageSize.width > 0, imageSize.height > 0 else { break }
            for y in stride(from: CGFloat.zero, to: size.height, by: imageSize.height) {
                for x in stride(from: CGFloat.zero, to: size.width, by: imageSize.width) {
                    image.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: imageSize))
                }
            }

        case .center:
            let rect = CGRect(
                x: (size.width - imageSize.width) / 2,
                y: (size.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            image.draw(in: rect)
        }

        context.setAlpha(1.0)
    }
}

#endif
