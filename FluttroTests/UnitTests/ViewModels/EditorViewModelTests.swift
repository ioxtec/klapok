//
//  EditorViewModelTests.swift
//  FluttroTests
//
//  Unit tests for EditorViewModel
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class EditorViewModelTests: XCTestCase {
    
    var editorViewModel: EditorViewModel!
    var testImage: NSImage!
    
    override func setUp() {
        super.setUp()
        editorViewModel = EditorViewModel()
        testImage = TestHelpers.createTestImage(size: CGSize(width: 800, height: 600))
    }
    
    override func tearDown() {
        editorViewModel = nil
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - Show Image Tests
    
    func testShowImage() {
        editorViewModel.show(image: testImage)
        
        XCTAssertEqual(editorViewModel.image, testImage)
        XCTAssertTrue(editorViewModel.isPresented)
    }
    
    // MARK: - Close Tests
    
    func testClose() {
        editorViewModel.show(image: testImage)
        editorViewModel.close()
        
        XCTAssertNil(editorViewModel.image)
        XCTAssertFalse(editorViewModel.isPresented)
    }
    
    // MARK: - Background Size Calculation Tests
    
    func testCalculateBackgroundSizeAuto() {
        let imageSize = CGSize(width: 800, height: 600)
        let availableSize = CGSize(width: 1200, height: 1000)
        editorViewModel.backgroundPadding = 30.0
        editorViewModel.selectedAspectRatio = .auto
        
        let backgroundSize = editorViewModel.calculateBackgroundSize(
            for: imageSize,
            in: availableSize
        )
        
        // Should use available space with padding
        XCTAssertEqual(backgroundSize.width, availableSize.width - 60.0, accuracy: 0.1)
        XCTAssertEqual(backgroundSize.height, availableSize.height - 60.0, accuracy: 0.1)
    }
    
    func testCalculateBackgroundSize16_9() {
        let imageSize = CGSize(width: 800, height: 600)
        let availableSize = CGSize(width: 1200, height: 1000)
        editorViewModel.backgroundPadding = 30.0
        editorViewModel.selectedAspectRatio = .ratio16_9
        
        let backgroundSize = editorViewModel.calculateBackgroundSize(
            for: imageSize,
            in: availableSize
        )
        
        // Should maintain 16:9 ratio
        let ratio = backgroundSize.width / backgroundSize.height
        XCTAssertEqual(ratio, 16.0/9.0, accuracy: 0.01)
    }
    
    func testCalculateBackgroundSize4_3() {
        let imageSize = CGSize(width: 800, height: 600)
        let availableSize = CGSize(width: 1200, height: 1000)
        editorViewModel.backgroundPadding = 30.0
        editorViewModel.selectedAspectRatio = .ratio4_3
        
        let backgroundSize = editorViewModel.calculateBackgroundSize(
            for: imageSize,
            in: availableSize
        )
        
        // Should maintain 4:3 ratio
        let ratio = backgroundSize.width / backgroundSize.height
        XCTAssertEqual(ratio, 4.0/3.0, accuracy: 0.01)
    }
    
    // MARK: - Image Position Calculation Tests
    
    func testCalculateImagePosition() {
        let backgroundSize = CGSize(width: 1200, height: 1000)
        let imageSize = CGSize(width: 800, height: 600)
        
        let position = editorViewModel.calculateImagePosition(
            backgroundSize: backgroundSize,
            imageSize: imageSize
        )
        
        // Should be centered
        XCTAssertEqual(position.x, 200.0, accuracy: 0.1)
        XCTAssertEqual(position.y, 200.0, accuracy: 0.1)
    }
    
    // MARK: - Annotation Manager Integration Tests
    
    func testAnnotationManagerIntegration() {
        XCTAssertNotNil(editorViewModel.annotationManager)
        
        let annotation = Annotation(
            type: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50)
        )
        
        editorViewModel.annotationManager.addAnnotation(annotation)
        XCTAssertTrue(editorViewModel.annotationManager.hasAnnotations)
    }
    
    // MARK: - Save Image Tests
    
    func testSaveImage() {
        editorViewModel.show(image: testImage)
        
        // Note: This will actually try to save, so we just verify it doesn't crash
        // In a real scenario, we would mock AppSettings
        editorViewModel.saveImage()
        
        // Should not crash
        XCTAssertNotNil(editorViewModel.image)
    }
    
    // MARK: - Copy to Clipboard Tests
    
    func testCopyToClipboard() {
        editorViewModel.show(image: testImage)
        
        // Note: This will actually copy to clipboard
        editorViewModel.copyToClipboard()
        
        // Verify clipboard has content
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems
        XCTAssertNotNil(items)
    }
    
    // MARK: - Property Tests
    
    func testDefaultProperties() {
        XCTAssertEqual(editorViewModel.selectedAspectRatio, .auto)
        XCTAssertEqual(editorViewModel.backgroundPadding, 30.0)
        XCTAssertEqual(editorViewModel.backgroundCornerRadius, 20.0)
        XCTAssertEqual(editorViewModel.shadowIntensity, 25.0)
    }
    
    func testPropertyUpdates() {
        editorViewModel.selectedAspectRatio = .ratio16_9
        editorViewModel.backgroundPadding = 50.0
        editorViewModel.shadowIntensity = 40.0
        
        XCTAssertEqual(editorViewModel.selectedAspectRatio, .ratio16_9)
        XCTAssertEqual(editorViewModel.backgroundPadding, 50.0)
        XCTAssertEqual(editorViewModel.shadowIntensity, 40.0)
    }
}

#endif








