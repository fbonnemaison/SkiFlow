import SpriteKit

/// Escena principal de juego: el Cuico baja una montaña andina infinita con
/// física de paso fijo, obstáculos, perseguidores, puertas de slalom y una cámara
/// que lo sigue.
final class GameScene: SKScene {
    /// Segundos que el Cuico queda en el suelo tras una caída.
    static let fallDuration: Double = 1.2
    /// Inmunidad a choques tras levantarse, para poder alejarse del obstáculo.
    static let recoveryGrace: Double = 0.6
    /// Radio alrededor del Cuico en el que se buscan obstáculos.
    static let collisionRadius: CGFloat = 120
    /// Duración de la animación de captura antes de la pantalla de fin.
    static let catchDuration: Double = 1.8

    // MARK: Estado de simulación

    private(set) var mode: GameMode
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
    private var currentSeed: UInt64

    // MARK: Perseguidores

    private let kunkConfig: KunkChaser.Config
    private let chupacabrasConfig: ChupacabrasChaser.Config
    private let avalancheConfig: AvalancheChaser.Config
    private(set) var kunk: KunkChaser
    private(set) var chupacabras: ChupacabrasChaser
    private(set) var avalanche: AvalancheChaser
    private(set) var chupacabrasEncounters = 0
    /// Quién atrapó al Cuico (durante la animación de captura y después).
    private(set) var caughtBy: ChaserKind?
    private var catchTimer: Double = 0
    private(set) var gameOver: GameOverInfo?

    // MARK: Slalom

    private(set) var slalom: SlalomProgress?
    private(set) var slalomResult: SlalomResult?

    /// La bajada terminó (atrapado o en meta).
    var isRunOver: Bool { gameOver != nil || slalomResult != nil }

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
    private var chaserNodes: [ChaserKind: ChaserNode] = [:]
    private var courseNode: SlalomCourseNode?
    private var avalancheNode: AvalancheNode?
    private let cameraNode = SKCameraNode()
    private let whiteout = SKSpriteNode(color: .white, size: .zero)
    private let pauseOverlay = SKNode()
    private let resultOverlay = SKNode()
    private let resultTitle = SKLabelNode(fontNamed: "Menlo-Bold")
    private let resultSummary = SKLabelNode(fontNamed: "Menlo")
    private let resultHint = SKLabelNode(fontNamed: "Menlo")
    private let messageLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let hudLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let alertLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    var seed: UInt64 { currentSeed }
    var heldActions: Set<InputAction> { input.held }
    var isTurboActive: Bool { input.held.contains(.turbo) && !skier.isFallen && caughtBy == nil }

    init(
        size: CGSize,
        seed: UInt64? = nil,
        mode: GameMode = .freeDescent,
        kunkConfig: KunkChaser.Config = ChaserTuning.kunk(),
        chupacabrasConfig: ChupacabrasChaser.Config = ChaserTuning.chupacabras(),
        avalancheConfig: AvalancheChaser.Config = AvalancheChaser.Config()
    ) {
        fixedSeed = seed
        self.mode = mode
        self.kunkConfig = kunkConfig
        self.chupacabrasConfig = chupacabrasConfig
        self.avalancheConfig = avalancheConfig
        currentSeed = seed ?? UInt64.random(in: .min ... .max)
        speckles = SnowSpeckleNode(area: CGSize(width: size.width * 1.2, height: size.height * 1.2))
        mountain = MountainNode(seed: currentSeed)
        kunk = KunkChaser(config: kunkConfig, side: 1)
        chupacabras = ChupacabrasChaser(config: chupacabrasConfig, seed: currentSeed)
        avalanche = AvalancheChaser(config: avalancheConfig)
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = GameConfig.snowColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        buildNodes()
        startRun()
    }

