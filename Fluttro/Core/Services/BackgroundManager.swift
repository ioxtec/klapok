//
//  BackgroundManager.swift
//  Fluttro
//
//  Manager for custom background gradients and images
//

import Foundation
import SwiftUI
import AppKit

class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()
    
    @Published var collections = BackgroundCollections()
    
    private let documentsPath: URL
    private let backgroundImagesPath: URL
    
    private init() {
        self.documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.backgroundImagesPath = documentsPath.appendingPathComponent("Fluttro Background Images")
        
        createDirectoriesIfNeeded()
        loadCollections()
        createDefaultGradientsIfNeeded()
    }
    
    // Public initializer for previews
    init(forPreview: Bool) {
        self.documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.backgroundImagesPath = documentsPath.appendingPathComponent("Fluttro Background Images")
        
        if forPreview {
            // For previews, create minimal collections without file operations
            let defaultGradients = BackgroundManager.createDefaultGradients()
            self.collections = BackgroundCollections()
            self.collections.customGradients = defaultGradients
            self.collections.backgroundImages = []
            self.collections.backgroundType = .gradient
            self.collections.selectedGradientId = defaultGradients.first?.id
            self.collections.selectedImageId = nil
        } else {
            createDirectoriesIfNeeded()
            loadCollections()
            createDefaultGradientsIfNeeded()
        }
    }
    
    // MARK: - Directory Management
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: backgroundImagesPath, withIntermediateDirectories: true)
    }
    
    // MARK: - Persistence
    
    func saveCollections() {
        let url = documentsPath.appendingPathComponent("background_collections.json")
        do {
            let data = try JSONEncoder().encode(collections)
            try data.write(to: url)
        } catch {
            print("BackgroundManager: Failed to save collections: \(error)")
        }
    }
    
    private func loadCollections() {
        let url = documentsPath.appendingPathComponent("background_collections.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            collections = try JSONDecoder().decode(BackgroundCollections.self, from: data)
        } catch {
            print("BackgroundManager: Failed to load collections: \(error)")
        }
    }
    
    // MARK: - Default Gradients
    
    static func createDefaultGradients() -> [CustomGradient] {
        return [
            CustomGradient(
                name: "Cool Blue",
                color1: ColorData(color: Color(red: 0.2, green: 0.6, blue: 1.0)),
                color2: ColorData(color: Color(red: 0.0, green: 0.3, blue: 0.8))
            ),
            CustomGradient(
                name: "Warm Orange",
                color1: ColorData(color: Color(red: 1.0, green: 0.6, blue: 0.2)),
                color2: ColorData(color: Color(red: 0.8, green: 0.3, blue: 0.0))
            ),
            CustomGradient(
                name: "Purple Dream",
                color1: ColorData(color: Color(red: 0.6, green: 0.2, blue: 1.0)),
                color2: ColorData(color: Color(red: 0.3, green: 0.0, blue: 0.8))
            ),
            CustomGradient(
                name: "Green Nature",
                color1: ColorData(color: Color(red: 0.2, green: 0.8, blue: 0.4)),
                color2: ColorData(color: Color(red: 0.0, green: 0.5, blue: 0.2))
                )
            ]
    }
    
    private func createDefaultGradientsIfNeeded() {
        if collections.customGradients.isEmpty {
            let defaultGradients = BackgroundManager.createDefaultGradients()
            collections.customGradients = defaultGradients
            collections.selectedGradientId = defaultGradients.first?.id
            saveCollections()
        }
    }
    
    // MARK: - Gradient Management
    
    func addCustomGradient(_ gradient: CustomGradient) {
        collections.customGradients.append(gradient)
        saveCollections()
    }
    
    func updateCustomGradient(_ gradient: CustomGradient) {
        if let index = collections.customGradients.firstIndex(where: { $0.id == gradient.id }) {
            collections.customGradients[index] = gradient
            saveCollections()
        }
    }
    
    func deleteCustomGradient(withId id: UUID) {
        collections.customGradients.removeAll { $0.id == id }
        if collections.selectedGradientId == id {
            collections.selectedGradientId = collections.customGradients.first?.id
        }
        saveCollections()
    }
    
    func selectGradient(withId id: UUID) {
        collections.selectedGradientId = id
        collections.backgroundType = .gradient
        saveCollections()
    }
    
    // MARK: - Background Image Management
    
    func addBackgroundImage(_ image: BackgroundImage, imageData: Data) {
        // Save image file
        let imageURL = backgroundImagesPath.appendingPathComponent(image.fileName)
        do {
            try imageData.write(to: imageURL)
            collections.backgroundImages.append(image)
            saveCollections()
        } catch {
            print("BackgroundManager: Failed to save background image: \(error)")
        }
    }
    
    func updateBackgroundImage(_ image: BackgroundImage) {
        if let index = collections.backgroundImages.firstIndex(where: { $0.id == image.id }) {
            collections.backgroundImages[index] = image
            saveCollections()
        }
    }
    
    func deleteBackgroundImage(withId id: UUID) {
        if let image = collections.backgroundImages.first(where: { $0.id == id }) {
            // Delete image file
            let imageURL = backgroundImagesPath.appendingPathComponent(image.fileName)
            try? FileManager.default.removeItem(at: imageURL)
            
            collections.backgroundImages.removeAll { $0.id == id }
            if collections.selectedImageId == id {
                collections.selectedImageId = collections.backgroundImages.first?.id
            }
            saveCollections()
        }
    }
    
    func selectImage(withId id: UUID) {
        collections.selectedImageId = id
        collections.backgroundType = .image
        saveCollections()
    }
    
    // MARK: - Background Type Management
    
    func setBackgroundType(_ type: BackgroundType) {
        collections.backgroundType = type
    }
    
    // MARK: - Import/Export
    
    func importBackgroundImage(from url: URL) -> Bool {
        do {
            let imageData = try Data(contentsOf: url)
            let fileName = "\(UUID().uuidString).\(url.pathExtension)"
            let name = url.deletingPathExtension().lastPathComponent
            
            let backgroundImage = BackgroundImage(
                name: name,
                fileName: fileName
            )
            
            addBackgroundImage(backgroundImage, imageData: imageData)
            return true
        } catch {
            print("BackgroundManager: Failed to import background image: \(error)")
            return false
        }
    }
    
    func exportCollections() -> URL? {
        let url = documentsPath.appendingPathComponent("fluttro_backgrounds_\(Date().timeIntervalSince1970).json")
        do {
            let data = try JSONEncoder().encode(collections)
            try data.write(to: url)
            return url
        } catch {
            print("BackgroundManager: Failed to export collections: \(error)")
            return nil
        }
    }
    
    func importCollections(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let importedCollections = try JSONDecoder().decode(BackgroundCollections.self, from: data)
            
            // Merge with existing collections
            collections.customGradients.append(contentsOf: importedCollections.customGradients)
            collections.backgroundImages.append(contentsOf: importedCollections.backgroundImages)
            
            saveCollections()
            return true
        } catch {
            print("BackgroundManager: Failed to import collections: \(error)")
            return false
        }
    }
}
