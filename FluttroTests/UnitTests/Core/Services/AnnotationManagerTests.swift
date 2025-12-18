//
//  AnnotationManagerTests.swift
//  FluttroTests
//
//  Unit tests for AnnotationManager
//

import XCTest
@testable import Fluttro

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