    override convenience init(size: CGSize) {
        self.init(size: size, seed: nil, mode: GameMode.fromLaunchArguments())
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
        makeOverlay(resultOverlay, title: resultTitle, subtitle: resultSummary, hint: resultHint)

        messageLabel.fontSize = 18
        messageLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        messageLabel.position = CGPoint(x: 0, y: -size.height * 0.35)
        messageLabel.zPosition = Depth.overhead + 20
        messageLabel.alpha = 0
        cameraNode.addChild(messageLabel)

        for label in [hudLabel, alertLabel] {
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = Depth.overhead + 20
            cameraNode.addChild(label)
        }
        hudLabel.fontSize = 16
        hudLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        alertLabel.fontSize = 16
        alertLabel.fontColor = SKColor(red: 0.80, green: 0.10, blue: 0.10, alpha: 1)
    }

    private func makeOverlay(_ overlay: SKNode, title: SKLabelNode, subtitle: SKLabelNode, hint: SKLabelNode) {
        let shade = SKSpriteNode(
            color: SKColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 0.6),
            size: CGSize(width: size.width * 2, height: size.height * 2)
        )
        overlay.addChild(shade)

        title.fontSize = 44
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 24)
        overlay.addChild(title)

        subtitle.fontSize = 18
        subtitle.fontColor = SKColor(white: 0.92, alpha: 1)
        subtitle.position = CGPoint(x: 0, y: -16)
        overlay.addChild(subtitle)

        hint.fontSize = 15
        hint.fontColor = SKColor(white: 0.8, alpha: 1)
        hint.position = CGPoint(x: 0, y: -52)
        overlay.addChild(hint)

        overlay.zPosition = Depth.overhead + 30
        overlay.isHidden = true
        cameraNode.addChild(overlay)
    }

    private func buildPauseOverlay() {
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "Pausa"
        let subtitle = SKLabelNode(fontNamed: "Menlo")
        subtitle.text = "Esc o P para seguir"
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "R reiniciar · 1 Descenso libre · 2 Slalom · 3 Slalom entre árboles"
        makeOverlay(pauseOverlay, title: title, subtitle: subtitle, hint: hint)
    }

    // MARK: Entrada

    /// Recibe una acción pulsada (`true`) o soltada (`false`) desde un dispositivo.
    func handle(_ action: InputAction, pressed: Bool, source: InputSource = .keyboard) {
        let isNewPress = input.set(action, pressed: pressed, source: source)
        guard isNewPress else { return }

        if let newMode = action.gameMode {
            restart(mode: newMode)
            return
        }

        switch action {
        case .restart:
            restart()
        case _ where caughtBy != nil || isRunOver:
            // Bajada terminada: solo se puede volver a empezar.
            break
        case .pause:
            setPaused(!isGamePaused)
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
        // Con la bajada terminada no tiene sentido pausar.
        guard !(paused && (caughtBy != nil || isRunOver)) else { return }
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
        messageLabel.run(.sequence([.wait(forDuration: 2.5), .fadeOut(withDuration: 0.6)]))
    }

    /// Vuelve a la salida.
    ///
    /// - Parameter newMode: cambia de modo (y de montaña). Sin él, el Descenso libre
    ///   estrena montaña y el slalom repite el mismo trazado para mejorar el tiempo.
    func restart(mode newMode: GameMode? = nil) {
        if let newMode {
            mode = newMode
            currentSeed = fixedSeed ?? UInt64.random(in: .min ... .max)
        } else if !mode.isSlalom {
            currentSeed = fixedSeed ?? UInt64.random(in: .min ... .max)
        }
        startRun()
        if newMode != nil {
            showMessage(mode.displayName)
        }
    }

    private func startRun() {
        skier = SkierState()
        controller = SkierController()
        timestep.reset()
        elapsed = 0
        crashes = 0
        environment = Environment()
        trail.clear()

        // Trazado de slalom y montaña con las puertas despejadas.
        let course = mode.courseConfig.map { SlalomCourse(seed: currentSeed, config: $0) }
        slalom = course.map(SlalomProgress.init(course:))
        slalomResult = nil
        mountain.reset(generator: MountainGenerator(
            seed: currentSeed,
            profile: mode.generatorProfile,
            exclusions: course?.clearings ?? []
        ))
        mountain.updateLoadedChunks(center: cameraCenter, viewSize: size, time: elapsed)
        courseNode?.removeFromParent()
        courseNode = course.map(SlalomCourseNode.init(course:))
        if let courseNode { world.addChild(courseNode) }

        kunk = KunkChaser(config: kunkConfig, side: currentSeed & 2 == 0 ? -1 : 1)
        chupacabras = ChupacabrasChaser(config: chupacabrasConfig, seed: currentSeed)
        avalanche = AvalancheChaser(config: avalancheConfig)
        chupacabrasEncounters = 0
        caughtBy = nil
        catchTimer = 0
        gameOver = nil
        chaserNodes.values.forEach { $0.removeFromParent() }
        chaserNodes.removeAll()
        avalancheNode?.removeFromParent()
        avalancheNode = nil
        cuico.isHidden = false
        resultOverlay.isHidden = true
        messageLabel.removeAllActions()
        messageLabel.alpha = 0

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
        guard !isRunOver else { return }

        if let caughtBy {
            catchTimer -= dt
            if catchTimer <= 0 {
                finishRun(caughtBy: caughtBy)
            }
            return
        }

        elapsed += dt
        mountain.updateLoadedChunks(center: cameraCenter, viewSize: size, time: elapsed)

        let previousPosition = skier.position
        if skier.isFallen {
            skier.fallTime = max(0, skier.fallTime - dt)
            if !skier.isFallen {
                // Se levanta con los esquís atravesados, listo para seguir.
                skier.direction = skier.direction.braking()
                skier.graceTime = Self.recoveryGrace
            }
        } else {
            simulateSkier(dt: dt)
        }

        updateSlalom(from: previousPosition)
        guard !isRunOver else { return }
        updateChasers(dt: dt)
    }

    private func simulateSkier(dt: Double) {
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

    private func updateSlalom(from previous: CGPoint) {
        guard var progress = slalom else { return }
        let events = progress.advance(from: previous, to: skier.position)
        slalom = progress
        for event in events {
            switch event {
            case let .passed(gate):
                courseNode?.mark(gate: gate, passed: true)
            case let .missed(gate):
                courseNode?.mark(gate: gate, passed: false)
                showMessage(String(format: "¡Puerta fallada! +%.0f s", SlalomProgress.missPenalty))
            case .finished:
                finishSlalom(progress)
            }
        }
    }

    private func updateChasers(dt: Double) {
        if mode.hasCreatures {
            switch kunk.update(dt: dt, skier: skier) {
            case .appeared:
                showMessage("¡Viene el Kunk! Mantén F (turbo) para escapar")
            case .caught:
                catchCuico(by: .kunk)
                return
            default:
                break
            }

            switch chupacabras.update(dt: dt, skier: skier) {
            case .warning:
                chupacabrasEncounters += 1
                showMessage("¡Algo acecha entre las rocas! Prepárate para saltar")
            case .caught:
                catchCuico(by: .chupacabras)
                return
            case .escaped:
                showMessage("El Chupacabras se esfumó…")
            default:
                break
            }
        }

        if mode.hasAvalanche {
            switch avalanche.update(dt: dt, skier: skier) {
            case .appeared:
                showMessage("¡Avalancha! No te detengas")
            case .caught:
                catchCuico(by: .avalanche)
            default:
                break
            }
        }
    }

    private func catchCuico(by kind: ChaserKind) {
        caughtBy = kind
        catchTimer = Self.catchDuration
        skier.speed = 0
        skier.airTime = 0
        input.releaseAll()
        messageLabel.removeAllActions()
        messageLabel.alpha = 0
        if isGamePaused { setPaused(false) }
    }

    private func finishRun(caughtBy kind: ChaserKind) {
        let info = GameOverInfo(
            caughtBy: kind,
            meters: skier.distanceMeters,
            seconds: elapsed,
            crashes: crashes
        )
        gameOver = info
        showResult(title: info.title, summary: info.summary, hint: "R (o Vista en el mando) para volver a bajar")
    }

    private func finishSlalom(_ progress: SlalomProgress) {
        avalanche.stop()
        let result = SlalomResult(
            seconds: elapsed,
            gatesPassed: progress.passed.count,
            gatesTotal: progress.course.gates.count,
            penaltySeconds: progress.penaltySeconds
        )
        slalomResult = result
        skier.speed = 0
        input.releaseAll()
        showResult(title: result.title, summary: result.summary, hint: "R repite este trazado · 2 o 3 para uno nuevo")
    }

    private func showResult(title: String, summary: String, hint: String) {
        resultTitle.text = title
        resultSummary.text = summary
        resultHint.text = hint
        resultOverlay.isHidden = false
        messageLabel.removeAllActions()
        messageLabel.alpha = 0
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
        renderChasers()

        // El viento blanco tapa la vista poco a poco.
        let targetAlpha: CGFloat = environment.isWhiteout ? 0.55 : 0
        whiteout.alpha += (targetAlpha - whiteout.alpha) * min(1, CGFloat(frameDelta) * 3)

        renderHUD()
    }

    private func renderChasers() {
        let creatures: [any Chaser] = [kunk, chupacabras]
        for chaser in creatures {
            if chaser.phase.isVisible {
                let node = chaserNodes[chaser.kind] ?? {
                    let node = ChaserNode(kind: chaser.kind)
                    world.addChild(node)
                    chaserNodes[chaser.kind] = node
                    return node
                }()
                node.apply(position: chaser.position, facesLeft: chaser.facesLeft)
                if chaser.phase == .caught {
                    node.playCatch()
                    cuico.isHidden = true
                }
            } else if let node = chaserNodes.removeValue(forKey: chaser.kind) {
                node.removeFromParent()
            }
        }

        if avalanche.phase == .chasing || avalanche.phase == .caught {
            let node = avalancheNode ?? {
                let node = AvalancheNode(width: size.width * 2)
                world.addChild(node)
                avalancheNode = node
                return node
            }()
            node.apply(frontY: avalanche.position.y, centerX: cameraCenter.x, time: elapsed)
            if avalanche.phase == .caught { cuico.isHidden = true }
        } else if let node = avalancheNode {
            node.removeFromParent()
            avalancheNode = nil
        }
    }

    private func renderHUD() {
        // Con `aspectFill` los bordes de la escena pueden quedar recortados, así que
        // el HUD se ancla a la esquina superior izquierda visible de la vista.
        var topLeft = CGPoint(x: -size.width / 2, y: size.height / 2)
        if let view {
            let topY = view.isFlipped ? 0 : view.bounds.height
            let visibleTopLeft = convertPoint(fromView: CGPoint(x: 0, y: topY))
            topLeft = cameraNode.convert(visibleTopLeft, from: self)
        }
        hudLabel.position = CGPoint(x: topLeft.x + 16, y: topLeft.y - 16)
        alertLabel.position = CGPoint(x: topLeft.x + 16, y: topLeft.y - 40)

        let turbo = isTurboActive ? " · TURBO" : ""
        if let slalom {
            let total = slalom.course.gates.count
            hudLabel.text = String(
                format: "%@ · puerta %d/%d · %@ · falladas: %d · %3.0f km/h%@",
                mode.displayName,
                min(slalom.nextGate + 1, total),
                total,
                SlalomResult.formatTime(elapsed + slalom.penaltySeconds),
                slalom.missed.count,
                skier.speedKmh,
                turbo
            )
        } else {
            hudLabel.text = String(
                format: "%5.0f m · %3.0f km/h · %@ · caídas: %d%@",
                skier.distanceMeters,
                skier.speedKmh,
                GameOverInfo.formatTime(elapsed),
                crashes,
                turbo
            )
        }

        if caughtBy != nil || isRunOver {
            alertLabel.text = nil
        } else if kunk.phase == .chasing {
            let meters = kunk.distance(to: skier) / GameConfig.pointsPerMeter
            alertLabel.text = String(format: "¡El Kunk te persigue! a %.0f m", meters)
        } else if chupacabras.phase == .warning {
            alertLabel.text = "¡Cuidado con el Chupacabras!"
        } else if avalanche.phase == .chasing {
            let meters = avalanche.gap(to: skier) / GameConfig.pointsPerMeter
            alertLabel.text = String(format: "Avalancha a %.0f m", max(0, meters))
        } else {
            alertLabel.text = nil
        }
    }
}
