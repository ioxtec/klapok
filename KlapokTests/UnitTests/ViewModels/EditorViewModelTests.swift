//
//  EditorViewModelTests.swift
//  KlapokTests
//
//  Unit tests for EditorViewModel
//

import XCTest
@testable import Klapok

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
    
    // MARK: - Output Size Calculation Tests
    
    func testCalculateOutputSizeWithoutBackground() {
        let previousBackgroundType = BackgroundManager.shared.collections.backgroundType
        BackgroundManager.shared.setBackgroundType(.none)
        defer {
            BackgroundManager.shared.setBackgroundType(previousBackgroundType)
        }
        
        let outputSize = editorViewModel.calculateOutputSize(for: testImage)
        
        XCTAssertEqual(outputSize.width, testImage.pixelSize.width, accuracy: 0.1)
        XCTAssertEqual(outputSize.height, testImage.pixelSize.height, accuracy: 0.1)
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
        let previousSaveDirectory = AppSettings.shared.saveDirectory
        let testDirectory = TestHelpers.createTempDirectory()
        AppSettings.shared.saveDirectory = testDirectory
        defer {
            AppSettings.shared.saveDirectory = previousSaveDirectory
            TestHelpers.removeDirectory(testDirectory)
        }

        editorViewModel.show(image: testImage)
        
        editorViewModel.saveImage()
        
        XCTAssertNotNil(editorViewModel.image)
        XCTAssertFalse((try? FileManager.default.contentsOfDirectory(atPath: testDirectory.path).isEmpty) ?? true)
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







