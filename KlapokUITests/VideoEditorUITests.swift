import XCTest
import AVFoundation
import CoreImage

@MainActor
final class VideoEditorUITests: XCTestCase {
    private var fixtureFolder: URL!
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        fixtureFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: fixtureFolder, withIntermediateDirectories: true)
        let url = fixtureFolder.appendingPathComponent("Screen recording.mov")
        try await makeFixture(url)
        app = XCUIApplication()
        app.launchArguments = ["-UITests", "-UITestVideoURL", url.path, "-app_language", "en"]
        app.launchEnvironment["KLAPOK_UI_TEST_VIDEO_DATA"] = try Data(contentsOf: url).base64EncodedString()
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(at: fixtureFolder)
        super.tearDown()
    }

    func testClipCanBeRenamedFromContextMenu() {
        let clip = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "video.clip.")).firstMatch
        XCTAssertTrue(clip.waitForExistence(timeout: 10))
        clip.rightClick()
        app.menuItems["Rename clip…"].click()
        let sheet = app.windows.firstMatch.sheets.firstMatch
        let field = sheet.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Opening")
        sheet.buttons["Save"].click()
        XCTAssertTrue(app.staticTexts["Opening"].waitForExistence(timeout: 3))
    }

    func testClipCanBeRenamedUsingVisiblePencil() {
        let pencil = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "video.renameClip.")).firstMatch
        XCTAssertTrue(pencil.waitForExistence(timeout: 10))
        pencil.click()
        let sheet = app.windows.firstMatch.sheets.firstMatch
        let field = sheet.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Introduction")
        sheet.buttons["Save"].click()
        XCTAssertTrue(app.staticTexts["Introduction"].waitForExistence(timeout: 3))
    }

    func testVideoClipLoadsFilmstrip() {
        let clip = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "video.clip.")).firstMatch
        XCTAssertTrue(clip.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "frames"), object: clip)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    func testAnnotationToolbarOffersFillAndTextStyles() {
        addLayer("Rectangle")
        let fill = app.checkBoxes["video.fillEnabled"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5))
        XCTAssertEqual(fill.value as? String, "1")
        let opacity = app.descendants(matching: .any)["video.fillOpacity"].firstMatch
        XCTAssertTrue(opacity.exists)
        fill.click()
        XCTAssertEqual(fill.value as? String, "0")
        XCTAssertFalse(opacity.exists)
        fill.click()
        XCTAssertTrue(opacity.waitForExistence(timeout: 3))
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.lifetime = .keepAlways; add(shot)
        addLayer("Text")
        XCTAssertTrue(app.descendants(matching: .any)["video.fontWeight"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["video.editText"].exists)
        XCTAssertFalse(fill.exists)
    }

    func testSilentVideoAndIndependentAnnotationLayers() {
        let audio = app.descendants(matching: .any)["video.audioTrack"].firstMatch
        XCTAssertTrue(audio.waitForExistence(timeout: 10))
        XCTAssertEqual(audio.value as? String, "unavailable")
        addLayer("Text")
        XCTAssertTrue(app.descendants(matching: .any)["video.layer.0"].firstMatch.waitForExistence(timeout: 3))
        addLayer("Rectangle")
        XCTAssertTrue(app.descendants(matching: .any)["video.layer.1"].firstMatch.waitForExistence(timeout: 3))
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }

    func testAnnotationRowsCanBeDraggedToChangeStackingOrder() {
        addLayer("Text")
        addLayer("Rectangle")
        let top = app.descendants(matching: .any)["video.layer.0"].firstMatch
        let bottom = app.descendants(matching: .any)["video.layer.1"].firstMatch
        XCTAssertTrue(top.waitForExistence(timeout: 5))
        XCTAssertTrue(top.staticTexts["Rectangle"].exists)
        let handle = bottom.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "timeline.reorder.")).firstMatch
        XCTAssertTrue(handle.exists)
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = start.withOffset(CGVector(dx: 0, dy: -40))
        start.click(forDuration: 0.8, thenDragTo: destination)
        XCTAssertTrue(top.staticTexts["Text"].waitForExistence(timeout: 5))
        XCTAssertTrue(bottom.staticTexts["Rectangle"].exists)
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.lifetime = .keepAlways; add(shot)
    }

    func testToolbarCreatesInlineText() {
        let tool = app.descendants(matching: .any)["video.tool.text"].firstMatch
        XCTAssertTrue(tool.waitForExistence(timeout: 10))
        tool.click()
        let canvas = app.descendants(matching: .any)["video.canvas"].firstMatch
        let insertion = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        insertion.click()
        let editor = app.descendants(matching: .any)["video.inlineText"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.frame.minX, insertion.screenPoint.x, accuracy: 4)
        XCTAssertEqual(editor.frame.minY, insertion.screenPoint.y, accuracy: 6)
        editor.click()
        editor.typeText("Quick annotation")
        XCTAssertEqual(editor.value as? String, "Quick annotation")
        XCTAssertTrue(app.descendants(matching: .any)["video.layer.0"].firstMatch.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).click()
        XCTAssertFalse(editor.exists)
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "video.annotationHit.")).firstMatch
        XCTAssertEqual(canvas.label, "Video preview")
        app.descendants(matching: .any)["video.layer.0"].firstMatch.click()
        let selected = NSPredicate(format: "label == %@", "Video preview, annotation selected")
        expectation(for: selected, evaluatedWith: canvas)
        waitForExpectations(timeout: 3)
        let annotationX = hit.frame.minX
        let dragStart = hit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        dragStart.click(forDuration: 0.2, thenDragTo: dragStart.withOffset(CGVector(dx: 40, dy: 20)))
        XCTAssertEqual(hit.frame.minX, annotationX + 40, accuracy: 4)
        hit.doubleClick()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click()
        editor.typeText(" edited")
        XCTAssertTrue((editor.value as? String ?? "").contains("edited"))
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.lifetime = .keepAlways; add(shot)
    }

    func testPlaybackControlsAreOutsidePreview() {
        let play = app.buttons["video.playPause"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        let canvas = app.descendants(matching: .any)["video.canvas"].firstMatch
        XCTAssertFalse(canvas.buttons["odtwarzaj/pauza"].exists)
        app.buttons["video.nextFrame"].click()
        play.click()
        XCTAssertEqual(play.value as? String, "playing")
        play.click()
        XCTAssertEqual(play.value as? String, "paused")
        app.buttons["video.stop"].click()
        XCTAssertEqual(play.value as? String, "paused")
    }

    func testToolbarHasClearExportWithoutBrandOrSourceDelete() {
        let export = app.buttons["video.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        let toolbar = app.windows.firstMatch.toolbars.firstMatch
        XCTAssertFalse(toolbar.images["Klapok"].exists)
        XCTAssertTrue(toolbar.buttons["video.showExport"].exists)
        XCTAssertFalse(toolbar.buttons["scissors"].exists)
        XCTAssertFalse(toolbar.buttons["trash"].exists)
    }

    func testExportDoesNotMoveToolbarActions() {
        let export = app.buttons["video.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        let initialX = export.frame.minX
        let copy = app.buttons["video.copyExport"]
        let finder = app.buttons["video.showExport"]
        XCTAssertFalse(copy.isEnabled)
        XCTAssertFalse(finder.isEnabled)
        export.click()
        XCTAssertTrue(app.descendants(matching: .any)["video.exportResult"].firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(export.frame.minX, initialX, accuracy: 2)
        XCTAssertTrue(copy.isEnabled)
        XCTAssertTrue(finder.isEnabled)
        copy.click()
        XCTAssertEqual(copy.value as? String, "copied")
        export.click()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: export)
        waitForExpectations(timeout: 30)
        XCTAssertEqual(export.frame.minX, initialX, accuracy: 2)
    }

    func testArrowCreationAndEndpointMovement() {
        let tool = app.descendants(matching: .any)["video.tool.callout"].firstMatch
        XCTAssertTrue(tool.waitForExistence(timeout: 10))
        tool.click()
        let canvas = app.descendants(matching: .any)["video.canvas"].firstMatch
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3))
        start.click(forDuration: 0.2, thenDragTo: end)
        let endpoint = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "video.annotationEnd.")).firstMatch
        let origin = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "video.annotationStart.")).firstMatch
        XCTAssertTrue(endpoint.waitForExistence(timeout: 3))
        let originX = origin.frame.midX, originY = origin.frame.midY
        let oldEnd = endpoint.frame.midY
        let drag = endpoint.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        drag.click(forDuration: 0.2, thenDragTo: drag.withOffset(CGVector(dx: -20, dy: 70)))
        XCTAssertEqual(origin.frame.midX, originX, accuracy: 2)
        XCTAssertEqual(origin.frame.midY, originY, accuracy: 2)
        XCTAssertEqual(endpoint.frame.midY, oldEnd + 70, accuracy: 4)
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.lifetime = .keepAlways; add(shot)
    }

    func testAnnotationDragKeepsNewPosition() {
        let menu = app.descendants(matching: .any)["video.addAnnotation"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        addLayer("Rectangle")
        let layer = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "video.annotationClip.")).firstMatch
        XCTAssertTrue(layer.waitForExistence(timeout: 3))
        let originalX = layer.frame.minX
        let from = layer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.click(forDuration: 0.2, thenDragTo: from.withOffset(CGVector(dx: 80, dy: 0)))
        XCTAssertGreaterThan(layer.frame.minX, originalX + 50)
        let movedX = layer.frame.minX
        XCTAssertEqual(layer.frame.minX, movedX, accuracy: 2)
        app.buttons["arrow.uturn.backward"].firstMatch.click()
        XCTAssertEqual(layer.frame.minX, originalX, accuracy: 2)
    }

    private func addLayer(_ kind: String) {
        app.descendants(matching: .any)["video.addAnnotation"].firstMatch.click()
        app.menuItems[kind].firstMatch.click()
    }

    private func makeFixture(_ url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 960, AVVideoHeightKey: 540])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for index in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 960, 540, kCVPixelFormatType_32BGRA, nil, &buffer)
            let color = CIColor(red: 0.12 + Double(index) / 150, green: 0.2, blue: 0.45)
            let frame = try XCTUnwrap(buffer)
            context.render(CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 960, height: 540)), to: frame)
            XCTAssertTrue(adaptor.append(frame, withPresentationTime: CMTime(value: Int64(index), timescale: 10)))
        }
        input.markAsFinished(); await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }
}
