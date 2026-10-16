import AppKit
import Combine
import SwiftUI
import XCTest
@testable import Klapok

@MainActor
final class ProfileRegressionTests: XCTestCase {
    private var directory: URL!
    private var manager: ProfileManager!
    private var background: BackgroundManager!
    private var editor: EditorViewModel!
    private var originalVideoSettings: VideoEditingProfile!

    override func setUp() {
        directory = TestHelpers.createTempDirectory()
        originalVideoSettings = .fromAppSettings(.shared, name: "Previous")
        manager = ProfileManager(profilesDirectory: directory.appendingPathComponent("Profiles"))
        background = BackgroundManager(forPreview: true, storageDirectory: directory.appendingPathComponent("Backgrounds"))
        editor = EditorViewModel()
    }

    override func tearDown() {
        originalVideoSettings.applyToAppSettings(.shared)
        TestHelpers.removeDirectory(directory)
    }

    func testOriginalIsEditableAndCustomSettingsCanBeSavedWithoutChangingPreset() throws {
        let original = try XCTUnwrap(manager.imageProfiles.profiles.first { $0.name == "Original" })
        manager.applyImageProfile(original, to: editor, background: background)
        XCTAssertTrue(original.matchesEditorSettings(editor, background: background))
        editor.ensureVisibleBackgroundPadding(from: .none, to: .gradient)
        background.setBackgroundType(.gradient)
        XCTAssertGreaterThan(editor.backgroundPadding, 0)
        XCTAssertNotNil(background.collections.selectedGradient)
        XCTAssertFalse(original.matchesEditorSettings(editor, background: background))
        editor.backgroundPadding = 800
        editor.backgroundCornerRadius = 600
        let custom = manager.createImageProfileFromCurrentSettings(name: "Large image", from: editor, background: background)
        manager.setActiveImageProfile(custom)
        XCTAssertTrue(custom.matchesEditorSettings(editor, background: background))
        XCTAssertEqual(manager.imageProfiles.profiles.first { $0.id == original.id }?.backgroundPadding, 0)
        manager.applyImageProfile(original, to: editor, background: background)
        XCTAssertTrue(original.matchesEditorSettings(editor, background: background))
        manager.applyImageProfile(custom, to: editor, background: background)
        XCTAssertTrue(custom.matchesEditorSettings(editor, background: background))
        XCTAssertEqual(editor.backgroundPadding, 800)
        XCTAssertEqual(editor.backgroundCornerRadius, 600)
        let reloaded = ProfileManager(profilesDirectory: directory.appendingPathComponent("Profiles"))
        XCTAssertEqual(reloaded.getActiveImageProfile()?.backgroundPadding, 800)
    }

    func testImageWorkingStateDetectsAllEditableAppearanceChanges() throws {
        let profile = try XCTUnwrap(manager.imageProfiles.profiles.first)
        let changes: [(EditorViewModel) -> Void] = [
            { $0.backgroundPadding += 10 }, { $0.backgroundCornerRadius += 20 },
            { $0.selectedAspectRatio = .ratio1_1 }, { $0.shadowIntensity += 5 },
            { $0.enableRoundedCorners.toggle() }, { $0.cornerRadius += 30 },
            { $0.selectedBackgroundColor = .red }
        ]
        for change in changes {
            manager.applyImageProfile(profile, to: editor, background: background)
            XCTAssertTrue(profile.matchesEditorSettings(editor, background: background))
            change(editor)
            XCTAssertFalse(profile.matchesEditorSettings(editor, background: background))
        }
        manager.applyImageProfile(profile, to: editor, background: background)
        background.collections.customGradients[background.collections.customGradients.count - 1].opacity = 0.5
        XCTAssertFalse(profile.matchesEditorSettings(editor, background: background))
    }

    func testVideoPresetIsEditableAndCanBeSavedAsNewProfile() throws {
        let preset = try XCTUnwrap(manager.videoProfiles.profiles.first)
        let settings = AppSettings.shared
        manager.applyVideoProfile(preset, to: settings)
        XCTAssertTrue(preset.matchesAppSettings(settings))
        settings.videoCodec = preset.codec == "H.264" ? "H.265" : "H.264"
        settings.showMouseCursor.toggle()
        XCTAssertFalse(preset.matchesAppSettings(settings))
        let custom = manager.createVideoProfileFromCurrentSettings(name: "Custom recording", from: settings)
        manager.setActiveVideoProfile(custom)
        XCTAssertTrue(custom.matchesAppSettings(settings))
        XCTAssertEqual(manager.videoProfiles.profiles.first { $0.id == preset.id }?.codec, preset.codec)
        manager.applyVideoProfile(preset, to: settings)
        XCTAssertTrue(preset.matchesAppSettings(settings))
        manager.applyVideoProfile(custom, to: settings)
        XCTAssertTrue(custom.matchesAppSettings(settings))
    }

