import SpriteKit

/// Motas de nieve repartidas por el fondo que se reciclan alrededor de la cámara.
/// Dan sensación de movimiento mientras no hay obstáculos (Fase 2).
final class SnowSpeckleNode: SKNode {
    private let area: CGSize
    private var speckles: [SKSpriteNode] = []

    init(area: CGSize, count: Int = 120, seed: UInt64 = 2026) {
        self.area = area
        super.init()
        var rng = SeededRandom(seed: seed)
        for _ in 0..<count {
            let shade = CGFloat.random(in: 0.82...0.92, using: &rng)
            let side = CGFloat.random(in: 2...4, using: &rng).rounded()
            let speckle = SKSpriteNode(
                color: SKColor(red: shade, green: shade + 0.04, blue: 1, alpha: 1),
                size: CGSize(width: side, height: side)
            )
            speckle.position = CGPoint(
                x: CGFloat.random(in: -area.width / 2...area.width / 2, using: &rng),
                y: CGFloat.random(in: -area.height / 2...area.height / 2, using: &rng)
            )
            speckles.append(speckle)
            addChild(speckle)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Envuelve las motas que salen del área centrada en `center`.
    func wrap(around center: CGPoint) {
        let halfW = area.width / 2
        let halfH = area.height / 2
        for speckle in speckles {
            var p = speckle.position
            while p.x < center.x - halfW { p.x += area.width }
            while p.x > center.x + halfW { p.x -= area.width }
            while p.y < center.y - halfH { p.y += area.height }
            while p.y > center.y + halfH { p.y -= area.height }
            speckle.position = p
        }
    }
}
