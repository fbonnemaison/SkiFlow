import SpriteKit

/// Escena principal de juego: el Cuico baja la montaña con física de paso fijo
/// y la cámara lo sigue.
final class GameScene: SKScene {
    // MARK: Estado de simulación

    private(set) var skier = SkierState()
    private(set) var heldActions: Set<InputAction> = []
    private let physics = SkierPhysics()
    private var controller = SkierController()
    private var timestep = FixedTimestep()
    private var lastUpdateTime: TimeInterval?

    // MARK: Nodos

    private let world = SKNode()
    private let speckles: SnowSpeckleNode
    private let trail = SkiTrailNode()
    private let cuico = CuicoNode()
    private let cameraNode = SKCameraNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    override init(size: CGSize) {
        speckles = SnowSpeckleNode(area: CGSize(width: size.width * 1.2, height: size.height * 1.2))
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = GameConfig.snowColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        buildNodes()
        render()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    private func buildNodes() {
        addChild(world)
        speckles.zPosition = 0
        trail.zPosition = 1
        cuico.zPosition = 10
        world.addChild(speckles)
        world.addChild(trail)
        world.addChild(cuico)

        addChild(cameraNode)
        camera = cameraNode

        debugLabel.fontSize = 14
        debugLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.position = CGPoint(x: -size.width / 2 + 16, y: size.height / 2 - 16)
        debugLabel.zPosition = 100
        cameraNode.addChild(debugLabel)
    }

    // MARK: Entrada

    /// Recibe una acción pulsada (`true`) o soltada (`false`).
    func handle(_ action: InputAction, pressed: Bool) {
        if pressed {
            guard !heldActions.contains(action) else { return }
            heldActions.insert(action)
            if action == .restart {
                restart()
            } else {
                controller.press(action, direction: &skier.direction)
            }
        } else {
            heldActions.remove(action)
        }
    }

    /// Suelta todas las teclas (por ejemplo, cuando la ventana pierde el foco).
    func releaseAllInput() {
        heldActions.removeAll()
    }

    func restart() {
        skier = SkierState()
        controller = SkierController()
        timestep.reset()
        trail.clear()
        render()
    }

    // MARK: Bucle de juego

    override func update(_ currentTime: TimeInterval) {
        let frameDelta = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        let steps = timestep.advance(by: frameDelta)
        for _ in 0..<steps {
            simulate(dt: timestep.step)
        }
        render()
    }

    /// Avanza la simulación un paso fijo. Es interno para poder testearlo.
    func simulate(dt: Double) {
        controller.update(held: heldActions, dt: dt, direction: &skier.direction)
        physics.step(&skier, dt: dt)
        trail.record(position: skier.position, direction: skier.direction)
    }

    private func render() {
        cuico.position = skier.position
        cuico.apply(direction: skier.direction)

        cameraNode.position = CGPoint(
            x: skier.position.x,
            y: skier.position.y - size.height * GameConfig.cameraLookAhead
        )
        speckles.wrap(around: cameraNode.position)

        // Con `aspectFill` los bordes de la escena pueden quedar recortados, así que
        // la etiqueta se ancla a la esquina superior izquierda visible de la vista.
        if let view {
            let topY = view.isFlipped ? 0 : view.bounds.height
            let visibleTopLeft = convertPoint(fromView: CGPoint(x: 0, y: topY))
            let local = cameraNode.convert(visibleTopLeft, from: self)
            debugLabel.position = CGPoint(x: local.x + 16, y: local.y - 16)
        }

        debugLabel.text = String(
            format: "%3.0f km/h · %5.0f m",
            skier.speedKmh,
            skier.distanceMeters
        )
    }
}
