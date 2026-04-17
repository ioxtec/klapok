//
//  AnnotationModels.swift
//  Fluttro
//
//  Models for drawing annotations on screenshots
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Unified Drawable Protocol

protocol DrawableAnnotation: Identifiable {
    var id: UUID { get }
    var type: AnnotationType { get }
    var startPoint: CGPoint { get set }
    var endPoint: CGPoint { get set }
    var createdAt: Date { get }
    var modifiedAt: Date { get set }
}

// Conformance: existing `Annotation` already satisfies the requirements
extension Annotation: DrawableAnnotation {}

// MARK: - Annotation Type

enum AnnotationType: String, Codable, CaseIterable {
    case text = "Text"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case line = "Line"
    case highlight = "Highlight" // Semi-transparent rectangle for highlighting text
    case freeDraw = "Free Draw" // Free hand drawing
    
    var icon: String {
        switch self {
        case .text: return "textformat"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .highlight: return "highlighter"
        case .freeDraw: return "pencil.tip"
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Resize Handle

enum ResizeHandle: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case top
    case bottom
    case left
    case right
}

// MARK: - Annotation Model

struct Annotation: Identifiable, Codable, Equatable {
    let id: UUID
    var type: AnnotationType
    var startPoint: CGPoint
    var endPoint: CGPoint
    
    // Text properties
    var text: String?
    var fontSize: CGFloat
    var fontWeight: FontWeight
    
    // Style properties
    var color: ColorData
    var strokeWidth: CGFloat
    var fillOpacity: Double // For rectangles and highlights
    
    // Arrow properties
    var arrowheadSize: CGFloat
    
    // Free draw properties
    var pathPoints: [CGPoint] // For free drawing
    
    var createdAt: Date
    var modifiedAt: Date
    
    init(
        id: UUID = UUID(),
        type: AnnotationType,
        startPoint: CGPoint,
        endPoint: CGPoint,
        text: String? = nil,
        fontSize: CGFloat = 16,
        fontWeight: FontWeight = .regular,
        color: ColorData = ColorData(color: .white),
        strokeWidth: CGFloat = 2,
        fillOpacity: Double = 0.3,
        arrowheadSize: CGFloat = 12,
        pathPoints: [CGPoint] = []
    ) {
        self.id = id
        self.type = type
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.color = color
        self.strokeWidth = strokeWidth
        self.fillOpacity = fillOpacity
        self.arrowheadSize = arrowheadSize
        self.pathPoints = pathPoints
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // Convenience computed properties
    var bounds: CGRect {
        if type == .circle {
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            let diameter = max(width, height)
            let centerX = (startPoint.x + endPoint.x) / 2
            let centerY = (startPoint.y + endPoint.y) / 2
            return CGRect(
                x: centerX - diameter / 2,
                y: centerY - diameter / 2,
                width: diameter,
                height: diameter
            )
        } else if type == .freeDraw && !pathPoints.isEmpty {
            // Calculate bounds from path points
            let minX = pathPoints.map { $0.x }.min() ?? startPoint.x
            let maxX = pathPoints.map { $0.x }.max() ?? endPoint.x
            let minY = pathPoints.map { $0.y }.min() ?? startPoint.y
            let maxY = pathPoints.map { $0.y }.max() ?? endPoint.y
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        } else {
            let minX = min(startPoint.x, endPoint.x)
            let minY = min(startPoint.y, endPoint.y)
            let maxX = max(startPoint.x, endPoint.x)
            let maxY = max(startPoint.y, endPoint.y)
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
    
    var center: CGPoint {
        return CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }
    
    func contains(_ point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        switch type {
        case .line, .arrow:
            // For lines and arrows, check distance to line segment
            let distance = distanceToLineSegment(point: point, start: startPoint, end: endPoint)
            return distance <= tolerance
        case .freeDraw:
            // For free draw, check if point is near any path point
            if pathPoints.isEmpty {
                return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
            }
            for pathPoint in pathPoints {
                let distance = sqrt(pow(point.x - pathPoint.x, 2) + pow(point.y - pathPoint.y, 2))
                if distance <= tolerance {
                    return true
                }
            }
            return false
        default:
            // For other types (rectangles, circles, text, highlight), use bounds
            let expandedBounds = bounds.insetBy(dx: -tolerance, dy: -tolerance)
            return expandedBounds.contains(point)
        }
    }
    
    private func distanceToLineSegment(point: CGPoint, start: CGPoint, end: CGPoint) -> CGFloat {
        let A = point.x - start.x
        let B = point.y - start.y
        let C = end.x - start.x
        let D = end.y - start.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        var param: CGFloat = -1
        
        if lenSq != 0 {
            param = dot / lenSq
        }
        
        var xx: CGFloat, yy: CGFloat
        
        if param < 0 {
            xx = start.x
            yy = start.y
        } else if param > 1 {
            xx = end.x
            yy = end.y
        } else {
            xx = start.x + param * C
            yy = start.y + param * D
        }
        
        let dx = point.x - xx
        let dy = point.y - yy
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Font Weight

enum FontWeight: String, Codable, CaseIterable {
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
    
    var nsWeight: NSFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

// MARK: - Drawing Tool State

enum DrawingTool: Equatable {
    case none
    case select
    case text
    case arrow
    case rectangle
    case circle
    case line
    case highlight
    case freeDraw
    
    var annotationType: AnnotationType? {
        switch self {
        case .text: return .text
        case .arrow: return .arrow
        case .rectangle: return .rectangle
        case .circle: return .circle
        case .line: return .line
        case .highlight: return .highlight
        case .freeDraw: return .freeDraw
        default: return nil
        }
    }
    
    var icon: String {
        switch self {
        case .none: return ""
        case .select: return "cursor.rays"
        case .text: return "textformat"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .highlight: return "highlighter"
        case .freeDraw: return "pencil.tip"
        }
    }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .select: return "Select"
        case .text: return "Text"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .line: return "Line"
        case .highlight: return "Highlight"
        case .freeDraw: return "Free Draw"
        }
    }
}

#endif
