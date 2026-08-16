//
//  AnnotationManagerTests.swift
//  KlapokTests
//
//  Unit tests for AnnotationManager
//

import XCTest
@testable import Klapok

#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class AnnotationManagerTests: XCTestCase {
    
    var annotationManager: AnnotationManager!
    
    override func setUp() {
        super.setUp()
        annotationManager = AnnotationManager()
    }
    
    override func tearDown() {
        annotationManager = nil
        super.tearDown()
    }
    
    // MARK: - Tool Selection Tests
    
    func testSelectTool() {
        annotationManager.selectTool(.arrow)
        XCTAssertEqual(annotationManager.currentTool, .arrow)
    }
    
    func testSelectToolDeselectsAnnotation() {
        // Create and select an annotation
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id
        
        // Select a different tool
        annotationManager.selectTool(.arrow)
        
        // Annotation should be deselected
        XCTAssertNil(annotationManager.selectedAnnotationId)
    }
    
    func testSelectToolDoesNotDeselectWhenSelectTool() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id
        
        // Select select tool
        annotationManager.selectTool(.select)
        
        // Annotation should remain selected
        XCTAssertEqual(annotationManager.selectedAnnotationId, annotation.id)
    }
    
    // MARK: - Annotation Management Tests
    
    func testAddAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        let initialCount = annotationManager.annotations.count
        annotationManager.addAnnotation(annotation)
        
        XCTAssertEqual(annotationManager.annotations.count, initialCount + 1)
        XCTAssertTrue(annotationManager.annotations.contains { $0.id == annotation.id })
    }
    
    func testUpdateAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50),
            color: ColorData(color: .red)
        )
        
        annotationManager.addAnnotation(annotation)
        
        var updatedAnnotation = annotation
        updatedAnnotation.color = ColorData(color: .blue)
        
        annotationManager.updateAnnotation(updatedAnnotation)
        
        let foundAnnotation = annotationManager.annotations.first { $0.id == annotation.id }
        XCTAssertNotNil(foundAnnotation)
        XCTAssertNotEqual(foundAnnotation?.modifiedAt, annotation.modifiedAt)
    }
    
    func testDeleteAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        let initialCount = annotationManager.annotations.count
        
        annotationManager.deleteAnnotation(withId: annotation.id)
        
        XCTAssertEqual(annotationManager.annotations.count, initialCount - 1)
        XCTAssertFalse(annotationManager.annotations.contains { $0.id == annotation.id })
    }
    
    func testDeleteSelectedAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id
        
        annotationManager.deleteSelectedAnnotation()
        
        XCTAssertFalse(annotationManager.annotations.contains { $0.id == annotation.id })
        XCTAssertNil(annotationManager.selectedAnnotationId)
    }
    
    func testClearAllAnnotations() {
        let annotation1 = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        let annotation2 = Annotation(
            type: .arrow,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 60, y: 60)
        )
        
        annotationManager.addAnnotation(annotation1)
        annotationManager.addAnnotation(annotation2)
        annotationManager.selectedAnnotationId = annotation1.id
        
        annotationManager.clearAllAnnotations()
        
        XCTAssertTrue(annotationManager.annotations.isEmpty)
        XCTAssertNil(annotationManager.selectedAnnotationId)
        XCTAssertNil(annotationManager.currentDraft)
    }
    
    // MARK: - Selection Tests
    
    func testSelectAnnotationAtPoint() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        
        // Point inside rectangle
        let point = CGPoint(x: 30, y: 30)
        let selected = annotationManager.selectAnnotation(at: point)
        
        XCTAssertTrue(selected)
        XCTAssertEqual(annotationManager.selectedAnnotationId, annotation.id)
    }
    
    func testSelectAnnotationAtPointOutside() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        
        // Point outside rectangle
        let point = CGPoint(x: 100, y: 100)
        let selected = annotationManager.selectAnnotation(at: point)
        
        XCTAssertFalse(selected)
        XCTAssertNil(annotationManager.selectedAnnotationId)
    }
    
    func testSelectTopMostAnnotation() {
        let annotation1 = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        let annotation2 = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 60, y: 60)
        )
        
        annotationManager.addAnnotation(annotation1)
        annotationManager.addAnnotation(annotation2)
        
        // Point that's in both rectangles
        let point = CGPoint(x: 30, y: 30)
        let selected = annotationManager.selectAnnotation(at: point)
        
        // Should select the top-most (last added)
        XCTAssertTrue(selected)
        XCTAssertEqual(annotationManager.selectedAnnotationId, annotation2.id)
    }
    
    func testDeselectAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id
        
        annotationManager.deselectAnnotation()
        
        XCTAssertNil(annotationManager.selectedAnnotationId)
    }
    
    // MARK: - Drawing Tests
    
    func testStartDrawing() {
        annotationManager.currentTool = .rectangle
        let point = CGPoint(x: 10, y: 10)
        
        annotationManager.startDrawing(at: point)
        
        XCTAssertTrue(annotationManager.isDrawing)
        XCTAssertNotNil(annotationManager.currentDraft)
        XCTAssertEqual(annotationManager.currentDraft?.startPoint, point)
    }
    
    func testStartDrawingWithFreeDraw() {
        annotationManager.currentTool = .freeDraw
        let point = CGPoint(x: 10, y: 10)
        
        annotationManager.startDrawing(at: point)
        
        XCTAssertTrue(annotationManager.isDrawing)
        XCTAssertNotNil(annotationManager.currentDraft)
        XCTAssertEqual(annotationManager.currentDraft?.type, .freeDraw)
        XCTAssertEqual(annotationManager.currentDraft?.pathPoints.count, 1)
    }
    
    func testUpdateDrawing() {
        annotationManager.currentTool = .rectangle
        annotationManager.startDrawing(at: CGPoint(x: 10, y: 10))
        
        let newPoint = CGPoint(x: 50, y: 50)
        annotationManager.updateDrawing(to: newPoint)
        
        XCTAssertEqual(annotationManager.currentDraft?.endPoint, newPoint)
    }
    
    func testUpdateDrawingWithFreeDraw() {
        annotationManager.currentTool = .freeDraw
        annotationManager.startDrawing(at: CGPoint(x: 10, y: 10))
        
        let point1 = CGPoint(x: 20, y: 20)
        let point2 = CGPoint(x: 30, y: 30)
        
        annotationManager.updateDrawing(to: point1)
        annotationManager.updateDrawing(to: point2)
        
        XCTAssertEqual(annotationManager.currentDraft?.pathPoints.count, 3) // Initial + 2 updates
    }
    
    func testFinishDrawing() {
        annotationManager.currentTool = .rectangle
        annotationManager.startDrawing(at: CGPoint(x: 10, y: 10))
        annotationManager.updateDrawing(to: CGPoint(x: 50, y: 50))
        
        let initialCount = annotationManager.annotations.count
        
        // finishDrawing exists in AnnotationManager
        annotationManager.finishDrawing()
        
        XCTAssertFalse(annotationManager.isDrawing)
        XCTAssertNil(annotationManager.currentDraft)
        // Annotation should be added if it has sufficient size
        if abs(50.0 - 10.0) > 5 { // minSize check
            XCTAssertEqual(annotationManager.annotations.count, initialCount + 1)
        }
    }

    func testCancelDrawingClearsDraftWithoutAddingAnnotation() {
        annotationManager.currentTool = .rectangle
        annotationManager.startDrawing(at: CGPoint(x: 10, y: 10))
        annotationManager.updateDrawing(to: CGPoint(x: 80, y: 90))

        annotationManager.cancelDrawing()

        XCTAssertFalse(annotationManager.isDrawing)
        XCTAssertNil(annotationManager.currentDraft)
        XCTAssertTrue(annotationManager.annotations.isEmpty)
    }

    func testSelectAnnotationWithIdIgnoresMissingAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        annotationManager.addAnnotation(annotation)

        annotationManager.selectAnnotation(withId: UUID())

        XCTAssertNil(annotationManager.selectedAnnotationId)

        annotationManager.selectAnnotation(withId: annotation.id)

        XCTAssertEqual(annotationManager.selectedAnnotationId, annotation.id)
    }

    func testMoveSelectedFreeDrawAnnotationMovesAllPathPoints() {
        let annotation = Annotation(
            type: .freeDraw,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 30, y: 30),
            pathPoints: [
                CGPoint(x: 10, y: 10),
                CGPoint(x: 20, y: 25),
                CGPoint(x: 30, y: 30)
            ]
        )
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id

        annotationManager.moveSelectedAnnotation(by: CGSize(width: 5, height: -3))

        let moved = annotationManager.annotations.first { $0.id == annotation.id }
        XCTAssertEqual(moved?.startPoint, CGPoint(x: 15, y: 7))
        XCTAssertEqual(moved?.endPoint, CGPoint(x: 35, y: 27))
        XCTAssertEqual(moved?.pathPoints, [
            CGPoint(x: 15, y: 7),
            CGPoint(x: 25, y: 22),
            CGPoint(x: 35, y: 27)
        ])
    }

    func testResizeSelectedTextAnnotationNormalizesBoundsAndScalesFont() {
        let annotation = Annotation(
            type: .text,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 110, y: 50),
            text: "Hello",
            fontSize: 20
        )
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id

        annotationManager.resizeSelectedAnnotation(
            by: CGSize(width: 20, height: 40),
            handle: .bottomRight
        )

        let resized = annotationManager.annotations.first { $0.id == annotation.id }
        XCTAssertEqual(resized?.startPoint, CGPoint(x: 10, y: 10))
        XCTAssertEqual(resized?.endPoint, CGPoint(x: 130, y: 90))
        XCTAssertEqual(resized?.fontSize ?? 0, 40, accuracy: 0.001)
    }

    func testUpdateSelectedAnnotationProperties() {
        let annotation = Annotation(
            type: .text,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 60, y: 40),
            text: "Old",
            fontSize: 14,
            fontWeight: .regular,
            strokeWidth: 2,
            fillOpacity: 0.1
        )
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id

        annotationManager.updateSelectedAnnotationText("Updated")
        annotationManager.updateSelectedAnnotationColor(.green)
        annotationManager.updateSelectedAnnotationStrokeWidth(7)
        annotationManager.updateSelectedAnnotationFontSize(22)
        annotationManager.updateSelectedAnnotationFontWeight(.bold)
        annotationManager.updateSelectedAnnotationFillOpacity(0.7)

        let updated = annotationManager.annotations.first { $0.id == annotation.id }
        XCTAssertEqual(updated?.text, "Updated")
        XCTAssertEqual(updated?.color, ColorData(color: .green))
        XCTAssertEqual(updated?.strokeWidth, 7)
        XCTAssertEqual(updated?.fontSize, 22)
        XCTAssertEqual(updated?.fontWeight, .bold)
        XCTAssertEqual(updated?.fillOpacity, 0.7)
        XCTAssertGreaterThan(updated?.bounds.width ?? 0, annotation.bounds.width)
    }

    func testUpdateAnnotationSizeAnchorsAtStartPoint() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 30, y: 40)
        )
        annotationManager.addAnnotation(annotation)

        annotationManager.updateAnnotationSize(annotationId: annotation.id, to: CGSize(width: 120, height: 80))

        let updated = annotationManager.annotations.first { $0.id == annotation.id }
        XCTAssertEqual(updated?.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(updated?.endPoint, CGPoint(x: 130, y: 100))
    }

    func testCreateTextAnnotationAddsAndStartsEditing() {
        annotationManager.defaultFontSize = 24
        annotationManager.defaultFontWeight = .bold
        let point = CGPoint(x: 30, y: 40)

        annotationManager.createTextAnnotation(at: point)

        let annotation = annotationManager.annotations.first
        XCTAssertEqual(annotationManager.annotations.count, 1)
        XCTAssertEqual(annotation?.type, .text)
        XCTAssertEqual(annotation?.startPoint, point)
        XCTAssertEqual(annotation?.text, "Text")
        XCTAssertEqual(annotation?.fontSize, 24)
        XCTAssertEqual(annotation?.fontWeight, .bold)
        XCTAssertEqual(annotationManager.selectedAnnotationId, annotation?.id)
        XCTAssertEqual(annotationManager.editingTextAnnotationId, annotation?.id)
        XCTAssertTrue(annotationManager.isEditingText)
        XCTAssertGreaterThanOrEqual(annotation?.bounds.width ?? 0, 112)
        XCTAssertGreaterThanOrEqual(annotation?.bounds.height ?? 0, 36)
    }

    func testStartAndFinishEditingTextUpdatesEditingState() {
        let annotation = Annotation(
            type: .text,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 100, y: 40),
            text: "Text"
        )
        annotationManager.addAnnotation(annotation)

        annotationManager.startEditingText(annotationId: annotation.id)

        XCTAssertEqual(annotationManager.editingTextAnnotationId, annotation.id)
        XCTAssertEqual(annotationManager.selectedAnnotationId, annotation.id)
        XCTAssertTrue(annotationManager.isEditingText)

        annotationManager.finishEditingText()

        XCTAssertNil(annotationManager.editingTextAnnotationId)
        XCTAssertFalse(annotationManager.isEditingText)
    }

    func testExportImportAnnotationsRoundTrips() throws {
        let annotations = [
            Annotation(
                type: .rectangle,
                startPoint: CGPoint(x: 10, y: 10),
                endPoint: CGPoint(x: 50, y: 50)
            ),
            Annotation(
                type: .text,
                startPoint: CGPoint(x: 20, y: 30),
                endPoint: CGPoint(x: 140, y: 70),
                text: "Caption",
                fontSize: 18,
                fontWeight: .medium
            )
        ]
        annotations.forEach { annotationManager.addAnnotation($0) }

        let data = try XCTUnwrap(annotationManager.exportAnnotations())
        let importingManager = AnnotationManager()
        importingManager.importAnnotations(from: data)

        XCTAssertEqual(importingManager.annotations, annotations)
    }

    func testUndoRedoRestoresAnnotationStates() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        annotationManager.addAnnotation(annotation)

        XCTAssertTrue(annotationManager.canUndo)
        XCTAssertFalse(annotationManager.canRedo)

        annotationManager.undo()

        XCTAssertTrue(annotationManager.annotations.isEmpty)
        XCTAssertFalse(annotationManager.canUndo)
        XCTAssertTrue(annotationManager.canRedo)

        annotationManager.redo()

        XCTAssertEqual(annotationManager.annotations, [annotation])
        XCTAssertTrue(annotationManager.canUndo)
        XCTAssertFalse(annotationManager.canRedo)
    }

    func testRedoIsClearedAfterNewMutation() {
        let first = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        let second = Annotation(
            type: .circle,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 80, y: 80)
        )
        annotationManager.addAnnotation(first)
        annotationManager.undo()

        XCTAssertTrue(annotationManager.canRedo)

        annotationManager.addAnnotation(second)

        XCTAssertFalse(annotationManager.canRedo)
        XCTAssertEqual(annotationManager.annotations, [second])
    }

    func testResetForNewImageClearsAnnotationsDraftsAndHistory() {
        annotationManager.currentTool = .rectangle
        annotationManager.startDrawing(at: CGPoint(x: 1, y: 1))
        annotationManager.updateDrawing(to: CGPoint(x: 20, y: 20))
        annotationManager.finishDrawing()
        annotationManager.undo()

        XCTAssertTrue(annotationManager.canRedo)

        annotationManager.resetForNewImage()

        XCTAssertTrue(annotationManager.annotations.isEmpty)
        XCTAssertNil(annotationManager.selectedAnnotationId)
        XCTAssertNil(annotationManager.currentDraft)
        XCTAssertFalse(annotationManager.isDrawing)
        XCTAssertNil(annotationManager.editingTextAnnotationId)
        XCTAssertFalse(annotationManager.isEditingText)
        XCTAssertFalse(annotationManager.canUndo)
        XCTAssertFalse(annotationManager.canRedo)
    }
    
    // MARK: - Computed Properties Tests
    
    func testSelectedAnnotation() {
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        annotationManager.selectedAnnotationId = annotation.id
        
        XCTAssertEqual(annotationManager.selectedAnnotation?.id, annotation.id)
    }
    
    func testHasAnnotations() {
        XCTAssertFalse(annotationManager.hasAnnotations)
        
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        annotationManager.addAnnotation(annotation)
        XCTAssertTrue(annotationManager.hasAnnotations)
    }
}

#endif
