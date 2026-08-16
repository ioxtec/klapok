//
//  Logger.swift
//  Klapok
//
//  Created by Marcin Ryzko on 13/09/2025.
//

import Foundation

enum LogType {
    case debug
    case info
    case warning
    case error
    case success
}

class Logger {
    // MARK: - Main logging method
    static func log(_ message: String, type: LogType) {
        let prefix: String
        switch type {
        case .debug:
            prefix = "🔍"
        case .info:
            prefix = "🔹"
        case .warning:
            prefix = "⚠️"
        case .error:
            prefix = "❌"
        case .success:
            prefix = "✅"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let currentTime = timeFormatter.string(from: Date())

        print("[\(currentTime)] \(prefix) \(message)")
    }

    // MARK: - Convenience methods
    static func d(_ message: String) {
        log(message, type: .debug)
    }

    static func i(_ message: String) {
        log(message, type: .info)
    }

    static func w(_ message: String) {
        log(message, type: .warning)
    }

    static func e(_ message: String) {
        log(message, type: .error)
    }

    static func s(_ message: String) {
        log(message, type: .success)
    }

    // MARK: - Debug convenience methods
    static func debug(_ message: String) {
        d(message)
    }

    static func info(_ message: String) {
        i(message)
    }

    static func warning(_ message: String) {
        w(message)
    }

    static func error(_ message: String) {
        e(message)
    }

    static func success(_ message: String) {
        s(message)
    }
}
