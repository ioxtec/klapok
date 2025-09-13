//
//  ScreenshotModels.swift
//  Fluttro
//
//  Core models for screenshot functionality
//

import Foundation

#if os(macOS)
    import AppKit
    import ScreenCaptureKit

    // MARK: - Enums

    enum CaptureMode: CaseIterable {
        case image
        case video

        var iconName: String {
            switch self {
            case .image: return "camera"
            case .video: return "video"
            }
        }

        var title: String {
            switch self {
            case .image: return "Obraz"
            case .video: return "Video"
            }
        }
    }

    enum ScreenshotType: CaseIterable {
        case fullScreen
        case area
        case window

        var iconName: String {
            switch self {
            case .fullScreen: return "rectangle.on.rectangle"
            case .area: return "viewfinder"
            case .window: return "macwindow"
            }
        }

        var title: String {
            switch self {
            case .fullScreen: return "Cały ekran"
            case .area: return "Wycinek"
            case .window: return "Okno"
            }
        }
    }

    enum ScreenshotError: Error {
        case unavailable
        case noDisplays
        case frameConversionFailed
        case userCancelled
        case noWindowSelected
    }

#endif
