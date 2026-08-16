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

        let exportSize = calculateExportSize(for: sourceSize, aspectRatio: aspectRatio)
        let backgroundSize = calculateBackgroundSize(
            for: sourceSize,
            in: exportSize,
            padding: padding,
            aspectRatio: aspectRatio
        )
        return roundedPixelSize(backgroundSize)
    }

    static func render(
        image originalImage: NSImage,
        backgroundManager: BackgroundManager,
        annotations: [Annotation],
        padding: CGFloat,
        aspectRatio: BackgroundAspectRatio,
        shadowIntensity: CGFloat
    ) -> NSImage {
        let imageSize = originalImage.pixelSize

        guard backgroundManager.collections.backgroundType != .none else {
            return originalImage
        }

        let exportSize = calculateExportSize(for: imageSize, aspectRatio: aspectRatio)
        let backgroundSize = calculateBackgroundSize(
            for: imageSize,
            in: exportSize,
            padding: padding,
            aspectRatio: aspectRatio
        )

        let maxImageWidth = backgroundSize.width - (padding * 2)
        let maxImageHeight = backgroundSize.height - (padding * 2)
        let scaleX = imageSize.width > maxImageWidth ? maxImageWidth / imageSize.width : 1.0
        let scaleY = imageSize.height > maxImageHeight ? maxImageHeight / imageSize.height : 1.0
        let scale = min(scaleX, scaleY)
        let finalImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let compositeImage = NSImage(size: backgroundSize)

        compositeImage.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            drawBackground(
                in: context,
                size: backgroundSize,
                backgroundManager: backgroundManager
            )
        }

        let imageRect = NSRect(
            x: (backgroundSize.width - finalImageSize.width) / 2,
            y: (backgroundSize.height - finalImageSize.height) / 2,
            width: finalImageSize.width,
            height: finalImageSize.height
        )

        drawShadow(intensity: shadowIntensity)
        originalImage.draw(
            in: imageRect,
            from: NSRect(origin: .zero, size: originalImage.size),
            operation: .sourceOver,
            fraction: 1.0
        )

        if !annotations.isEmpty {
            drawAnnotations(annotations, in: imageRect, imageSize: imageSize)
        }

        compositeImage.unlockFocus()
        return compositeImage
    }

    private static func calculateExportSize(
        for imageSize: CGSize,
        aspectRatio: BackgroundAspectRatio
    ) -> CGSize {
        let baseSize: CGFloat = 1200

        switch aspectRatio {
        case .auto:
            let imageRatio = imageSize.width / imageSize.height
            if imageRatio > 1.0 {
                return CGSize(width: baseSize, height: baseSize / imageRatio)
            }

            return CGSize(width: baseSize * imageRatio, height: baseSize)

        case .ratio16_9:
            return CGSize(width: baseSize, height: baseSize * 9 / 16)

        case .ratio4_3:
            return CGSize(width: baseSize, height: baseSize * 3 / 4)

        case .ratio3_2:
            return CGSize(width: baseSize, height: baseSize * 2 / 3)

        case .ratio1_1:
            return CGSize(width: baseSize, height: baseSize)
        }
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
            $0.color.toNSColor().withAlphaComponent(selectedGradient.opacity).cgColor
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
        in context: CGContext,
        size: CGSize
    ) {
        guard let selectedImage,
              let backgroundImage = selectedImage.image
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

    private static func drawAnnotations(
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
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength = annotation.arrowheadSize
        let arrowAngle: CGFloat = .pi / 6
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: point1)
        context.move(to: end)
        context.addLine(to: point2)
        context.strokePath()
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
            let patternRect = CGRect(origin: .zero, size: imageSize)
            image.draw(in: targetRect, from: patternRect, operation: .sourceOver, fraction: 1.0)

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
