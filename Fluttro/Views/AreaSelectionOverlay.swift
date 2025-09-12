//
//  AreaSelectionOverlay.swift
//  Fluttro
//
//  Area selection overlay for screenshot capture
//

import Foundation

#if os(macOS)
    import AppKit

    class AreaSelectionOverlay: NSObject {
        private var window: NSWindow?
        private var backgroundImage: NSImage
        private var completion: (NSRect?) -> Void
        private var startPoint: NSPoint?
        private var currentRect: NSRect = .zero
        private var overlayView: AreaSelectionView?

        // Static reference to pre-created window
        static var sharedOverlayWindow: NSWindow?
        private var isClosing: Bool = false

        init(backgroundImage: NSImage, completion: @escaping (NSRect?) -> Void) {
            self.backgroundImage = backgroundImage
            self.completion = completion
            super.init()
        }

        deinit {
            print("AreaSelectionOverlay: deinit called")
            if !isClosing {
                overlayView?.delegate = nil
                window?.contentView = nil
                window?.close()
                window = nil
                overlayView = nil
            }
        }

        func show() {
            print("AreaSelectionOverlay: show() called - BYPASSING WINDOW CREATION FOR NOW")

            // TYMCZASOWO: Nie tworzymy okna wcale - tylko symulujemy że overlay istnieje
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print(
                    "AreaSelectionOverlay: Simulating overlay existence without creating NSWindow")
                // Nie wywołujemy completion - niech FloatingPanelViewModel myśli że overlay istnieje
            }
        }

        func close(with rect: NSRect?) {
            guard !isClosing else {
                print("AreaSelectionOverlay: already closing, ignoring")
                return
            }

            isClosing = true
            print("AreaSelectionOverlay: closing with rect: \(String(describing: rect))")

            // Wyczyść delegate przed zamknięciem
            overlayView?.delegate = nil

            // Usuń view z okna
            window?.contentView = nil

            // Zamknij okno
            window?.close()
            window = nil
            overlayView = nil

            completion(rect)
            print("AreaSelectionOverlay: completion called and cleanup completed")
        }

        // Metoda do pobierania aktualnie zaznaczonego obszaru
        func getCurrentSelection() -> NSRect {
            return overlayView?.getCurrentSelection() ?? .zero
        }

        // Metoda do zamykania bez wywoływania callback (dla ręcznego zamykania)
        func closeWithoutCallback() {
            guard !isClosing else {
                print("AreaSelectionOverlay: already closing, ignoring closeWithoutCallback")
                return
            }

            isClosing = true
            print("AreaSelectionOverlay: closing without callback")

            // Wyczyść delegate przed zamknięciem
            overlayView?.delegate = nil

            // Usuń view z okna
            window?.contentView = nil

            // Zamknij okno
            window?.close()
            window = nil
            overlayView = nil

            print("AreaSelectionOverlay: cleanup completed")
            // NIE wywołujemy completion(rect)
        }

        private func closeInternal(with rect: NSRect?) {
            close(with: rect)
        }
    }

    extension AreaSelectionOverlay: AreaSelectionViewDelegate {
        func areaSelectionView(_ view: AreaSelectionView, didSelectArea rect: NSRect) {
            print("AreaSelectionOverlay: didSelectArea called with rect: \(rect)")
            closeInternal(with: rect)
        }

        func areaSelectionViewDidCancel(_ view: AreaSelectionView) {
            print("AreaSelectionOverlay: didCancel called")
            closeInternal(with: nil)
        }
    }

    protocol AreaSelectionViewDelegate: AnyObject {
        func areaSelectionView(_ view: AreaSelectionView, didSelectArea rect: NSRect)
        func areaSelectionViewDidCancel(_ view: AreaSelectionView)
    }

    class AreaSelectionView: NSView {
        weak var delegate: AreaSelectionViewDelegate?
        private let backgroundImage: NSImage
        private var startPoint: NSPoint?
        private var currentRect: NSRect = .zero
        private var isSelecting = false

        init(frame: NSRect, backgroundImage: NSImage) {
            self.backgroundImage = backgroundImage
            super.init(frame: frame)
            setupView()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            print("AreaSelectionView: deinit called")
            delegate = nil
        }

        private func setupView() {
            wantsLayer = true

            // Add instructions label
            let instructionLabel = NSTextField(
                labelWithString: "Przeciągnij, aby wybrać obszar. Naciśnij ESC, aby anulować.")
            instructionLabel.textColor = .white
            instructionLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
            instructionLabel.font = NSFont.systemFont(ofSize: 16)
            instructionLabel.alignment = .center
            instructionLabel.sizeToFit()

            let labelFrame = NSRect(
                x: (bounds.width - instructionLabel.frame.width) / 2,
                y: bounds.height - 100,
                width: instructionLabel.frame.width + 20,
                height: instructionLabel.frame.height + 10
            )
            instructionLabel.frame = labelFrame
            addSubview(instructionLabel)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            // Draw dimmed background
            NSColor.black.withAlphaComponent(0.3).setFill()
            bounds.fill()

            // Draw selection rectangle
            if !currentRect.isEmpty {
                // Clear the selected area
                NSColor.clear.setFill()
                currentRect.fill()

                // Draw selection border
                NSColor.systemBlue.setStroke()
                let borderPath = NSBezierPath(rect: currentRect)
                borderPath.lineWidth = 2
                borderPath.stroke()

                // Draw corner handles
                drawCornerHandles(for: currentRect)
            }
        }

        private func drawCornerHandles(for rect: NSRect) {
            let handleSize: CGFloat = 8
            let handleColor = NSColor.systemBlue

            let corners = [
                NSPoint(x: rect.minX, y: rect.minY),
                NSPoint(x: rect.maxX, y: rect.minY),
                NSPoint(x: rect.minX, y: rect.maxY),
                NSPoint(x: rect.maxX, y: rect.maxY),
            ]

            handleColor.setFill()
            for corner in corners {
                let handleRect = NSRect(
                    x: corner.x - handleSize / 2,
                    y: corner.y - handleSize / 2,
                    width: handleSize,
                    height: handleSize
                )
                NSBezierPath(ovalIn: handleRect).fill()
            }
        }

        override func mouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)

            // Rozpocznij nowe zaznaczanie
            startPoint = point
            currentRect = NSRect(origin: point, size: .zero)
            isSelecting = true
            needsDisplay = true
        }

        override func mouseDragged(with event: NSEvent) {
            guard let startPoint = startPoint else { return }

            let currentPoint = convert(event.locationInWindow, from: nil)

            let minX = min(startPoint.x, currentPoint.x)
            let minY = min(startPoint.y, currentPoint.y)
            let maxX = max(startPoint.x, currentPoint.x)
            let maxY = max(startPoint.y, currentPoint.y)

            currentRect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            needsDisplay = true
        }

        override func mouseUp(with event: NSEvent) {
            guard isSelecting else { return }

            isSelecting = false

            // Po zakończeniu przeciągania, tylko zapisz obszar (nie wywołuj delegate)
            if currentRect.width > 10 && currentRect.height > 10 {
                print("Zaznaczono obszar: \(currentRect)")
                needsDisplay = true
            } else {
                // Obszar za mały - wyczyść
                currentRect = .zero
                needsDisplay = true
            }
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 {  // ESC key
                delegate?.areaSelectionViewDidCancel(self)
            } else {
                super.keyDown(with: event)
            }
        }

        override var acceptsFirstResponder: Bool {
            return true
        }

        override func becomeFirstResponder() -> Bool {
            print("AreaSelectionView: becomeFirstResponder")
            return super.becomeFirstResponder()
        }

        // Metoda do pobierania aktualnie zaznaczonego obszaru
        func getCurrentSelection() -> NSRect {
            return currentRect
        }
    }

#endif
