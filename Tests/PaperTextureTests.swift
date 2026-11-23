@testable import DailyHangul
import SwiftUI
import UIKit
import XCTest

/// Sichert die kachelbare Papier-Linierung aus Issue #140 ab: `PaperTexture` rendert die
/// Linien nicht mehr pro Canvas-Pass als ~N/4 Rects, sondern einmal als 64×4pt-Kachel, die
/// das System kachelt. Die Tests fixieren Kachelgröße, Linienfarbe, die Lage der 1pt-Linie
/// in der Kachel und dass `PaperTexture` tatsächlich kachelt und oben bei y=0 beginnt.
@MainActor
final class PaperTextureTests: XCTestCase {

    /// Die Kachel ist 4pt hoch (1pt Linie + 3pt Lücke) und breit genug für wenige Kacheln.
    func testTileHasRasterPitchSize() {
        let tile = PaperTexture.makeTile()
        XCTAssertEqual(tile.size.width, 64, accuracy: 0.001)
        XCTAssertEqual(tile.size.height, 4, accuracy: 0.001)
    }

    /// Die Linienfarbe entspricht der Tinte `#211E19` bei 2,2 % Deckkraft (gleiche Quelle
    /// wie `Color(hex:)`, damit Darstellung und Kachel nicht auseinanderlaufen).
    func testLineColorMatchesInkHexAndOpacity() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        PaperTexture.lineColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, CGFloat(0x21) / 255, accuracy: 0.004)
        XCTAssertEqual(g, CGFloat(0x1E) / 255, accuracy: 0.004)
        XCTAssertEqual(b, CGFloat(0x19) / 255, accuracy: 0.004)
        XCTAssertEqual(a, 0.022, accuracy: 0.001)
    }

    /// Die oberste 1pt (= `scale` Pixelzeilen) trägt Tinte, die 3pt darunter sind transparent –
    /// so ergibt die Kachelung die ursprüngliche 1pt-Linie bei y = 0, 4, 8 …
    func testTileHasInkLineAtTopAndTransparentGapBelow() throws {
        let tile = PaperTexture.makeTile()
        let cg = try XCTUnwrap(tile.cgImage, "Kachel sollte ein CGImage haben")
        let scale = Int(tile.scale.rounded())
        XCTAssertEqual(cg.height, scale * 4, "Kachel ist 4pt hoch")

        let alphas = try Self.rowAlphas(of: cg)
        XCTAssertEqual(alphas, Self.expectedRows(pixelHeight: cg.height, scale: scale))
    }

    /// `PaperTexture` kachelt (statt die Kachel zu strecken) und beginnt oben bei y=0 – auch
    /// bei einer Höhe, die kein Vielfaches von 4pt ist (10pt → Linien bei 0, 4, 8).
    func testRenderedTextureTilesFromTop() throws {
        let renderer = ImageRenderer(content: PaperTexture().frame(width: 8, height: 10))
        renderer.scale = 2
        renderer.isOpaque = false
        let cg = try XCTUnwrap(renderer.cgImage, "PaperTexture sollte rendern")
        XCTAssertEqual(cg.height, 20)

        let alphas = try Self.rowAlphas(of: cg)
        XCTAssertEqual(alphas, Self.expectedRows(pixelHeight: cg.height, scale: 2))
    }

    // MARK: - Helpers

    /// Erwartetes Muster je Pixelzeile: `true` = Tinte (erste Punktzeile jedes 4pt-Rasters).
    private static func expectedRows(pixelHeight: Int, scale: Int) -> [Bool] {
        (0 ..< pixelHeight).map { ($0 / scale) % 4 == 0 }
    }

    /// Je Pixelzeile (oben → unten), ob die erste Spalte Tinte trägt (Alpha > 0).
    /// Der Bitmap-Puffer liegt zeilenweise von oben nach unten, das Bild wird aufrecht gezeichnet.
    private static func rowAlphas(of cg: CGImage) throws -> [Bool] {
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (0 ..< height).map { row in pixels[(row * width) * 4 + 3] > 0 }
    }
}
