import SpriteKit

/// El Cuico en pixel art, con la estética del icono de la app: casco y braga
/// negros, antiparras espejadas con marco rojo, parka roja con cremallera blanca
/// y esquís con cantos verde lima. Los esquís giran según la dirección.
final class CuicoNode: SKNode {
    /// Cuerpo visto de frente (10 × 15 píxeles más el contorno).
    static let bodyArt = PixelArt(
        rows: [
            "...KKKK...",
            "..KKKKKK..",
            "..FIIIiF..",
            "..FIIIIF..",
            "..KKKKKK..",
            "...KKKK...",
            "..EEWWEE..",
            ".EEEWWEEE.",
            "EEEEWWEEEE",
            "E.EEWWEE.E",
            "K.EEWWEE.K",
            "..EEEEEE..",
            "..PPPPPP..",
            "..PP..PP..",
            "..PP..PP..",
        ],
        overrides: [
            "K": 0x1A1B20, // casco, braga y guantes
            "F": 0xE52626, // marco de las antiparras
            "I": 0x3A8CF2, // lente espejada
            "i": 0xBFE6FF, // reflejo
            "E": 0xE31E21, // parka
            "W": 0xF5F5F5, // cremallera
            "P": 0x2A2C35, // pantalón
        ]
    )

    /// Un esquí: canto lima y suela negra, sin contorno para que quede fino.
    static let skiArt = PixelArt(
        rows: Array(repeating: "LK", count: 12),
        overrides: ["L": 0xB8F21A, "K": 0x16171C],
        outlined: false
    )

    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 8))
    /// Contenedor de esquís y cuerpo; se eleva en los saltos y se tumba al caer.
    private let figure = SKNode()
    private let skis = SKNode()
    private let body = SKNode()
    private var bodySprite: SKSpriteNode?
    private let bubble = SKNode()
    private(set) var isGolden = false
    /// Última frase dicha (para los tests).
    private(set) var lastLine: String?

    override init() {
        super.init()
        name = "cuico"
        shadow.fillColor = SKColor(white: 0.2, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        addChild(shadow)
        addChild(figure)
        buildSkis()
        buildBody()
        apply(SkierState())
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Refleja el estado del Cuico: dirección, salto, caída, tambaleo y trucos.
    func apply(_ state: SkierState, trick: Trick? = nil, trickProgress: Double = 0) {
        let angle = CGFloat(state.direction.angle)
        let height = CGFloat(state.airHeight)
        let scale = 1 + height / 160

        figure.position = CGPoint(x: 0, y: height)
        figure.xScale = scale
        figure.yScale = scale
        shadow.setScale(max(0.5, 1 - height / 120))

        if state.isFallen {
            // Tumbado en la nieve con los esquís cruzados.
            figure.zRotation = .pi / 2
            skis.zRotation = .pi / 3
            body.zRotation = 0
            return
        }

        let wobble = state.stumbleTime > 0 ? sin(CGFloat(state.stumbleTime) * 40) * 0.35 : 0
        figure.zRotation = wobble
        skis.zRotation = angle
        body.zRotation = 0

        let turn = CGFloat(trickProgress) * 2 * .pi
        switch trick {
        case .spinLeft:
            figure.zRotation = turn
        case .spinRight:
            figure.zRotation = -turn
        case .frontFlip:
            // Vista desde arriba: el cuerpo "se da la vuelta" y vuelve.
            figure.yScale = scale * cos(turn)
        case .backFlip:
            figure.yScale = scale * cos(turn)
            figure.zRotation = sin(turn) * 0.3
        case .selfie:
            // Brazos arriba para la foto: los esquís se abren en V.
            skis.zRotation = angle + sin(CGFloat(trickProgress) * .pi) * 0.5
        case nil:
            break
        }
    }

    /// Efecto puntual al empezar un truco (el flash del selfie).
    func startTrickEffect(_ trick: Trick) {
        guard trick == .selfie else { return }
        let phone = SKSpriteNode(color: SKColor(white: 0.1, alpha: 1), size: CGSize(width: 5, height: 8))
        phone.position = CGPoint(x: 14, y: 40)
        let flash = SKShapeNode(circleOfRadius: 14)
        flash.fillColor = .white
        flash.strokeColor = SKColor(red: 1, green: 0.95, blue: 0.6, alpha: 1)
        flash.alpha = 0
        flash.position = phone.position
        figure.addChild(phone)
        figure.addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.05), .fadeOut(withDuration: 0.25), .removeFromParent()]))
        phone.run(.sequence([.wait(forDuration: Trick.selfie.duration), .removeFromParent()]))
    }

    private func buildSkis() {
        let texture = SpriteFactory.shared.texture(named: "cuico-ski", art: Self.skiArt)
        for offset in [-4.5, 4.5] {
            let ski = SKSpriteNode(texture: texture, size: Self.skiArt.size)
            ski.position = CGPoint(x: offset, y: -4)
            ski.xScale = offset < 0 ? 1 : -1 // cantos lima hacia fuera
            skis.addChild(ski)
        }
        skis.zPosition = 0
        figure.addChild(skis)
    }

    private func buildBody() {
        let texture = SpriteFactory.shared.texture(named: "cuico-body", art: Self.bodyArt)
        let sprite = SKSpriteNode(texture: texture, size: Self.bodyArt.size)
        bodySprite = sprite
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = CGPoint(x: 0, y: -3)
        body.addChild(sprite)
        body.zPosition = 1
        figure.addChild(body)
    }

    // MARK: Personalidad

    /// Parka dorada (easter egg del código CUICO).
    static let goldenBodyArt = PixelArt(
        rows: bodyArt.rows,
        overrides: bodyArt.overrides.merging(["E": 0xF2C230, "W": 0xFFF6D5, "F": 0xB8860B]) { $1 }
    )

    func setGolden(_ golden: Bool) {
        guard golden != isGolden else { return }
        isGolden = golden
        let art = golden ? Self.goldenBodyArt : Self.bodyArt
        bodySprite?.texture = SpriteFactory.shared.texture(named: golden ? "cuico-body-gold" : "cuico-body", art: art)
    }

    /// Muestra una frase en un bocadillo sobre la cabeza durante unos segundos.
    func say(_ text: String) {
        lastLine = text
        bubble.removeAllActions()
        bubble.removeAllChildren()
        if bubble.parent == nil {
            bubble.zPosition = 50
            addChild(bubble)
        }

        let label = SKLabelNode(fontNamed: PixelFont.name)
        label.text = text
        label.fontSize = 16
        label.fontColor = SKColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let width = label.frame.width + 20
        let box = SKShapeNode(rectOf: CGSize(width: width, height: 30), cornerRadius: 6)
        box.fillColor = .white
        box.strokeColor = SKColor(
            red: CGFloat((PixelArt.outlineColor >> 16) & 0xFF) / 255,
            green: CGFloat((PixelArt.outlineColor >> 8) & 0xFF) / 255,
            blue: CGFloat(PixelArt.outlineColor & 0xFF) / 255,
            alpha: 1
        )
        box.lineWidth = 3
        let tail = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        tail.fillColor = .white
        tail.strokeColor = .clear
        tail.position = CGPoint(x: -width / 2 + 18, y: -16)
        tail.zRotation = .pi / 4

        bubble.addChild(tail)
        bubble.addChild(box)
        bubble.addChild(label)
        bubble.position = CGPoint(x: width / 2 - 14, y: 78)
        bubble.alpha = 1
        bubble.run(.sequence([.wait(forDuration: 2.2), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
