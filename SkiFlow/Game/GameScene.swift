import SpriteKit

/// Escena principal de juego. En la Fase 0 solo muestra la pista vacía.
final class GameScene: SKScene {
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = GameConfig.snowColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    override func didMove(to view: SKView) {
        guard childNode(withName: "title") == nil else { return }

        let title = SKLabelNode(text: "SkiFlow")
        title.name = "title"
        title.fontName = "Menlo-Bold"
        title.fontSize = 48
        title.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1.0)
        addChild(title)
    }

    override func update(_ currentTime: TimeInterval) {
        // El bucle de juego se implementa en la Fase 1.
    }
}
