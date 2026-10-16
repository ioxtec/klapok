import AppKit
import Combine

enum AppIconChoice: String, CaseIterable, Identifiable {
    case roostersLight, roostersDark, flowerLight, flowerDark

    var id: String { rawValue }

    var resourceName: String {
        switch self {
        case .roostersLight: return "KlapokPaper"
        case .roostersDark: return "KlapokRoostersDark"
        case .flowerLight: return "KlapokFlowerLight"
        case .flowerDark: return "KlapokFlowerDark"
        }
    }

    var title: String {
        switch self {
        case .roostersLight: return "Roosters · Light".localized
        case .roostersDark: return "Roosters · Dark".localized
        case .flowerLight: return "Flowers · Light".localized
        case .flowerDark: return "Flowers · Dark".localized
        }
    }

    func image(in bundle: Bundle = .main) -> NSImage? {
        // Asset-catalog images are full bleed; compiled ICNS files include Apple's icon mask.
        guard let url = bundle.url(forResource: resourceName, withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }
}

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()
    static let preferenceKey = "dockIconChoice"

    @Published private(set) var selection: AppIconChoice
    private let defaults: UserDefaults
    private let imageProvider: (AppIconChoice) -> NSImage?
    private let applyImage: @MainActor (NSImage?) -> Void

    init(defaults: UserDefaults = .standard,
         imageProvider: @escaping (AppIconChoice) -> NSImage? = { $0.image() },
         applyImage: @escaping @MainActor (NSImage?) -> Void = { NSApp.applicationIconImage = $0 }) {
        self.defaults = defaults
        self.imageProvider = imageProvider
        self.applyImage = applyImage
        selection = defaults.string(forKey: Self.preferenceKey).flatMap(AppIconChoice.init(rawValue:)) ?? .roostersLight
    }

    @discardableResult
    func select(_ choice: AppIconChoice) -> Bool {
        let image = choice == .roostersLight ? nil : imageProvider(choice)
        guard choice == .roostersLight || image != nil else { return false }
        applyImage(image)
        selection = choice
        defaults.set(choice.rawValue, forKey: Self.preferenceKey)
        return true
    }

    func applySavedIcon() {
        // This changes only the running application's Dock tile, never its signed bundle.
        if !select(selection) { select(.roostersLight) }
    }
}
