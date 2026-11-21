import SpriteKit

/// Escena principal de juego: el Cuico baja una montaña andina infinita con
/// física de paso fijo, obstáculos y una cámara que lo sigue.
final class GameScene: SKScene {
    /// Segundos que el Cuico queda en el suelo tras una caída.
    static let fallDuration: Double = 1.2
    /// Inmunidad a choques tras levantarse, para poder alejarse del obstáculo.
    static let recoveryGrace: Double = 0.6
    /// Radio alrededor del Cuico en el que se buscan obstáculos.
    static let collisionRadius: CGFloat = 120

    // MARK: Estado de simulación

    private(set) var skier = SkierState()
    private(set) var input = InputState()
    private(set) var crashes = 0
    private(set) var environment = Environment()
    private(set) var elapsed: Double = 0
    private(set) var isGamePaused = false
    private let physics = SkierPhysics()
    private var controller = SkierController()
    private var timestep = FixedTimestep()
    private var lastUpdateTime: TimeInterval?
    /// Semilla fija (tests) o `nil` para una montaña distinta en cada bajada.
    private let fixedSeed: UInt64?

    // MARK: Mando

    private let gamepadReader = GamepadReader()
    private var gamepad = GamepadState()
    private var gamepadName: String?

    // MARK: Nodos

    private let world = SKNode()
    private let speckles: SnowSpeckleNode
    private let mountain: MountainNode
    private let trail = SkiTrailNode()
    private let cuico = CuicoNode()
    private let cameraNode = SKCameraNode()
    private let whiteout = SKSpriteNode(color: .white, size: .zero)
    private let pauseOverlay = SKNode()
    private let messageLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let debugLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    var seed: UInt64 { mountain.generator.seed }
    var heldActions: Set<InputAction> { input.held }
    var isTurboActive: Bool { input.held.contains(.turbo) && !skier.isFallen }

    init(size: CGSize, seed: UInt64? = nil) {
        fixedSeed = seed
        speckles = SnowSpeckleNode(area: CGSize(width: size.width * 1.2, height: size.height * 1.2))
        mountain = MountainNode(seed: seed ?? UInt64.random(in: .min ... .max))
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = GameConfig.snowColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        buildNodes()
        mountain.updateLoadedChunks(center: cameraCenter, viewSize: size, time: elapsed)
        render()
    }

    override convenience init(size: CGSize) {
        self.init(size: size, seed: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    private func buildNodes() {
        addChild(world)
        speckles.zPosition = Depth.speckles
        trail.zPosition = Depth.trail
        world.addChild(speckles)
        world.addChild(mountain)
        world.addChild(trail)
        world.addChild(cuico)

        addChild(cameraNode)
        camera = cameraNode

        whiteout.size = CGSize(width: size.width * 2, height: size.height * 2)
        whiteout.alpha = 0
        whiteout.zPosition = Depth.overhead + 10
        cameraNode.addChild(whiteout)

        buildPauseOverlay()

        messageLabel.fontSize = 18
        messageLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        messageLabel.position = CGPoint(x: 0, y: -size.height * 0.35)
        messageLabel.zPosition = Depth.overhead + 20
        messageLabel.alpha = 0
        cameraNode.addChild(messageLabel)

        debugLabel.fontSize = 14
        debugLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.position = CGPoint(x: -size.width / 2 + 16, y: size.height / 2 - 16)
        debugLabel.zPosition = Depth.overhead + 20
        cameraNode.addChild(debugLabel)
    }

    private func buildPauseOverlay() {
        let shade = SKSpriteNode(
            color: SKColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 0.55),
            size: CGSize(width: size.width * 2, height: size.height * 2)
        )
        pauseOverlay.addChild(shade)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "Pausa"
        title.fontSize = 48
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 10)
        pauseOverlay.addChild(title)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "Esc o P para seguir · R para reiniciar"
        hint.fontSize = 16
        hint.fontColor = SKColor(white: 0.9, alpha: 1)
        hint.position = CGPoint(x: 0, y: -30)
        pauseOverlay.addChild(hint)

        pauseOverlay.zPosition = Depth.overhead + 30
        pauseOverlay.isHidden = true
        cameraNode.addChild(pauseOverlay)
    }