    func testLargeImageHasUsefulAnnotationDefaultsAndExpandedControls() {
        editor.show(image: NSImage(size: NSSize(width: 6200, height: 4200)))
        XCTAssertGreaterThan(editor.annotationManager.defaultFontSize, 48)
        XCTAssertGreaterThan(editor.annotationManager.defaultStrokeWidth, 10)
        XCTAssertEqual(EditorSizing.fontSizes.last, 1024)
        XCTAssertEqual(EditorSizing.strokeWidths.last, 256)
        XCTAssertGreaterThan(EditorSizing.cornerRange(for: CGSize(width: 6200, height: 4200), current: 0).upperBound, 50)
        XCTAssertEqual(EditorSizing.cornerRange(for: .zero, current: 5000).upperBound, 5000)
        editor.annotationManager.selectTool(.text)
        editor.annotationManager.startDrawing(at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(editor.annotationManager.currentDraft?.fontSize, editor.annotationManager.defaultFontSize)
        editor.show(image: NSImage(size: NSSize(width: 1000, height: 500)))
        XCTAssertEqual(editor.annotationManager.defaultFontSize, 18)
        XCTAssertEqual(editor.annotationManager.defaultStrokeWidth, 3)
    }

    func testLargeAnnotationsExportAtNativeImageDimensions() throws {
        let image = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 6200, height: 4200))
        background.setBackgroundType(.none)
        let text = Annotation(type: .text, startPoint: CGPoint(x: 400, y: 400),
                              endPoint: CGPoint(x: 2800, y: 1200), text: "Large image",
                              fontSize: 384, color: ColorData(color: .red))
        let arrow = Annotation(type: .arrow, startPoint: CGPoint(x: 500, y: 2100),
                               endPoint: CGPoint(x: 4500, y: 2100), color: ColorData(color: .blue),
                               strokeWidth: 128, arrowStyle: .triangle)
        let result = ImageCompositeRenderer.render(image: image, backgroundManager: background,
            annotations: [text, arrow], padding: 0, aspectRatio: .auto, shadowIntensity: 0)
        XCTAssertEqual(result.pixelSize, CGSize(width: 6200, height: 4200))
        let bitmap = try XCTUnwrap(CaptureFileStore.nativeBitmap(from: result))
        let shaft = try XCTUnwrap(bitmap.colorAt(x: 2500, y: 2100)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(shaft.alphaComponent, 0.9)
        XCTAssertGreaterThan(shaft.blueComponent, 0.9)
        let aboveShaft = try XCTUnwrap(bitmap.colorAt(x: 2500, y: 1950))
        XCTAssertLessThan(aboveShaft.alphaComponent, 0.1)
    }

    func testGradientSelectionRecoversMissingGradientAndZeroMargin() {
        background.collections.customGradients = []
        background.collections.selectedGradientId = nil
        background.collections.backgroundType = .none
        editor.backgroundPadding = 0
        editor.ensureVisibleBackgroundPadding(from: .none, to: .gradient)
        background.setBackgroundType(.gradient)
        XCTAssertNotNil(background.collections.selectedGradient)
        XCTAssertEqual(editor.backgroundPadding, 30)
        editor.backgroundPadding = 120
        editor.ensureVisibleBackgroundPadding(from: .none, to: .gradient)
        XCTAssertEqual(editor.backgroundPadding, 120)
    }

