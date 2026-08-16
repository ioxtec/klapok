//
//  BackgroundModelsTests.swift
//  KlapokTests
//

import XCTest
@testable import Klapok

#if os(macOS)
import SwiftUI

final class BackgroundModelsTests: XCTestCase {
    func testGradientStopLocationIsClamped() {
        let low = GradientStopData(color: ColorData(color: .red), location: -0.4)
        let high = GradientStopData(color: ColorData(color: .blue), location: 1.8)

        XCTAssertEqual(low.location, 0)
        XCTAssertEqual(high.location, 1)
    }

    func testCustomGradientSortsStopsByLocation() {
        let gradient = CustomGradient(
            name: "Sorted",
            color1: ColorData(color: .red),
            color2: ColorData(color: .blue),
            stops: [
                GradientStopData(color: ColorData(color: .blue), location: 1),
                GradientStopData(color: ColorData(color: .green), location: 0.5),
                GradientStopData(color: ColorData(color: .red), location: 0)
            ]
        )

        XCTAssertEqual(gradient.sortedStops.map(\.location), [0, 0.5, 1])
    }

    func testCustomGradientAddsFallbackStopWhenOnlyOneStopIsProvided() {
        let gradient = CustomGradient(
            name: "One Stop",
            color1: ColorData(color: .red),
            color2: ColorData(color: .blue),
            stops: [
                GradientStopData(color: ColorData(color: .green), location: 0.42)
            ]
        )

        XCTAssertEqual(gradient.sortedStops.count, 2)
        XCTAssertEqual(gradient.sortedStops.map(\.location), [0, 1])
    }

    func testGradientDirectionCGPoints() {
        let size = CGSize(width: 200, height: 100)

        XCTAssertEqual(GradientDirection.leftToRight.cgPoints(in: size).start, CGPoint(x: 0, y: 50))
        XCTAssertEqual(GradientDirection.leftToRight.cgPoints(in: size).end, CGPoint(x: 200, y: 50))
        XCTAssertEqual(GradientDirection.topToBottom.cgPoints(in: size).start, CGPoint(x: 100, y: 100))
        XCTAssertEqual(GradientDirection.topToBottom.cgPoints(in: size).end, CGPoint(x: 100, y: 0))
    }

    func testBackgroundCollectionsSelectedGradientAndImage() {
        let gradient = CustomGradient(
            name: "Selected",
            color1: ColorData(color: .red),
            color2: ColorData(color: .blue)
        )
        let image = BackgroundImage(name: "Paper", fileName: "paper.png")

        var collections = BackgroundCollections()
        collections.customGradients = [gradient]
        collections.backgroundImages = [image]
        collections.selectedGradientId = gradient.id
        collections.selectedImageId = image.id

        XCTAssertEqual(collections.selectedGradient?.id, gradient.id)
        XCTAssertEqual(collections.selectedImage?.id, image.id)
    }

    func testCustomGradientDecodesLegacyGradientWithoutStops() throws {
        let payload = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Legacy",
          "color1": { "red": 1, "green": 0, "blue": 0, "alpha": 1 },
          "color2": { "red": 0, "green": 0, "blue": 1, "alpha": 1 },
          "opacity": 0.75,
          "direction": "Left to Right"
        }
        """

        let gradient = try JSONDecoder().decode(CustomGradient.self, from: Data(payload.utf8))

        XCTAssertEqual(gradient.name, "Legacy")
        XCTAssertEqual(gradient.opacity, 0.75)
        XCTAssertEqual(gradient.direction, .leftToRight)
        XCTAssertEqual(gradient.sortedStops.count, 2)
        XCTAssertEqual(gradient.sortedStops.map(\.location), [0, 1])
    }
}

#endif
