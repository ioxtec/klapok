//
//  CaptureFileStore.swift
//  Fluttro
//

import Foundation

#if os(macOS)
import AppKit

struct CaptureFileStoreResult {
    let url: URL
    let directory: URL
}

enum CaptureFileStore {
    static func ensureDirectory(_ directory: URL, securityScoped: Bool = false) throws {
        try withSecurityScope(for: directory, enabled: securityScoped) {
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        }
    }

    static func saveScreenshot(
        _ image: NSImage,
        fileName: String,
        primaryDirectory: URL,
        fallbackDirectory: URL,
        securityScoped: Bool = false
    ) -> CaptureFileStoreResult? {
        saveScreenshot(
            image,
            fileName: fileName,
            to: primaryDirectory,
            securityScoped: securityScoped
        )
            ?? saveScreenshot(image, fileName: fileName, to: fallbackDirectory)
    }

    static func saveVideo(
        _ sourceURL: URL,
        fileName: String,
        primaryDirectory: URL,
        fallbackDirectory: URL
    ) -> CaptureFileStoreResult? {
        saveVideo(sourceURL, fileName: fileName, to: primaryDirectory)
            ?? saveVideo(sourceURL, fileName: fileName, to: fallbackDirectory)
    }

    static func writeScreenshot(_ image: NSImage, to fileURL: URL) -> Bool {
        guard let pngData = pngData(from: image) else {
            Logger.e("CaptureFileStore: Failed to convert screenshot to PNG")
            return false
        }

        do {
            try pngData.write(to: fileURL)
            return true
        } catch {
            Logger.e("CaptureFileStore: Failed to write screenshot to \(fileURL.path): \(error)")
            return false
        }
    }

    private static func saveScreenshot(
        _ image: NSImage,
        fileName: String,
        to directory: URL,
        securityScoped: Bool = false
    ) -> CaptureFileStoreResult? {
        guard let pngData = pngData(from: image) else {
            Logger.e("CaptureFileStore: Failed to convert screenshot to PNG")
            return nil
        }

        do {
            return try withSecurityScope(for: directory, enabled: securityScoped) {
                try ensureDirectory(directory)
                let fileURL = directory.appendingPathComponent(fileName)
                try pngData.write(to: fileURL)
                return CaptureFileStoreResult(url: fileURL, directory: directory)
            }
        } catch {
            Logger.e("CaptureFileStore: Failed to save screenshot to \(directory.path): \(error)")
            return nil
        }
    }

    private static func saveVideo(
        _ sourceURL: URL,
        fileName: String,
        to directory: URL
    ) -> CaptureFileStoreResult? {
        do {
            return try withSecurityScope(for: directory, enabled: true) {
                try ensureDirectory(directory)
                let destinationURL = directory.appendingPathComponent(fileName)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                return CaptureFileStoreResult(url: destinationURL, directory: directory)
            }
        } catch {
            Logger.e("CaptureFileStore: Failed to save video to \(directory.path): \(error)")
            return nil
        }
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmapRep.representation(using: .png, properties: [:])
    }

    private static func withSecurityScope<T>(
        for directory: URL,
        enabled: Bool,
        _ operation: () throws -> T
    ) throws -> T {
        let didStartAccess = enabled && directory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                directory.stopAccessingSecurityScopedResource()
            }
        }

        return try operation()
    }
}

#endif
