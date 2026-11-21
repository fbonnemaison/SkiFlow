import SpriteKit

/// Sprite animado de un perseguidor con su sombra en la nieve.
final class ChaserNode: SKNode {
    let kind: ChaserKind
    private let sprite: SKSpriteNode
    private let shadow: SKShapeNode
    private let runFrames: [SKTexture]
    private let eatFrame: SKTexture?
    private var isEating = false

    init(kind: ChaserKind) {
        self.kind = kind
        let factory = SpriteFactory.shared
        let runArts: [PixelArt]
        switch kind {
        case .kunk:
            runArts = [CreatureArt.kunkRun1, CreatureArt.kunkRun2]
            eatFrame = factory.texture(named: "kunk-eat", art: CreatureArt.kunkEat)
        case .chupacabras:
            runArts = [CreatureArt.chupaRun1, CreatureArt.chupaRun2]
            eatFrame = nil
        case .avalanche:
            preconditionFailure("La avalancha se dibuja con AvalancheNode")
        }
        runFrames = runArts.enumerated().map { index, art in
            factory.texture(named: "\(kind.rawValue)-run\(index)", art: art)
        }
        sprite = SKSpriteNode(texture: runFrames[0], size: runArts[0].size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        shadow = SKShapeNode(ellipseOf: CGSize(width: runArts[0].size.width * 0.8, height: 12))
        super.init()

        name = kind.rawValue
        shadow.fillColor = SKColor(white: 0.2, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 4)
        shadow.zPosition = -1
        addChild(shadow)
        addChild(sprite)

        let period = kind == .kunk ? 0.16 : 0.08
        sprite.run(.repeatForever(.animate(with: runFrames, timePerFrame: period)), withKey: "run")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    func apply(position: CGPoint, facesLeft: Bool) {
        self.position = position
        sprite.xScale = facesLeft ? -1 : 1
        zPosition = Depth.object(atY: position.y) + 0.0002
    }

    /// Animación de captura: el Kunk se come al Cuico dando saltitos.
    func playCatch() {
        guard !isEating else { return }
        isEating = true
        sprite.removeAction(forKey: "run")
        if let eatFrame {
            sprite.texture = eatFrame
            sprite.size = CreatureArt.kunkEat.size
        }
        let hop = SKAction.sequence([
            .moveBy(x: 0, y: 10, duration: 0.12),
            .moveBy(x: 0, y: -10, duration: 0.12),
        ])
        sprite.run(.repeatForever(hop), withKey: "eat")
    }
}
