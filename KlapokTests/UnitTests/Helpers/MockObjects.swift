//
//  MockObjects.swift
//  KlapokTests
//
//  Mock objects for testing
//

import Foundation
@testable import Klapok

#if os(macOS)
import AppKit
import ScreenCaptureKit

// Note: SCWindow and SCRunningApplication cannot be subclassed or mocked directly
// We use protocol-based approach for testing

// MARK: - Mock Window Protocol

/// Protocol for mock windows in tests
/// Note: SCWindow cannot be subclassed, so we use a protocol-based approach
protocol MockWindowProtocol {
    var windowID: CGWindowID { get }
    var title: String? { get }
    var frame: CGRect { get }
    var owningApplication: SCRunningApplication? { get }
}

/// Wrapper for SCWindow that can be used in tests
struct MockWindowWrapper: MockWindowProtocol {
    let windowID: CGWindowID
    let title: String?
    let frame: CGRect
    let owningApplication: SCRunningApplication?
    
    init(
        windowID: CGWindowID = 1,
        title: String? = "Test Window",
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        owningApplication: SCRunningApplication? = nil
    ) {
        self.windowID = windowID
        self.title = title
        self.frame = frame
        self.owningApplication = owningApplication
    }
}

// MARK: - Mock Capture Service

protocol MockCaptureServiceProtocol {
    var shouldSucceed: Bool { get set }
    var mockImage: NSImage? { get set }
    var captureCallCount: Int { get }
}

class MockFullScreenCaptureService: MockCaptureServiceProtocol {
    var shouldSucceed: Bool = true
    var mockImage: NSImage?
    var captureCallCount: Int = 0
    
    func capture() async throws -> NSImage {
        captureCallCount += 1
        
        if !shouldSucceed {
            throw CaptureError.permissionDenied
        }
        
        return mockImage ?? TestHelpers.createTestImage()
    }
}

class MockAreaCaptureService: MockCaptureServiceProtocol {
    var shouldSucceed: Bool = true
    var mockImage: NSImage?
    var captureCallCount: Int = 0
    var lastCapturedArea: NSRect?
    
    func capture(area: NSRect) async throws -> NSImage {
        captureCallCount += 1
        lastCapturedArea = area
        
        if !shouldSucceed {
            throw CaptureError.invalidConfiguration
        }
        
        return mockImage ?? TestHelpers.createTestImage()
    }
}

class MockWindowCaptureService: MockCaptureServiceProtocol {
    var shouldSucceed: Bool = true
    var mockImage: NSImage?
    var captureCallCount: Int = 0
    var lastCapturedWindow: SCWindow?
    
    func capture(window: SCWindow) async throws -> NSImage {
        captureCallCount += 1
        lastCapturedWindow = window
        
        if !shouldSucceed {
            throw CaptureError.noWindowSelected
        }
        
        return mockImage ?? TestHelpers.createTestImage()
    }
}

// MARK: - Mock File Manager

class MockFileManager: FileManager {
    var fileExistsResults: [String: Bool] = [:]
    var createDirectoryShouldSucceed: Bool = true
    var writeShouldSucceed: Bool = true
    var removeItemShouldSucceed: Bool = true
    
    override func fileExists(atPath path: String) -> Bool {
        return fileExistsResults[path] ?? super.fileExists(atPath: path)
    }
    
    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        if !createDirectoryShouldSucceed {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        try super.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
}

#endif

