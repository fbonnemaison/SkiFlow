import SpriteKit

/// Sprite de un rival con sus esquís (o a pie, el Gringo) y su bocadillo.
final class RivalSkierNode: SKNode {
    let rivalID: Int
    let kind: RivalKind
    private let figure = SKNode()
    private let skis = SKNode()
    private let bubble = SpeechBubbleNode()
    private var body: SKSpriteNode?

    init(rival: RivalSkier) {
        rivalID = rival.id
        kind = rival.kind
        super.init()
        name = "rival-\(rival.kind.rawValue)"

        let factory = SpriteFactory.shared
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 8))
        shadow.fillColor = SKColor(white: 0.2, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        addChild(shadow)

        let skiTexture = factory.texture(named: "cuico-ski", art: CuicoNode.skiArt)
        for offset in [-4.5, 4.5] where !rival.kind.walksAcross {
            let ski = SKSpriteNode(texture: skiTexture, size: CuicoNode.skiArt.size)
            ski.position = CGPoint(x: offset, y: -4)
            ski.xScale = offset < 0 ? 1 : -1
            skis.addChild(ski)
        }
        figure.addChild(skis)

        let art = ObstacleArt.art(for: rival.kind.obstacleKind)
        let body = SKSpriteNode(texture: factory.texture(named: "rival-\(rival.kind.rawValue)", art: art), size: art.size)
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.position = CGPoint(x: 0, y: -3)
        body.zPosition = 1
        figure.addChild(body)
        self.body = body
        addChild(figure)
        addChild(bubble)
        bubble.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Última frase dicha (para los tests).
    var lastLine: String? { bubble.text }

    func apply(_ rival: RivalSkier, time: Double) {
        position = rival.position
        zPosition = Depth.object(atY: rival.position.y) + 0.0002
        if kind.walksAcross {
            // A pie: se balancea un poco con cada paso y mira hacia donde camina.
            let step = sin((time - rival.spawnTime) * 9)
            body?.position.y = -3 + CGFloat(abs(step)) * 2
            figure.xScale = rival.facesLeft(at: time) ? -1 : 1
        } else {
            // Solo los esquís se inclinan con las eses (el pixel art girado se ve dentado).
            skis.zRotation = rival.facesLeft(at: time) ? -0.4 : 0.4
        }
    }

    func say(_ text: String) {
        bubble.show(text, height: 78)
    }
}