    func testBlurredWallpaperExportsWithoutBlurringForeground() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80,
            pixelsHigh: 80, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let bytes = try XCTUnwrap(bitmap.bitmapData)
        for y in 0..<80 { for x in 0..<80 {
            let offset = y * bitmap.bytesPerRow + x * 4
            let value: UInt8 = x < 40 ? 0 : 255
            bytes[offset] = value; bytes[offset + 1] = value
            bytes[offset + 2] = value; bytes[offset + 3] = 255
        } }
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let wallpaper = BackgroundImage(name: "Split", fileName: "split.png", scaleMode: .stretch)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Backgrounds/Klapok Background Images"), withIntermediateDirectories: true)
        background.addBackgroundImage(wallpaper, imageData: data)
        background.selectImage(withId: wallpaper.id)
        let source = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 40, height: 40))
        let sourceBitmap = try XCTUnwrap(source.representations.first as? NSBitmapImageRep)
        let sourceBytes = try XCTUnwrap(sourceBitmap.bitmapData)
        for y in 0..<40 { for x in 0..<40 {
            let offset = y * sourceBitmap.bytesPerRow + x * 4
            sourceBytes[offset] = 0; sourceBytes[offset + 1] = 255
            sourceBytes[offset + 2] = 0; sourceBytes[offset + 3] = 255
        } }
        func render() throws -> NSBitmapImageRep {
            let image = ImageCompositeRenderer.render(image: source, backgroundManager: background,
                annotations: [], padding: 20, aspectRatio: .auto, shadowIntensity: 0)
            XCTAssertEqual(image.pixelSize, CGSize(width: 80, height: 80))
            return try XCTUnwrap(CaptureFileStore.nativeBitmap(from: image))
        }
        let sharp = try render()
        var blurred = wallpaper
        blurred.blurRadius = 8
        background.updateBackgroundImage(blurred)
        let output = try render()
        let before = try XCTUnwrap(sharp.colorAt(x: 35, y: 5)?.usingColorSpace(.deviceRGB))
        let after = try XCTUnwrap(output.colorAt(x: 35, y: 5)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(before.redComponent, 0.01)
        XCTAssertGreaterThan(after.redComponent, before.redComponent + 0.05)
        let foreground = try XCTUnwrap(output.colorAt(x: 21, y: 21)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(foreground.greenComponent, 0.99)
        XCTAssertLessThan(foreground.redComponent, 0.01)
        let edge = try XCTUnwrap(output.colorAt(x: 0, y: 0))
        XCTAssertGreaterThan(edge.alphaComponent, 0.99)
        let preview = try XCTUnwrap(background.renderedImage(for: blurred))
        XCTAssertTrue(preview === background.renderedImage(for: blurred))
        background.updateBackgroundImage(wallpaper)
        let restored = try render()
        XCTAssertLessThan(try XCTUnwrap(restored.colorAt(x: 35, y: 5)?.usingColorSpace(.deviceRGB)).redComponent, 0.01)
    }

    func testLegacyWallpaperDecodesWithoutBlur() throws {
        let image = BackgroundImage(name: "Legacy", fileName: "old.png", blurRadius: 25)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(image)) as? [String: Any])
        json.removeValue(forKey: "blurRadius")
        let decoded = try JSONDecoder().decode(BackgroundImage.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.blurRadius, 0)
        XCTAssertEqual(decoded.id, image.id)
    }

    func testProfileImportRejectsInvalidWallpaperBlur() throws {
        let source = TestHelpers.createTestImage(size: CGSize(width: 20, height: 20), color: .blue)
        let data = try XCTUnwrap(CaptureFileStore.nativeBitmap(from: source)?.representation(using: .png, properties: [:]))
        let image = BackgroundImage(name: "Bad blur", fileName: "bad.png", blurRadius: 101)
        let profile = ImageEditingProfile(name: "Invalid", appearance: ImageProfileAppearance(
            backgroundType: .image, backgroundImage: image, backgroundImageData: data))
        XCTAssertThrowsError(try ProfileCollection(profiles: [profile]).validated())
    }

    func testCustomGradientStyleSurvivesSaveReloadAndApply() throws {
        var gradient = try XCTUnwrap(background.collections.customGradients.first)
        gradient.opacity = 0.45
        gradient.direction = .leftToRight
        gradient.stops = [GradientStopData(color: ColorData(color: .red), location: 0),
                          GradientStopData(color: ColorData(color: .green), location: 0.4),
                          GradientStopData(color: ColorData(color: .blue), location: 1)]
        background.collections.customGradients = [gradient]
        background.collections.selectedGradientId = gradient.id
        editor.enableRoundedCorners = true
        editor.cornerRadius = 17
        editor.backgroundPadding = 48
        editor.backgroundCornerRadius = 11
        editor.shadowIntensity = 33
        editor.selectedAspectRatio = .ratio3_2
        let profile = manager.createImageProfileFromCurrentSettings(name: "Custom", from: editor, background: background)
        manager.setActiveImageProfile(profile)
        let restored = ProfileManager(profilesDirectory: directory.appendingPathComponent("Profiles"))
        background.collections.backgroundType = .none
        background.collections.customGradients = []
        editor.enableRoundedCorners = false
        editor.backgroundPadding = 2
        restored.applyImageProfile(try XCTUnwrap(restored.getActiveImageProfile()), to: editor, background: background)
        XCTAssertEqual(background.collections.backgroundType, .gradient)
        XCTAssertEqual(background.collections.selectedGradient?.opacity, 0.45)
        XCTAssertEqual(background.collections.selectedGradient?.direction, .leftToRight)
        XCTAssertEqual(background.collections.selectedGradient?.stops.map(\.location), [0, 0.4, 1])
        XCTAssertEqual(editor.backgroundPadding, 48)
        XCTAssertEqual(editor.backgroundCornerRadius, 11)
        XCTAssertEqual(editor.shadowIntensity, 33)
        XCTAssertEqual(editor.selectedAspectRatio, .ratio3_2)
        XCTAssertTrue(editor.enableRoundedCorners)
        XCTAssertEqual(editor.cornerRadius, 17)
    }

    func testUpdatingCustomImageProfilePreservesIdentityAndOtherFields() {
        let profile = ImageEditingProfile(name: "Custom", imageFormat: .jpeg, imageQuality: 0.65)
        background.collections.backgroundType = .none
        editor.enableRoundedCorners = true
        editor.cornerRadius = 21
        let updated = profile.updating(from: editor, background: background)
        XCTAssertEqual(updated.id, profile.id)
        XCTAssertEqual(updated.createdAt, profile.createdAt)
        XCTAssertEqual(updated.imageFormat, .jpeg)
        XCTAssertEqual(updated.imageQuality, 0.65)
        XCTAssertEqual(updated.appearance?.backgroundType, BackgroundType.none)
        XCTAssertEqual(updated.appearance?.imageCornerRadius, 21)
    }

    func testCustomBackgroundImageTravelsInsideExportedJSON() throws {
        let source = TestHelpers.createTestImage(size: CGSize(width: 80, height: 40), color: .orange)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(source.tiffRepresentation)))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let image = BackgroundImage(name: "Custom wallpaper", fileName: "wallpaper.png", opacity: 0.6, scaleMode: .fill, blurRadius: 17)
        // The normal background importer creates its storage directory first.
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Backgrounds/Klapok Background Images"), withIntermediateDirectories: true)
        background.addBackgroundImage(image, imageData: data)
        background.selectImage(withId: image.id)
        let profile = manager.createImageProfileFromCurrentSettings(name: "Wallpaper", from: editor, background: background)
        manager.setActiveImageProfile(profile)
        var changed = image
        changed.blurRadius = 30
        background.updateBackgroundImage(changed)
        XCTAssertFalse(profile.matchesEditorSettings(editor, background: background))
        let export = directory.appendingPathComponent("export.json")
        try manager.exportImageProfiles(to: export)
        let destination = ProfileManager(profilesDirectory: directory.appendingPathComponent("OtherProfiles"))
        let otherBackground = BackgroundManager(forPreview: true, storageDirectory: directory.appendingPathComponent("OtherBackgrounds"))
        try destination.importImageProfiles(from: export)
        destination.applyImageProfile(try XCTUnwrap(destination.getActiveImageProfile()), to: editor, background: otherBackground)
        let restored = try XCTUnwrap(otherBackground.collections.selectedImage)
        XCTAssertEqual(otherBackground.collections.backgroundType, .image)
        XCTAssertEqual(restored.opacity, 0.6)
        XCTAssertEqual(restored.scaleMode, .fill)
        XCTAssertEqual(restored.blurRadius, 17)
        XCTAssertEqual(restored.fileName, "profile-\(image.id.uuidString).png")
        let restoredData = try XCTUnwrap(otherBackground.profileImageData(for: restored))
        let restoredBitmap = try XCTUnwrap(NSBitmapImageRep(data: restoredData))
        XCTAssertEqual(restoredBitmap.pixelsWide, bitmap.pixelsWide)
        XCTAssertEqual(restoredBitmap.pixelsHigh, bitmap.pixelsHigh)
    }

    func testOriginalAndLegacyOriginalKeepNativePixelsAndSquareCorners() throws {
        let source = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 1000, height: 500))
        let original = try XCTUnwrap(ImageEditingProfile.createDefaultProfiles().first { $0.name == "Original" })
        for profile in [original, ImageEditingProfile(name: "Original", backgroundPadding: 0, shadowIntensity: 0)] {
            editor.enableRoundedCorners = true
            background.collections.backgroundType = .gradient
            XCTAssertTrue(profile.applyToEditorViewModel(editor, background: background))
            XCTAssertEqual(background.collections.backgroundType, .none)
            XCTAssertFalse(editor.enableRoundedCorners)
            XCTAssertEqual(editor.backgroundCornerRadius, 0)
            let result = ImageCompositeRenderer.render(image: source, backgroundManager: background,
                annotations: [], padding: editor.backgroundPadding, aspectRatio: editor.selectedAspectRatio,
                shadowIntensity: editor.shadowIntensity, cornerRadius: editor.enableRoundedCorners ? editor.cornerRadius : 0,
                canvasCornerRadius: editor.backgroundCornerRadius)
            XCTAssertTrue(result === source)
            XCTAssertEqual(result.pixelSize, CGSize(width: 1000, height: 500))
        }
    }

    func testOldImageProfileWithoutAppearanceRemainsReadable() throws {
        let old = ImageEditingProfile(name: "Legacy", backgroundPadding: 47)
        let decoded = try JSONDecoder().decode(ImageEditingProfile.self, from: JSONEncoder().encode(old))
        XCTAssertNil(decoded.appearance)
        XCTAssertTrue(decoded.applyToEditorViewModel(editor, background: background))
        XCTAssertEqual(editor.backgroundPadding, 47)
    }

    func testImageImportResetAndActiveDeletionNotifyOpenEditor() throws {
        let subscription = manager.$imageApplicationRevision.dropFirst().sink { [self] _ in
            if let active = manager.getActiveImageProfile() {
                manager.applyImageProfile(active, to: editor, background: background)
            }
        }
        defer { subscription.cancel() }
        editor.backgroundPadding = 64
        let profile = manager.createImageProfileFromCurrentSettings(name: "Imported", from: editor, background: background)
        manager.setActiveImageProfile(profile)
        let export = directory.appendingPathComponent("image.json")
        try manager.exportImageProfiles(to: export)
        editor.backgroundPadding = 1
        try manager.importImageProfiles(from: export)
        XCTAssertEqual(editor.backgroundPadding, 64)
        manager.removeImageProfile(withId: profile.id)
        XCTAssertEqual(editor.backgroundPadding, 30)
        editor.backgroundPadding = 2
        manager.resetImageProfilesToDefaults()
        XCTAssertEqual(editor.backgroundPadding, 30)
    }

    func testVideoImportResetAndActiveDeletionApplyActualSettings() throws {
        let profile = VideoEditingProfile(name: "Custom video", resolution: "720p", frameRate: 24,
            bitrate: 3_000_000, codec: "H.265", format: "MOV", recordSystemAudio: true,
            showMouseCursor: true, enableRecordingCountdown: true, recordingCountdownSeconds: 5)
        manager.addVideoProfile(profile)
        manager.setActiveVideoProfile(profile)
        let export = directory.appendingPathComponent("video.json")
        try manager.exportVideoProfiles(to: export)
        AppSettings.shared.videoFrameRate = 60
        try manager.importVideoProfiles(from: export)
        let settings = AppSettings.shared
        XCTAssertEqual(settings.videoFrameRate, 24)
        XCTAssertEqual(settings.videoBitrate, 3_000_000)
        XCTAssertEqual(settings.videoCodec, "H.265")
        XCTAssertEqual(settings.videoFormat, "MOV")
        XCTAssertEqual(settings.videoResolution, "720p")
        XCTAssertTrue(settings.recordSystemAudio)
        XCTAssertTrue(settings.showMouseCursor)
        XCTAssertTrue(settings.enableRecordingCountdown)
        XCTAssertEqual(settings.recordingCountdownSeconds, 5)
        manager.removeVideoProfile(withId: profile.id)
        XCTAssertEqual(settings.videoFrameRate, manager.getActiveVideoProfile()?.frameRate)
        settings.videoFrameRate = 24
        manager.resetVideoProfilesToDefaults()
        XCTAssertEqual(settings.videoFrameRate, 60)
        XCTAssertEqual(settings.videoResolution, "Source")
    }

    func testEmptyImageAndVideoImportsKeepMemoryAndDiskUnchanged() throws {
        let imageID = manager.getActiveImageProfile()?.id
        let videoID = manager.getActiveVideoProfile()?.id
        let imageFile = directory.appendingPathComponent("Profiles/image_profiles.json")
        let videoFile = directory.appendingPathComponent("Profiles/video_profiles.json")
        let oldImage = try Data(contentsOf: imageFile), oldVideo = try Data(contentsOf: videoFile)
        let url = directory.appendingPathComponent("empty.json")
        try JSONEncoder().encode(ProfileCollection<ImageEditingProfile>()).write(to: url)
        XCTAssertThrowsError(try manager.importImageProfiles(from: url))
        XCTAssertThrowsError(try manager.importVideoProfiles(from: url))
        XCTAssertEqual(manager.getActiveImageProfile()?.id, imageID)
        XCTAssertEqual(manager.getActiveVideoProfile()?.id, videoID)
        XCTAssertEqual(try Data(contentsOf: imageFile), oldImage)
        XCTAssertEqual(try Data(contentsOf: videoFile), oldVideo)
    }

    func testInvalidIdentifiersSettingsAndMissingImageAreRejected() throws {
        let profile = ImageEditingProfile(name: "Duplicate")
        let url = directory.appendingPathComponent("invalid.json")
        for collection in [ProfileCollection(profiles: [profile, profile]),
                           ProfileCollection(profiles: [profile], activeProfileId: UUID()),
                           ProfileCollection(profiles: [ImageEditingProfile(name: "Invalid", backgroundPadding: -1)]),
                           ProfileCollection(profiles: [ImageEditingProfile(name: "Missing wallpaper", appearance: .init(backgroundType: .image))])] {
            try JSONEncoder().encode(collection).write(to: url)
            XCTAssertThrowsError(try manager.importImageProfiles(from: url))
        }
        let badVideo = VideoEditingProfile(name: "Invalid", frameRate: 0)
        try JSONEncoder().encode(ProfileCollection(profiles: [badVideo])).write(to: url)
        XCTAssertThrowsError(try manager.importVideoProfiles(from: url))
    }

    func testCollectionWithoutSelectionUsesFirstProfile() throws {
        let profile = ImageEditingProfile(name: "First", backgroundPadding: 56)
        let url = directory.appendingPathComponent("no-selection.json")
        try JSONEncoder().encode(ProfileCollection(profiles: [profile])).write(to: url)
        try manager.importImageProfiles(from: url)
        XCTAssertEqual(manager.getActiveImageProfile()?.id, profile.id)
    }

    func testEveryBuiltInProfileAppliesItsValuesAfterAnotherPreset() {
        for profile in manager.imageProfiles.profiles.reversed() {
            manager.applyImageProfile(profile, to: editor, background: background)
            XCTAssertEqual(editor.selectedAspectRatio, profile.backgroundAspectRatio)
            XCTAssertEqual(editor.backgroundPadding, profile.backgroundPadding)
            XCTAssertEqual(editor.backgroundCornerRadius, profile.backgroundCornerRadius)
            XCTAssertEqual(editor.shadowIntensity, profile.shadowIntensity)
            XCTAssertEqual(background.collections.backgroundType, profile.appearance?.backgroundType)
            XCTAssertEqual(manager.getActiveImageProfile()?.id, profile.id)
        }
        for profile in manager.videoProfiles.profiles.reversed() {
            let settings = AppSettings.shared
            manager.applyVideoProfile(profile, to: settings)
            XCTAssertEqual(settings.videoResolution, profile.resolution)
            XCTAssertEqual(settings.videoFrameRate, profile.frameRate)
            XCTAssertEqual(settings.videoBitrate, profile.bitrate)
            XCTAssertEqual(settings.videoCodec, profile.codec)
            XCTAssertEqual(settings.videoFormat, profile.format)
            XCTAssertEqual(settings.recordSystemAudio, profile.recordSystemAudio)
            XCTAssertEqual(settings.showMouseCursor, profile.showMouseCursor)
            XCTAssertEqual(settings.enableRecordingCountdown, profile.enableRecordingCountdown)
            XCTAssertEqual(settings.recordingCountdownSeconds, profile.recordingCountdownSeconds)
        }
    }
}
