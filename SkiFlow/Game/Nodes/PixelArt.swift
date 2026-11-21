import CoreGraphics
import SpriteKit

/// Un dibujo pixel art descrito como texto: cada carácter es un píxel y `.` es
/// transparente. Así están hechos los sprites propios (lo andino, el Kunk, el
/// Chupacabras…), que conviven con los tiles CC0 de Kenney.
struct PixelArt: Sendable {
    /// Color del contorno de los tiles de Kenney, para que todo combine.
    static let outlineColor: UInt32 = 0x3F2631

    let rows: [String]
    /// Escala en puntos por píxel.
    var scale: CGFloat = GameConfig.pixelScale
    /// Colores que sustituyen a los de la paleta común (para variantes).
    var overrides: [Character: UInt32] = [:]
    /// Añade un contorno oscuro de 1 píxel alrededor del dibujo.
    var outlined = true

    private var margin: Int { outlined ? 1 : 0 }
    var width: Int { (rows.map(\.count).max() ?? 0) + 2 * margin }
    var height: Int { rows.count + 2 * margin }
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

    /// Colores por píxel (fila 0 arriba), con el contorno ya aplicado.
    func pixels() -> [[UInt32?]] {
        let w = width, h = height, m = margin
        var grid = [[UInt32?]](repeating: [UInt32?](repeating: nil, count: w), count: h)
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, character) in row.enumerated() {
                grid[rowIndex + m][columnIndex + m] = color(for: character)
            }
        }
        guard outlined else { return grid }
        var result = grid
        for y in 0..<h {
            for x in 0..<w where grid[y][x] == nil {
                let touches = (-1...1).contains { dy in
                    (-1...1).contains { dx in
                        let ny = y + dy, nx = x + dx
                        return ny >= 0 && ny < h && nx >= 0 && nx < w && grid[ny][nx] != nil
                    }
                }
                if touches { result[y][x] = Self.outlineColor }
            }
        }
        return result
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

        for (rowIndex, row) in pixels().enumerated() {
            for (columnIndex, color) in row.enumerated() {
                guard let hex = color else { continue }
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

/// Tiles CC0 de «Tiny Ski» (Kenney) que usa el juego. Están en el atlas
/// `Kenney.spriteatlas`. Los tiles del yeti del pack no se usan a propósito:
/// el perseguidor de SkiFlow es el Kunk, de diseño propio.
enum KenneySprite: String, CaseIterable, Sendable {
    case flagRed = "flag_red"
    case flagBlue = "flag_blue"
    case snowman
    case rock = "rock_kenney"
    case liftChair = "lift_chair"

    /// Todos los tiles miden 16 × 16 píxeles.
    static let tileSize: CGFloat = 16

    var size: CGSize {
        CGSize(width: Self.tileSize * GameConfig.pixelScale, height: Self.tileSize * GameConfig.pixelScale)
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
    /// - Parameter variant: para elegir entre aspectos (por ejemplo, la ropa de
    ///   los otros esquiadores).
    func sprite(for kind: ObstacleKind, variant: Int = 0) -> SKSpriteNode {
        switch kind {
        case .rock:
            return sprite(.rock)
        case .snowman:
            return sprite(.snowman)
        default:
            break
        }
        let art = ObstacleArt.art(for: kind)
        let node = SKSpriteNode(texture: texture(named: kind.rawValue, art: art), size: art.size)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        return node
    }

    /// Textura de un tile de Kenney (con filtrado `nearest`).
    func texture(_ sprite: KenneySprite) -> SKTexture {
        let key = "kenney-" + sprite.rawValue
        if let cached = cache[key] { return cached }
        let texture = SKTexture(imageNamed: sprite.rawValue)
        texture.filteringMode = .nearest
        cache[key] = texture
        return texture
    }

    /// Sprite de Kenney con el ancla en la base.
    func sprite(_ kenney: KenneySprite) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(kenney), size: kenney.size)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        return node
    }

    func sprite(named name: String, art: PixelArt) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(named: name, art: art), size: art.size)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        return node
    }
}