    // MARK: Entrada

    /// Recibe una acción pulsada (`true`) o soltada (`false`) desde un dispositivo.
    func handle(_ action: InputAction, pressed: Bool, source: InputSource = .keyboard) {
        let isNewPress = input.set(action, pressed: pressed, source: source)
        guard isNewPress else { return }

        switch action {
        case .pause:
            setPaused(!isGamePaused)
        case .restart:
            restart()
        case _ where isGamePaused:
            break
        case .jump:
            physics.hop(&skier)
        case .turbo:
            break
        default:
            // Girar con teclas o cruceta desactiva el apuntado con ratón.
            if action.isSteering, source != .mouse {
                input.mouseAim = nil
            }
            if !skier.isFallen {
                controller.press(action, direction: &skier.direction)
            }
        }
    }

    /// Posición del cursor en coordenadas de escena (desde el ratón o trackpad).
    func aimMouse(atScenePoint point: CGPoint) {
        input.mouseAim = CGPoint(x: point.x - cameraNode.position.x, y: point.y - cameraNode.position.y)
    }

    /// Posición del cursor a partir de un evento de ventana. Ignora lo que cae
    /// fuera de la vista del juego. Devuelve `true` si el punto estaba dentro.
    @discardableResult
    func aimMouse(windowPoint: CGPoint, window: NSWindow?) -> Bool {
        guard let view, view.window === window else { return false }
        let local = view.convert(windowPoint, from: nil)
        guard view.bounds.contains(local) else { return false }
        aimMouse(atScenePoint: convertPoint(fromView: local))
        return true
    }

    /// Aplica una nueva lectura del mando (o `nil` si no hay mando).
    func applyGamepad(_ state: GamepadState?) {
        let new = state ?? GamepadState()
        for transition in GamepadState.transitions(from: gamepad, to: new) {
            handle(transition.action, pressed: transition.pressed, source: .gamepad)
        }
        gamepad = new
        input.stickAim = new.stick
    }

    /// Suelta todas las teclas (por ejemplo, cuando la ventana pierde el foco).
    func releaseAllInput() {
        input.releaseAll()
        gamepad = GamepadState()
    }

    func setPaused(_ paused: Bool) {
        isGamePaused = paused
        pauseOverlay.isHidden = !paused
        // Al reanudar no se recupera el tiempo pasado en pausa.
        lastUpdateTime = nil
        timestep.reset()
    }

    /// Muestra un aviso breve en la parte inferior de la pantalla.
    func showMessage(_ text: String) {
        messageLabel.text = text
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.run(.sequence([.wait(forDuration: 2), .fadeOut(withDuration: 0.6)]))
    }

    /// Vuelve a la salida. Sin semilla fija, la montaña cambia en cada bajada.
    func restart() {
        skier = SkierState()
        controller = SkierController()
        timestep.reset()
        elapsed = 0
        crashes = 0
        environment = Environment()
        trail.clear()
        mountain.reset(seed: fixedSeed ?? UInt64.random(in: .min ... .max))
        mountain.updateLoadedChunks(center: cameraCenter, viewSize: size, time: elapsed)
        if isGamePaused { setPaused(false) }
        render()
    }

    // MARK: Bucle de juego

    override func update(_ currentTime: TimeInterval) {
        pollGamepad()

        if let window = view?.window, !window.acceptsMouseMovedEvents {
            window.acceptsMouseMovedEvents = true
        }

        let frameDelta = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        if !isGamePaused {
            let steps = timestep.advance(by: frameDelta)
            for _ in 0..<steps {
                simulate(dt: timestep.step)
            }
        }
        render(frameDelta: min(frameDelta, 0.1))
    }

