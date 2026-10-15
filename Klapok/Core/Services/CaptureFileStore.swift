//
//  CaptureFileStore.swift
//  Klapok
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
        let jpeg = ["jpg", "jpeg"].contains(fileURL.pathExtension.lowercased())
        guard let pngData = nativeBitmap(from: image)?.representation(using: jpeg ? .jpeg : .png,
            properties: jpeg ? [.compressionFactor: 0.95] : [:]) else {
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
                let requestedURL = directory.appendingPathComponent(fileName)
                if sourceURL.standardizedFileURL == requestedURL.standardizedFileURL {
                    return CaptureFileStoreResult(url: requestedURL, directory: directory)
                }
                var destinationURL = requestedURL
                var suffix = 2
                while FileManager.default.fileExists(atPath: destinationURL.path) {
                    destinationURL = directory.appendingPathComponent(
                        "\(requestedURL.deletingPathExtension().lastPathComponent)-\(suffix)"
                    ).appendingPathExtension(requestedURL.pathExtension)
                    suffix += 1
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
        nativeBitmap(from: image)?.representation(using: .png, properties: [:])
    }

    static func nativeBitmap(from image: NSImage) -> NSBitmapImageRep? {
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }) {
            return bitmap
        }
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmapRep
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
