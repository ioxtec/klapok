import XCTest
@testable import Klapok

final class CaptureFilePersistenceTests: XCTestCase {
    func testSavingVideoToItsExistingLocationPreservesSource() throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let source = folder.appendingPathComponent("capture.mp4")
        let bytes = Data([1, 2, 3])
        try bytes.write(to: source)
        let result = try XCTUnwrap(CaptureFileStore.saveVideo(source, fileName: source.lastPathComponent,
            primaryDirectory: folder, fallbackDirectory: folder))
        XCTAssertEqual(result.url, source)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    func testNameCollisionDoesNotOverwriteEarlierRecording() throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let source = folder.appendingPathComponent("source.mp4")
        let previous = folder.appendingPathComponent("capture.mp4")
        try Data([1]).write(to: previous)
        try Data([2]).write(to: source)
        let result = try XCTUnwrap(CaptureFileStore.saveVideo(source, fileName: "capture.mp4",
            primaryDirectory: folder, fallbackDirectory: folder))
        XCTAssertEqual(result.url.lastPathComponent, "capture-2.mp4")
        XCTAssertEqual(try Data(contentsOf: previous), Data([1]))
        XCTAssertEqual(try Data(contentsOf: result.url), Data([2]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
}
