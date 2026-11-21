import SpriteKit

/// Banderas del trazado de slalom y la línea de meta.
final class SlalomCourseNode: SKNode {
    private var flags: [[SKSpriteNode]] = []

    static let redFlag = PixelArt(rows: [
        "KEEEE",
        "KEEEEE",
        "KEEEE",
        "K",
        "K",
        "K",
        "K",
        "K",
    ], scale: 3)

    static let blueFlag = PixelArt(rows: [
        "KNNNN",
        "KNNNNN",
        "KNNNN",
        "K",
        "K",
        "K",
        "K",
        "K",
    ], scale: 3)

    init(course: SlalomCourse) {
        super.init()
        name = "slalom"
        let factory = SpriteFactory.shared
        for gate in course.gates {
            let art = gate.isRed ? Self.redFlag : Self.blueFlag
            let texture = factory.texture(named: gate.isRed ? "flag-red" : "flag-blue", art: art)
            var pair: [SKSpriteNode] = []
            for (x, mirrored) in [(gate.leftX, true), (gate.rightX, false)] {
                let flag = SKSpriteNode(texture: texture, size: art.size)
                flag.anchorPoint = CGPoint(x: 0.1, y: 0)
                flag.position = CGPoint(x: x, y: gate.y)
                // La tela apunta hacia fuera de la puerta.
                flag.xScale = mirrored ? -1 : 1
                flag.zPosition = Depth.object(atY: gate.y)
                addChild(flag)
                pair.append(flag)
            }
            flags.append(pair)
        }
        addFinishLine(at: course.finishY)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Atenúa las banderas ya pasadas (o falladas) para ver mejor la siguiente.
    func mark(gate index: Int, passed: Bool) {
        guard flags.indices.contains(index) else { return }
        for flag in flags[index] {
            flag.alpha = passed ? 0.35 : 0.2
            if !passed { flag.color = .gray; flag.colorBlendFactor = 0.8 }
        }
    }

    private func addFinishLine(at y: Double) {
        // Franja a cuadros a lo ancho de la pista.
        let squares = 40
        let side: CGFloat = 20
        for i in 0..<squares {
            for row in 0..<2 {
                let dark = (i + row).isMultiple(of: 2)
                let square = SKSpriteNode(
                    color: dark ? SKColor(white: 0.15, alpha: 1) : .white,
                    size: CGSize(width: side, height: side / 2)
                )
                square.position = CGPoint(
                    x: (CGFloat(i) - CGFloat(squares) / 2 + 0.5) * side,
                    y: CGFloat(y) - CGFloat(row) * side / 2
                )
                square.zPosition = Depth.zones
                addChild(square)
            }
        }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "META"
        label.fontSize = 28
        label.fontColor = SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1)
        label.position = CGPoint(x: 0, y: y + 14)
        label.zPosition = Depth.object(atY: CGFloat(y))
        addChild(label)
    }
}

/// Frente de la avalancha: una pared de nieve a lo ancho de la pantalla.
final class AvalancheNode: SKNode {
    private let wall: SKSpriteNode
    private var puffs: [SKShapeNode] = []

    init(width: CGFloat) {
        wall = SKSpriteNode(
            color: SKColor(red: 0.80, green: 0.86, blue: 0.95, alpha: 1),
            size: CGSize(width: width, height: 1200)
        )
        super.init()
        name = "avalanche"
        wall.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(wall)

        // Bolas de nieve en el borde para que se vea irregular.
        var rng = SeededRandom(seed: 99)
        let count = Int(width / 36)
        for i in 0..<count {
            let radius = CGFloat.random(in: 18...34, using: &rng)
            let puff = SKShapeNode(circleOfRadius: radius)
            puff.fillColor = SKColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1)
            puff.strokeColor = SKColor(red: 0.62, green: 0.70, blue: 0.86, alpha: 1)
            puff.lineWidth = 2
            puff.position = CGPoint(x: -width / 2 + CGFloat(i) * 36 + 18, y: CGFloat.random(in: -6...10, using: &rng))
            addChild(puff)
            puffs.append(puff)
        }
        zPosition = Depth.overhead - 5
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Coloca el frente y hace temblar las bolas de nieve.
    func apply(frontY: CGFloat, centerX: CGFloat, time: Double) {
        position = CGPoint(x: centerX, y: frontY)
        for (i, puff) in puffs.enumerated() {
            puff.position.y = CGFloat(sin(time * 9 + Double(i) * 1.7)) * 6
        }
    }
}
