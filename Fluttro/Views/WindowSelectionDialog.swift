//
//  WindowSelectionDialog.swift
//  Fluttro
//
//  Window selection dialog for screenshot capture
//

import Foundation
#if os(macOS)
import AppKit
import ScreenCaptureKit

class WindowSelectionDialog: NSObject {
    private var window: NSWindow?
    private var completion: (SCWindow?) -> Void
    private let windows: [SCWindow]
    
    init(windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        self.windows = windows
        self.completion = completion
        super.init()
    }
    
    func show() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.title = "Wybierz okno do zrzutu"
        panel.level = .floating
        panel.center()
        
        let contentView = WindowSelectionView(windows: windows) { [weak self] selectedWindow in
            self?.close(with: selectedWindow)
        }
        
        panel.contentView = contentView
        self.window = panel
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func close(with window: SCWindow?) {
        self.window?.close()
        self.window = nil
        completion(window)
    }
}

class WindowSelectionView: NSView {
    private let windows: [SCWindow]
    private let completion: (SCWindow?) -> Void
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    
    init(windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        self.windows = windows
        self.completion = completion
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Create table view
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick)
        
        // Create columns
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "Aplikacja"
        appColumn.width = 150
        tableView.addTableColumn(appColumn)
        
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Tytuł okna"
        titleColumn.width = 300
        tableView.addTableColumn(titleColumn)
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        addSubview(scrollView)
        
        // Add instruction label
        let instructionLabel = NSTextField(labelWithString: "Wybierz okno z listy i kliknij 'Wybierz' lub kliknij dwukrotnie na okno")
        instructionLabel.font = NSFont.systemFont(ofSize: 12)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.alignment = .center
        addSubview(instructionLabel)
        
        // Create buttons
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        
        let cancelButton = NSButton(title: "Anuluj", target: self, action: #selector(cancelClicked))
        let selectButton = NSButton(title: "Wybierz", target: self, action: #selector(selectClicked))
        selectButton.keyEquivalent = "\r"
        
        buttonStack.addArrangedSubview(NSView()) // Spacer
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(selectButton)
        
        addSubview(buttonStack)
        
        // Setup constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            instructionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            scrollView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -20),
            
            buttonStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc private func tableViewDoubleClick() {
        selectClicked()
    }
    
    @objc private func selectClicked() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < windows.count else {
            completion(nil)
            return
        }
        
        completion(windows[selectedRow])
    }
    
    @objc private func cancelClicked() {
        completion(nil)
    }
}

extension WindowSelectionView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return windows.count
    }
}

extension WindowSelectionView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < windows.count else { return nil }
        
        let window = windows[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        
        if tableColumn?.identifier.rawValue == "app" {
            textField.stringValue = window.owningApplication?.applicationName ?? "Nieznana"
        } else if tableColumn?.identifier.rawValue == "title" {
            textField.stringValue = window.title ?? "Bez tytułu"
        }
        
        cellView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        cellView.textField = textField
        return cellView
    }
}

#endif