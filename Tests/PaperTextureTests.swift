@testable import DailyHangul
import UIKit
import XCTest

/// Sichert die kachelbare Papier-Linierung aus Issue #140 ab: `PaperTexture` rendert die
/// Linien nicht mehr pro Canvas-Pass als ~N/4 Rects, sondern einmal als 1×4pt-Kachel, die
/// das System tilt. Die Tests fixieren Kachelgröße, Linienfarbe und das 1pt-Linie-/3pt-Lücke-
/// Raster, damit die Optik identisch bleibt.
final class PaperTextureTests: XCTestCase {

    /// Die Kachel hat die Punktgröße des Linienrasters: 1pt breit, 4pt hoch (1pt Linie + 3pt Lücke).
    func testTileHasRasterPitchSize() {
        let tile = PaperTexture.makeTile()
        XCTAssertEqual(tile.size.width, 1, accuracy: 0.001)
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

    /// Genau 1pt (= `scale` Pixelzeilen) trägt Tinte, der Rest (3pt) ist transparent – so
    /// ergibt die Kachelung die ursprüngliche 1pt-Linie alle 4pt. Geprüft wird nur die Anzahl
    /// inked/transparenter Zeilen, nicht ihre Position (robust gegen Koordinaten-Flip).
    func testTileHasOnePointInkLineAndTransparentGap() throws {
        let tile = PaperTexture.makeTile()
        let cg = try XCTUnwrap(tile.cgImage, "Kachel sollte ein CGImage haben")
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

        // Alpha der jeweils ersten Spalte je Pixelzeile einsammeln.
        let rowAlphas = (0 ..< height).map { row in pixels[(row * width) * 4 + 3] }
        let inkedRows = rowAlphas.filter { $0 > 0 }.count
        let transparentRows = rowAlphas.filter { $0 == 0 }.count

        let scale = Int(tile.scale.rounded())
        XCTAssertEqual(height, scale * 4, "Kachel ist 4pt hoch")
        XCTAssertEqual(inkedRows, scale, "genau 1pt Linie trägt Tinte")
        XCTAssertEqual(transparentRows, scale * 3, "3pt Lücke sind transparent")
    }
}
