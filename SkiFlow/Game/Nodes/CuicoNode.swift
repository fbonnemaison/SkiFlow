import SpriteKit

/// Representación provisional del Cuico hecha con formas de colores, con la
/// estética del icono de la app: parka roja, casco y braga negros, antiparras
/// espejadas y esquís negros con cantos verde lima.
/// Se sustituirá por sprites pixel art en la Fase 8.
final class CuicoNode: SKNode {
    private enum Palette {
        static let jacketRed = SKColor(red: 0.89, green: 0.12, blue: 0.13, alpha: 1)
        static let jacketShadow = SKColor(red: 0.55, green: 0.05, blue: 0.07, alpha: 1)
        static let zipper = SKColor(white: 0.95, alpha: 1)
        static let black = SKColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        static let helmetShine = SKColor(red: 0.35, green: 0.37, blue: 0.42, alpha: 1)
        static let goggleLens = SKColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
        static let goggleFrame = SKColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1)
        static let skiBase = SKColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        static let skiEdge = SKColor(red: 0.72, green: 0.95, blue: 0.10, alpha: 1)
    }

    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 8))
    /// Contenedor de esquís y cuerpo; se eleva en los saltos y se tumba al caer.
    private let figure = SKNode()
    private let skis = SKNode()
    private let body = SKNode()

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

    /// Refleja el estado del Cuico: dirección, salto, caída y tambaleo.
    func apply(_ state: SkierState) {
        let angle = CGFloat(state.direction.angle)
        let height = CGFloat(state.airHeight)

        figure.position = CGPoint(x: 0, y: height)
        figure.setScale(1 + height / 160)
        shadow.setScale(max(0.5, 1 - height / 120))

        if state.isFallen {
            // Tumbado en la nieve con los esquís cruzados.
            figure.zRotation = .pi / 2
            skis.zRotation = .pi / 3
            body.zRotation = 0
        } else {
            let wobble = state.stumbleTime > 0 ? sin(CGFloat(state.stumbleTime) * 40) * 0.35 : 0
            figure.zRotation = wobble
            skis.zRotation = angle
            body.zRotation = angle * 0.25
        }
    }

    private func buildSkis() {
        for offset in [-5.0, 5.0] {
            // Canto verde lima que asoma por los lados del esquí negro.
            let edge = SKSpriteNode(color: Palette.skiEdge, size: CGSize(width: 4, height: 34))
            edge.position = CGPoint(x: offset, y: -4)
            let base = SKSpriteNode(color: Palette.skiBase, size: CGSize(width: 2, height: 32))
            edge.addChild(base)
            skis.addChild(edge)
        }
        skis.zPosition = 0
        figure.addChild(skis)
    }

    private func buildBody() {
        // Pantalones negros.
        let legs = SKSpriteNode(color: Palette.black, size: CGSize(width: 12, height: 10))
        legs.position = CGPoint(x: 0, y: 2)

        // Parka roja con cremallera blanca.
        let jacket = SKShapeNode(rectOf: CGSize(width: 16, height: 14), cornerRadius: 4)
        jacket.fillColor = Palette.jacketRed
        jacket.strokeColor = Palette.jacketShadow
        jacket.position = CGPoint(x: 0, y: 13)
        let zipper = SKSpriteNode(color: Palette.zipper, size: CGSize(width: 1.5, height: 11))
        jacket.addChild(zipper)

        // Cabeza: braga negra y casco negro con un brillo.
        let head = SKShapeNode(circleOfRadius: 5.5)
        head.fillColor = Palette.black
        head.strokeColor = Palette.black
        head.position = CGPoint(x: 0, y: 24)
        let shine = SKSpriteNode(color: Palette.helmetShine, size: CGSize(width: 3, height: 1.5))
        shine.position = CGPoint(x: -1.5, y: 4)
        head.addChild(shine)

        // Antiparras espejadas con marco rojo.
        let goggles = SKSpriteNode(color: Palette.goggleFrame, size: CGSize(width: 11, height: 4.5))
        goggles.position = CGPoint(x: 0, y: 0.5)
        let lens = SKSpriteNode(color: Palette.goggleLens, size: CGSize(width: 9, height: 2.5))
        goggles.addChild(lens)
        head.addChild(goggles)

        body.addChild(legs)
        body.addChild(jacket)
        body.addChild(head)
        body.zPosition = 1
        figure.addChild(body)
    }
}
