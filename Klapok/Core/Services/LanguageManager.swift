//
//  LanguageManager.swift
//  Klapok
//
//  Language management for app localization
//

import Foundation
import SwiftUI

/// Available app languages
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case polish = "pl"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case portugueseBrazil = "pt-BR"
    case japanese = "ja"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .polish:
            return "Polski"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        case .portugueseBrazil: return "Português (Brasil)"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
    
    var locale: Locale? {
        switch self {
        case .system:
            return nil // Use system locale
        default:
            return Locale(identifier: rawValue)
        }
    }

    var formattingLocale: Locale { locale ?? .autoupdatingCurrent }

    func formatFileSize(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file).locale(formattingLocale))
    }

    func formatCreationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = formattingLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Language manager for handling app language selection
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "app_language")
            applyLanguage()
        }
    }
    
    private init() {
        // Load saved language or default to system
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "system"
        self.selectedLanguage = AppLanguage(rawValue: savedLanguage) ?? .system
        applyLanguage()
    }
    
    /// Apply the selected language to the app
    private func applyLanguage() {
        Bundle.setLanguage(currentLanguage)
        
        // Swizzle Bundle.main to use our custom localization
        object_setClass(Bundle.main, AnyLanguageBundle.self)
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    /// Get current effective language (either selected or system)
    var currentLanguage: String {
        if selectedLanguage == .system {
            let supported = AppLanguage.allCases.filter { $0 != .system }.map(\.rawValue)
            return Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages).first ?? "en"
        }
        return selectedLanguage.rawValue
    }
}

// MARK: - Bundle Extension for Language Switching
extension Bundle {
    static var currentLanguageBundle: Bundle?
    
    static var localizedBundle: Bundle? {
        return currentLanguageBundle
    }
    
    static func setLanguage(_ language: String?) {
        if let language = language {
            guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else {
                currentLanguageBundle = nil
                return
            }
            currentLanguageBundle = localizedBundle
        } else {
            currentLanguageBundle = nil
        }
    }
}

// MARK: - Custom Bundle Class for Language Switching
class AnyLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // Get the localized bundle directly without going through Bundle.localizedBundle()
        // to avoid recursion
        if let localizedBundle = Bundle.currentLanguageBundle {
            return localizedBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        
        // Fallback to super implementation
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - String Extension for Language-aware Localization
extension String {
    /// Get localized string that respects current app language
    var localizedForApp: String {
        if let localizedBundle = Bundle.localizedBundle {
            return localizedBundle.localizedString(forKey: self, value: nil, table: nil)
        }
        return NSLocalizedString(self, comment: "")
    }
}
