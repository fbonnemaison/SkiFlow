import SpriteKit

/// Representación provisional del Cuico hecha con formas de colores.
/// Se sustituirá por sprites pixel art en la Fase 8.
final class CuicoNode: SKNode {
    private let skis = SKNode()
    private let body = SKNode()

    override init() {
        super.init()
        name = "cuico"
        buildSkis()
        buildBody()
        apply(direction: .down)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Orienta los esquís (y un poco el cuerpo) según la dirección.
    func apply(direction: SkiDirection) {
        skis.zRotation = CGFloat(direction.angle)
        body.zRotation = CGFloat(direction.angle) * 0.25
    }

    private func buildSkis() {
        let skiColor = SKColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)
        for offset in [-5.0, 5.0] {
            let ski = SKSpriteNode(color: skiColor, size: CGSize(width: 3, height: 34))
            ski.position = CGPoint(x: offset, y: -4)
            skis.addChild(ski)
        }
        skis.zPosition = 0
        addChild(skis)
    }

    private func buildBody() {
        // Pantalones blancos impecables.
        let legs = SKSpriteNode(color: .white, size: CGSize(width: 12, height: 10))
        legs.position = CGPoint(x: 0, y: 2)
        let legsOutline = SKShapeNode(rectOf: legs.size)
        legsOutline.strokeColor = SKColor(white: 0.7, alpha: 1)
        legsOutline.lineWidth = 1
        legs.addChild(legsOutline)

        // Parka fucsia de marca.
        let jacket = SKShapeNode(rectOf: CGSize(width: 16, height: 14), cornerRadius: 4)
        jacket.fillColor = SKColor(red: 0.90, green: 0.15, blue: 0.55, alpha: 1)
        jacket.strokeColor = SKColor(red: 0.55, green: 0.05, blue: 0.30, alpha: 1)
        jacket.position = CGPoint(x: 0, y: 13)

        // Cabeza.
        let head = SKShapeNode(circleOfRadius: 5)
        head.fillColor = SKColor(red: 0.96, green: 0.80, blue: 0.65, alpha: 1)
        head.strokeColor = SKColor(red: 0.70, green: 0.50, blue: 0.40, alpha: 1)
        head.position = CGPoint(x: 0, y: 24)

        // Lentes de sol, imprescindibles para la foto.
        let glasses = SKSpriteNode(color: .black, size: CGSize(width: 9, height: 2.5))
        glasses.position = CGPoint(x: 0, y: 1)
        head.addChild(glasses)

        body.addChild(legs)
        body.addChild(jacket)
        body.addChild(head)
        body.zPosition = 1
        addChild(body)
    }
}
