//
//  TestHelpers.swift
//  KlapokTests
//
//  Helper functions for testing
//

import Foundation
import XCTest

#if os(macOS)
import AppKit

// MARK: - Test Image Helpers

extension TestHelpers {
    /// Creates a test NSImage with specified size
    static func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: NSColor = .blue) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
    
    /// Creates a test NSImage from a simple bitmap
    static func createTestImageFromData(width: Int = 100, height: Int = 100) -> NSImage? {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let rep = rep else { return nil }
        
        image.addRepresentation(rep)
        return image
    }
}

// MARK: - Test Window Helpers

extension TestHelpers {
    /// Creates a mock window wrapper for testing
    static func createMockWindow(
        windowID: CGWindowID = 1,
        title: String = "Test Window",
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    ) -> MockWindowWrapper {
        return MockWindowWrapper(
            windowID: windowID,
            title: title,
            frame: frame
        )
    }
}

// MARK: - File System Helpers

extension TestHelpers {
    /// Creates a temporary directory for testing
    static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: testDir,
            withIntermediateDirectories: true
        )
        
        return testDir
    }
    
    /// Removes a directory and all its contents
    static func removeDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Cleans up test files
    static func cleanupTestFiles(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Async Test Helpers

extension TestHelpers {
    /// Waits for an async operation to complete
    static func waitForAsync(
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping () async throws -> Void
    ) async throws {
        let expectation = XCTestExpectation(description: "Async operation")
        var caughtError: Error?
        
        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                caughtError = error
                expectation.fulfill()
            }
        }
        
        // Use withCheckedContinuation to bridge sync XCTWaiter with async context
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
                if result != .completed {
                    XCTFail("Async operation timed out", file: file, line: line)
                }
                continuation.resume()
            }
        }
        
        if let error = caughtError {
            throw error
        }
    }
}

// MARK: - Test Helpers Class

enum TestHelpers {
    // Static helper functions are defined in extensions above
}

#endif

