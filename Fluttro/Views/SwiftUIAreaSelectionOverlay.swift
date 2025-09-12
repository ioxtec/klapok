//
//  SwiftUIAreaSelectionOverlay.swift
//  Fluttro
//
//  SwiftUI-based area selection overlay
//

import SwiftUI

#if os(macOS)
    import AppKit

    struct AreaSelectionOverlayView: View {
        let backgroundImage: NSImage
        let onSelection: (NSRect?) -> Void
        @Binding var currentSelection: NSRect

        @State private var startPoint: CGPoint = .zero
        @State private var currentPoint: CGPoint = .zero
        @State private var isDragging = false
        @State private var selectionRect: CGRect = .zero

        var body: some View {
            ZStack {
                // Tło z przezroczystością
                Color.black.opacity(0.3)
                    .ignoresSafeArea(.all)

                // Instrukcje
                VStack {
                    if selectionRect.isEmpty {
                        Text("Przeciągnij, aby wybrać obszar")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    } else {
                        Text("Naciśnij Enter aby potwierdzić lub ESC aby anulować")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.top, 50)

                // Ramka selekcji
                if isDragging || !selectionRect.isEmpty {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.clear)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            startPoint = value.startLocation
                            isDragging = true
                        }
                        currentPoint = value.location
                        updateSelectionRect()
                    }
                    .onEnded { _ in
                        isDragging = false
                        if selectionRect.width > 10 && selectionRect.height > 10 {
                            // Zachowaj selekcję - nie zamykaj od razu overlay
                            print("AreaSelectionOverlayView: Selection completed: \(selectionRect)")

                            // Przekaż selekcję do managera przez binding
                            let nsRect = NSRect(
                                x: selectionRect.minX,
                                y: selectionRect.minY,
                                width: selectionRect.width,
                                height: selectionRect.height
                            )
                            currentSelection = nsRect

                        } else {
                            // Za mały obszar - wyczyść
                            selectionRect = .zero
                        }
                    }
            )
            .onKeyPress(.escape) {
                onSelection(nil)
                return .handled
            }
            .onKeyPress(.return) {
                if !selectionRect.isEmpty {
                    // Potwierdź selekcję
                    let nsRect = NSRect(
                        x: selectionRect.minX,
                        y: selectionRect.minY,
                        width: selectionRect.width,
                        height: selectionRect.height
                    )
                    onSelection(nsRect)
                }
                return .handled
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // NAPRAW: Wymuś pełny rozmiar
        }

        private func updateSelectionRect() {
            let minX = min(startPoint.x, currentPoint.x)
            let minY = min(startPoint.y, currentPoint.y)
            let maxX = max(startPoint.x, currentPoint.x)
            let maxY = max(startPoint.y, currentPoint.y)

            selectionRect = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY
            )
        }
    }

    // Manager dla SwiftUI overlay
    class SwiftUIAreaSelectionManager: ObservableObject {
        @Published var isPresented = false
        private var backgroundImage: NSImage?
        private var completion: ((NSRect?) -> Void)?
        private var overlayWindow: NSWindow?
        private var isHiding = false  // Flaga żeby uniknąć pętli

        func show(backgroundImage: NSImage, completion: @escaping (NSRect?) -> Void) {
            self.backgroundImage = backgroundImage
            self.completion = completion
            self.isPresented = true

            // Twórz osobne okno dla overlay
            createOverlayWindow()
        }

        func hide(with rect: NSRect?) {
            guard !isHiding else {
                print("SwiftUIAreaSelectionManager: Already hiding, avoiding infinite loop")
                return
            }

            isHiding = true
            isPresented = false
            overlayWindow?.close()
            overlayWindow = nil

            let completionToCall = completion
            completion = nil
            backgroundImage = nil

            // Wywołaj completion na końcu i zresetuj flagę
            completionToCall?(rect)
            isHiding = false
        }

        private var currentSelection: NSRect = .zero

        func getCurrentSelection() -> NSRect {
            return currentSelection
        }

        func setCurrentSelection(_ rect: NSRect) {
            currentSelection = rect
        }

        private func createOverlayWindow() {
            print("SwiftUIAreaSelectionManager: createOverlayWindow() called")

            guard let screen = NSScreen.main else {
                print("SwiftUIAreaSelectionManager: ERROR - No main screen found")
                return
            }

            guard let backgroundImage = backgroundImage else {
                print("SwiftUIAreaSelectionManager: ERROR - No background image")
                return
            }

            print("SwiftUIAreaSelectionManager: Screen and image OK, creating SwiftUI view...")

            // Twórz SwiftUI view
            let overlayView = AreaSelectionOverlayView(
                backgroundImage: backgroundImage,
                onSelection: { rect in
                    print(
                        "SwiftUIAreaSelectionManager: Overlay callback called with rect: \(String(describing: rect))"
                    )
                    self.hide(with: rect)
                },
                currentSelection: Binding(
                    get: { self.currentSelection },
                    set: { self.currentSelection = $0 }
                )
            )

            print(
                "SwiftUIAreaSelectionManager: SwiftUI view created, creating hosting controller...")

            // Twórz hosting controller
            let hostingController = NSHostingController(rootView: overlayView)

            print("SwiftUIAreaSelectionManager: Hosting controller created, creating NSWindow...")

            // NAPRAW: Użyj pełnych współrzędnych ekranu
            print("SwiftUIAreaSelectionManager: Screen frame: \(screen.frame)")
            print("SwiftUIAreaSelectionManager: Screen visibleFrame: \(screen.visibleFrame)")

            let fullScreenRect = NSRect(
                x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)
            print("SwiftUIAreaSelectionManager: Using fullScreenRect: \(fullScreenRect)")

            let window = NSPanel(
                contentRect: fullScreenRect,
                styleMask: [.nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            print("SwiftUIAreaSelectionManager: NSPanel created successfully!")

            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.contentViewController = hostingController
            window.acceptsMouseMovedEvents = true
            window.becomesKeyOnlyIfNeeded = false

            overlayWindow = window

            print("SwiftUIAreaSelectionManager: Window configured, setting frame...")

            // NAPRAW: Wymuś rozmiar i pozycję okna
            window.setFrame(fullScreenRect, display: true)
            window.center()  // Wyśrodkuj na ekranie

            print("SwiftUIAreaSelectionManager: Window frame set to: \(window.frame)")
            print("SwiftUIAreaSelectionManager: Showing window...")

            // Pokaż okno BEZ robienia go key window
            window.orderFront(nil)
            // NSApp.activate(ignoringOtherApps: true)  // Może to powoduje problem

            print("SwiftUIAreaSelectionManager: Fullscreen overlay window shown successfully!")
        }

        var overlayView: some View {
            // To już nie jest potrzebne - używamy osobnego okna
            EmptyView()
        }
    }

#endif