    private func pollGamepad() {
        applyGamepad(gamepadReader.read())
        let name = gamepadReader.controllerName
        if name != gamepadName {
            if let name {
                showMessage("Mando conectado: \(name)")
            } else if gamepadName != nil {
                showMessage("Mando desconectado")
            }
            gamepadName = name
        }
    }

    /// Avanza la simulación un paso fijo. Es interno para poder testearlo.
    func simulate(dt: Double) {
        elapsed += dt
        mountain.updateLoadedChunks(center: cameraCenter, viewSize: size, time: elapsed)

        if skier.isFallen {
            skier.fallTime = max(0, skier.fallTime - dt)
            if !skier.isFallen {
                // Se levanta con los esquís atravesados, listo para seguir.
                skier.direction = skier.direction.braking()
                skier.graceTime = Self.recoveryGrace
            }
            return
        }

        skier.stumbleTime = max(0, skier.stumbleTime - dt)
        if let target = input.aimDirection(skier: skier.position, camera: cameraCenter) {
            controller.steer(toward: target, dt: dt, direction: &skier.direction)
        } else {
            controller.update(held: input.held, dt: dt, direction: &skier.direction)
        }

        let nearby = mountain.snapshots(near: skier.position, radius: Self.collisionRadius, time: elapsed)
        environment = skier.isAirborne
            ? Environment()
            : CollisionResolver.environment(at: skier.position, among: nearby)
        physics.step(&skier, dt: dt, environment: environment, turbo: isTurboActive)

        if skier.graceTime > 0 {
            skier.graceTime = max(0, skier.graceTime - dt)
        } else if let hit = CollisionResolver.firstHit(skier: skier, among: nearby) {
            apply(hit.effect, obstacleHitbox: hit.snapshot.hitbox)
        }

        if !skier.isAirborne {
            trail.record(position: skier.position, direction: skier.direction)
        }
    }

    /// Aplica el efecto de un choque. Es interno para poder testearlo.
    func apply(_ effect: CollisionEffect, obstacleHitbox: CGRect) {
        switch effect {
        case .crash:
            crashes += 1
            skier.speed = 0
            skier.airTime = 0
            skier.stumbleTime = 0
            skier.fallTime = Self.fallDuration
            // Rueda hasta quedar justo por debajo del obstáculo.
            skier.position.y = min(skier.position.y, obstacleHitbox.minY - 14)
        case .trip:
            skier.speed *= 0.45
            skier.stumbleTime = 0.4
            skier.graceTime = 0.5
        case .jump:
            physics.launch(&skier)
        }
    }

    // MARK: Dibujo

    private var cameraCenter: CGPoint {
        CGPoint(
            x: skier.position.x,
            y: skier.position.y - size.height * GameConfig.cameraLookAhead
        )
    }

    private func render(frameDelta: Double = 0) {
        cuico.position = skier.position
        cuico.zPosition = Depth.object(atY: skier.position.y) + 0.0001
        cuico.apply(skier)

        cameraNode.position = cameraCenter
        speckles.wrap(around: cameraNode.position)
        mountain.render(time: elapsed)

        // El viento blanco tapa la vista poco a poco.
        let targetAlpha: CGFloat = environment.isWhiteout ? 0.55 : 0
        whiteout.alpha += (targetAlpha - whiteout.alpha) * min(1, CGFloat(frameDelta) * 3)

        // Con `aspectFill` los bordes de la escena pueden quedar recortados, así que
        // la etiqueta se ancla a la esquina superior izquierda visible de la vista.
        if let view {
            let topY = view.isFlipped ? 0 : view.bounds.height
            let visibleTopLeft = convertPoint(fromView: CGPoint(x: 0, y: topY))
            let local = cameraNode.convert(visibleTopLeft, from: self)
            debugLabel.position = CGPoint(x: local.x + 16, y: local.y - 16)
        }

        debugLabel.text = String(
            format: "%3.0f km/h · %5.0f m · caídas: %d%@",
            skier.speedKmh,
            skier.distanceMeters,
            crashes,
            isTurboActive ? " · TURBO" : ""
        )
    }
}
