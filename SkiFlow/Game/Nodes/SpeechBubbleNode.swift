import SpriteKit

/// Bocadillo de cómic con texto en fuente pixel. Se muestra unos segundos y se
/// desvanece. Lo usan el Cuico y los rivales.
final class SpeechBubbleNode: SKNode {
    private static let ink = SKColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1)
    private static let outline = SKColor(
        red: CGFloat((PixelArt.outlineColor >> 16) & 0xFF) / 255,
        green: CGFloat((PixelArt.outlineColor >> 8) & 0xFF) / 255,
        blue: CGFloat(PixelArt.outlineColor & 0xFF) / 255,
        alpha: 1
    )

    /// Texto que se muestra ahora (o el último).
    private(set) var text: String?

    override init() {
        super.init()
        zPosition = 50
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Muestra `text` a `height` puntos por encima del personaje.
    func show(_ text: String, height: CGFloat, duration: Double = 2.2) {
        self.text = text
        removeAllActions()
        removeAllChildren()

        let label = SKLabelNode(fontNamed: PixelFont.name)
        label.text = text
        label.fontSize = 16
        label.fontColor = Self.ink
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let width = label.frame.width + 20
        let box = SKShapeNode(rectOf: CGSize(width: width, height: 30), cornerRadius: 6)
        box.fillColor = .white
        box.strokeColor = Self.outline
        box.lineWidth = 3
        let tail = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        tail.fillColor = .white
        tail.strokeColor = .clear
        tail.position = CGPoint(x: -width / 2 + 18, y: -16)
        tail.zRotation = .pi / 4

        addChild(tail)
        addChild(box)
        addChild(label)
        position = CGPoint(x: width / 2 - 14, y: height)
        alpha = 1
        isHidden = false
        run(.sequence([.wait(forDuration: duration), .fadeOut(withDuration: 0.3), .hide()]))
    }
}
