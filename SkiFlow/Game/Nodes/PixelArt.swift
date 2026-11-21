import CoreGraphics
import SpriteKit

/// Un dibujo pixel art descrito como texto: cada carácter es un píxel y `.` es
/// transparente. Sirve de arte provisional hasta tener los packs CC0 (Fase 8).
struct PixelArt: Sendable {
    let rows: [String]
    /// Escala en puntos por píxel.
    var scale: CGFloat = 3
    /// Colores que sustituyen a los de la paleta común (para variantes).
    var overrides: [Character: UInt32] = [:]

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }
    var size: CGSize { CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale) }

    /// Paleta común (0xRRGGBB).
    static let palette: [Character: UInt32] = [
        "G": 0x1E5631, "g": 0x3C8D2F, "B": 0x6B4226, "D": 0x4A2F1B,
        "O": 0xB5651D, "r": 0x9AA0A6, "R": 0x5F6368, "W": 0xFFFFFF,
        "S": 0xDDE7F5, "I": 0xBFE6FF, "i": 0x7FC4F0, "K": 0x1A1B20,
        "N": 0x1F3A93, "E": 0xC0392B, "Y": 0xF4D35E, "T": 0xF2EBDD,
        "t": 0xD9CBB0, "C": 0x4E8F3A, "c": 0x8CC084, "L": 0xB6F21A,
    ]

    func color(for character: Character) -> UInt32? {
        overrides[character] ?? Self.palette[character]
    }

    /// Imagen a 1 píxel por carácter. Se escala con filtrado `nearest`.
    func makeImage() -> CGImage? {
        let w = width, h = height
        guard w > 0, h > 0,
              let context = CGContext(
                  data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, character) in row.enumerated() {
                guard let hex = color(for: character) else { continue }
                context.setFillColor(CGColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                ))
                context.fill(CGRect(x: columnIndex, y: h - 1 - rowIndex, width: 1, height: 1))
            }
        }
        return context.makeImage()
    }
}

/// Crea y cachea las texturas de los objetos de la montaña.
@MainActor
final class SpriteFactory {
    static let shared = SpriteFactory()

    private var cache: [String: SKTexture] = [:]

    func texture(named name: String, art: PixelArt) -> SKTexture {
        if let cached = cache[name] { return cached }
        let texture = art.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }

    /// Sprite con el ancla en la base (centro inferior), como las cajas de choque.
    func sprite(for kind: ObstacleKind) -> SKSpriteNode {
        let art = ObstacleArt.art(for: kind)
        let node = SKSpriteNode(texture: texture(named: kind.rawValue, art: art), size: art.size)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        return node
    }

    func sprite(named name: String, art: PixelArt) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(named: name, art: art), size: art.size)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        return node
    }
}
