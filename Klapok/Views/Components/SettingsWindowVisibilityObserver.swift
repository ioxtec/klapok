import SwiftUI
import AppKit

/// Window lifetime is more precise than SwiftUI appearance for retained settings windows.
struct SettingsWindowVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) { nsView.onChange = onChange }
    static func dismantleNSView(_ nsView: ObserverView, coordinator: ()) { nsView.detach() }

    final class ObserverView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observers: [NSObjectProtocol] = []
        private var previousVisibility: Bool?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            detach()
            guard let window else { return }
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didMiniaturizeNotification,
                         NSWindow.didDeminiaturizeNotification, NSWindow.didChangeOcclusionStateNotification,
                         NSWindow.willCloseNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        self?.report(closing: note.name == NSWindow.willCloseNotification)
                    }
                })
            }
            DispatchQueue.main.async { [weak self] in self?.report() }
        }

        private func report(closing: Bool = false) {
            let visible = !closing && window?.isVisible == true && window?.isMiniaturized == false
            guard previousVisibility != visible else { return }
            previousVisibility = visible
            onChange?(visible)
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            if previousVisibility == true { onChange?(false) }
            previousVisibility = nil
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
