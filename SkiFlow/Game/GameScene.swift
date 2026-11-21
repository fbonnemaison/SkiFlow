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
    private(set) var heldActions: Set<InputAction> = []
    private(set) var crashes = 0
    private(set) var environment = Environment()
    private(set) var elapsed: Double = 0
    private let physics = SkierPhysics()
    private var controller = SkierController()
    private var timestep = FixedTimestep()
    private var lastUpdateTime: TimeInterval?
    /// Semilla fija (tests) o `nil` para una montaña distinta en cada bajada.
    private let fixedSeed: UInt64?

    // MARK: Nodos

    private let world = SKNode()
    private let speckles: SnowSpeckleNode
    private let mountain: MountainNode
    private let trail = SkiTrailNode()
    private let cuico = CuicoNode()
    private let cameraNode = SKCameraNode()
    private let whiteout = SKSpriteNode(color: .white, size: .zero)
    private let debugLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    var seed: UInt64 { mountain.generator.seed }

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

        debugLabel.fontSize = 14
        debugLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.position = CGPoint(x: -size.width / 2 + 16, y: size.height / 2 - 16)
        debugLabel.zPosition = Depth.overhead + 20
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
            } else if !skier.isFallen {
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
        render(frameDelta: min(frameDelta, 0.1))
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
        controller.update(held: heldActions, dt: dt, direction: &skier.direction)

        let nearby = mountain.snapshots(near: skier.position, radius: Self.collisionRadius, time: elapsed)
        environment = skier.isAirborne
            ? Environment()
            : CollisionResolver.environment(at: skier.position, among: nearby)
        physics.step(&skier, dt: dt, environment: environment)

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
            format: "%3.0f km/h · %5.0f m · caídas: %d",
            skier.speedKmh,
            skier.distanceMeters,
            crashes
        )
    }
}
