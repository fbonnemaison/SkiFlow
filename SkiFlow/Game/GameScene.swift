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
    private(set) var environment = Terrain()
    private(set) var elapsed: Double = 0
    private(set) var isGamePaused = false
    private var physics = SkierPhysics()
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

    // MARK: Freestyle

    private(set) var freestyle: FreestyleScore?
    private(set) var freestyleResult: FreestyleResult?
    private var finishNode: FinishLineNode?

    /// La bajada terminó (atrapado o en meta).
    var isRunOver: Bool { gameOver != nil || slalomResult != nil || freestyleResult != nil }

    /// Resultado de la bajada, cuando termina.
    var outcome: RunOutcome? {
        if let gameOver { return .caught(gameOver) }
        if let slalomResult { return .slalom(slalomResult) }
        if let freestyleResult { return .freestyle(freestyleResult) }
        return nil
    }

    // MARK: Avisos a la interfaz

    /// Se llama cuando cambia lo que muestra el HUD.
    var onHUDChange: ((HUDSnapshot) -> Void)?
    /// Se llama al terminar la bajada (tras la animación de captura, si la hay).
    var onRunEnded: ((RunOutcome) -> Void)?
    /// Se llama al pausar o reanudar.
    var onPauseChange: ((Bool) -> Void)?
    /// Salida de sonido (música y efectos). `nil` = mudo (por ejemplo, en tests).
    weak var audio: GameAudio? {
        didSet { audio?.playMusic(musicForState) }
    }

    /// Se llama al empezar una bajada (también al reiniciar o cambiar de modo).
    var onRunStarted: ((GameMode) -> Void)?
    private(set) var hud = HUDSnapshot()

    /// Zoom de la cámara (escala de píxel de los Ajustes).
    var pixelZoom: CGFloat = 1 {
        didSet { cameraNode.setScale(1 / max(pixelZoom, 0.1)) }
    }

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
    private let messageLabel: SKLabelNode
    private let spray = SnowEffects.spray()
    private var blizzard: SKEmitterNode?

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
        PixelFont.register()
        messageLabel = SKLabelNode(fontNamed: PixelFont.name)
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

        // Nieve que levantan los esquís (las partículas se quedan en el mundo).
        spray.position = CGPoint(x: 0, y: -8)
        spray.zPosition = -0.5
        spray.targetNode = world
        cuico.addChild(spray)

        let blizzard = SnowEffects.blizzard(size: size)
        blizzard.zPosition = Depth.overhead + 11
        cameraNode.addChild(blizzard)
        self.blizzard = blizzard

        messageLabel.fontSize = 16
        messageLabel.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 1)
        messageLabel.position = CGPoint(x: 0, y: -size.height * 0.35)
        messageLabel.zPosition = Depth.overhead + 20
        messageLabel.alpha = 0
        cameraNode.addChild(messageLabel)
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
        case _ where freestyle != nil && skier.isAirborne && Trick(action: action) != nil:
            // En el aire, en freestyle, las teclas de giro y salto hacen trucos.
            if let trick = Trick(action: action), freestyle?.start(trick) == true {
                cuico.startTrickEffect(trick)
                audio?.play(trick == .selfie ? .selfie : .swish)
            }
        case .jump:
            if physics.hop(&skier) { audio?.play(.hop) }
        case .turbo:
            if !skier.isFallen { audio?.play(.turbo) }
        default:
            // Girar con teclas o cruceta desactiva el apuntado con ratón.
            if action.isSteering, source != .mouse {
                input.mouseAim = nil
            }
            if !skier.isFallen {
                let before = skier.direction
                controller.press(action, direction: &skier.direction)
                if skier.direction != before, !skier.isAirborne { audio?.play(.swish) }
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
        let changed = isGamePaused != paused
        isGamePaused = paused
        if changed { onPauseChange?(paused) }
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
    /// - Parameter seed: semilla concreta (por ejemplo, para repetir un trazado).
    func restart(mode newMode: GameMode? = nil, seed: UInt64? = nil) {
        if let newMode {
            mode = newMode
            currentSeed = fixedSeed ?? UInt64.random(in: .min ... .max)
        } else if !mode.hasFinish {
            currentSeed = fixedSeed ?? UInt64.random(in: .min ... .max)
        }
        if let seed { currentSeed = seed }
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
        environment = Terrain()
        trail.clear()
        physics.airTimeMultiplier = mode.airTimeMultiplier
        freestyle = mode == .freestyle ? FreestyleScore() : nil
        freestyleResult = nil
        finishNode?.removeFromParent()
        finishNode = mode.finishMeters.map { FinishLineNode(y: -$0 * GameConfig.pointsPerMeter) }
        if let finishNode { world.addChild(finishNode) }

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
        messageLabel.removeAllActions()
        messageLabel.alpha = 0

        if isGamePaused { setPaused(false) }
        render()
        audio?.playMusic(.run)
        onRunStarted?(mode)
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
        updateFreestyle(dt: dt)
        guard !isRunOver else { return }
        updateChasers(dt: dt)
    }

    private func simulateSkier(dt: Double) {
        skier.stumbleTime = max(0, skier.stumbleTime - dt)
        wasAirborne = skier.isAirborne
        if freestyle != nil, skier.isAirborne {
            // En el aire, en freestyle, las teclas hacen trucos en vez de girar.
        } else if let target = input.aimDirection(skier: skier.position, camera: cameraCenter) {
            controller.steer(toward: target, dt: dt, direction: &skier.direction)
        } else {
            controller.update(held: input.held, dt: dt, direction: &skier.direction)
        }

        let nearby = mountain.snapshots(near: skier.position, radius: Self.collisionRadius, time: elapsed)
        environment = skier.isAirborne
            ? Terrain()
            : CollisionResolver.environment(at: skier.position, among: nearby)
        physics.step(&skier, dt: dt, environment: environment, turbo: isTurboActive)

        if skier.graceTime > 0 {
            skier.graceTime = max(0, skier.graceTime - dt)
        } else if let hit = CollisionResolver.firstHit(skier: skier, among: nearby) {
            apply(hit.effect, obstacleHitbox: hit.snapshot.hitbox)
        }

        if !skier.isAirborne {
            trail.record(position: skier.position, direction: skier.direction)
            if wasAirborne, !skier.isFallen {
                snowBurst(count: 18)
                audio?.play(.land)
            }
        }
    }

    /// Estallido de nieve a los pies del Cuico.
    private func snowBurst(count: Int) {
        let burst = SnowEffects.burst(count: count)
        burst.position = skier.position
        burst.zPosition = Depth.object(atY: skier.position.y) + 0.001
        burst.targetNode = world
        world.addChild(burst)
    }

    private var wasAirborne = false

    private func updateFreestyle(dt: Double) {
        guard var score = freestyle else { return }
        defer { freestyle = score }

        if let done = score.update(dt: dt) {
            audio?.play(.trick)
            showMessage("\(done.displayName)! · salto: \(score.pendingPoints) pts")
        }

        // Aterrizaje: el salto terminó en este paso.
        if wasAirborne, !skier.isAirborne, !skier.isFallen {
            wasAirborne = false
            switch score.land(sideways: skier.direction.isSideways) {
            case let .clean(points):
                audio?.play(.cleanLanding)
                showMessage("¡Aterrizaje limpio! +\(points) pts · racha ×\(Self.format(score.chain))")
            case let .forced(points):
                audio?.play(.bump)
                skier.stumbleTime = 0.4
                skier.speed *= 0.7
                showMessage("Aterrizaje forzado +\(points) pts")
            case let .crash(lost):
                fallDown()
                showMessage(lost > 0 ? "¡A mitad del truco! Pierdes \(lost) pts" : "¡A mitad del truco!")
            case nil:
                break
            }
        }

        if let meters = mode.finishMeters, skier.distanceMeters >= meters {
            finishFreestyle(score)
        }
    }

    private static func format(_ multiplier: Double) -> String {
        multiplier.rounded() == multiplier ? String(format: "%.0f", multiplier) : String(format: "%.1f", multiplier)
    }

    /// El Cuico se cae donde está (sin obstáculo).
    private func fallDown() {
        let here = CGRect(x: skier.position.x, y: skier.position.y + 14, width: 0, height: 0)
        apply(.crash, obstacleHitbox: here)
    }

    private func finishFreestyle(_ score: FreestyleScore) {
        avalanche.stop()
        let result = FreestyleResult(
            points: score.total,
            bestJump: score.bestJump,
            tricks: score.tricksLanded,
            seconds: elapsed
        )
        freestyleResult = result
        audio?.play(.finish)
        audio?.playMusic(.menu)
        skier.speed = 0
        input.releaseAll()
        endRun()
    }

    private func updateSlalom(from previous: CGPoint) {
        guard var progress = slalom else { return }
        let events = progress.advance(from: previous, to: skier.position)
        slalom = progress
        for event in events {
            switch event {
            case let .passed(gate):
                courseNode?.mark(gate: gate, passed: true)
                audio?.play(.gate)
            case let .missed(gate):
                courseNode?.mark(gate: gate, passed: false)
                audio?.play(.gateMissed)
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
                audio?.play(.kunkRoar)
                audio?.playMusic(musicForState)
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
                audio?.play(.chupacabrasScreech)
                audio?.playMusic(musicForState)
                showMessage("¡Algo acecha entre las rocas! Prepárate para saltar")
            case .caught:
                catchCuico(by: .chupacabras)
                return
            case .escaped:
                audio?.playMusic(musicForState)
                showMessage("El Chupacabras se esfumó…")
            default:
                break
            }
        }

        if mode.hasAvalanche {
            switch avalanche.update(dt: dt, skier: skier) {
            case .appeared:
                audio?.play(.avalancheRumble)
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
        switch kind {
        case .kunk: audio?.play(.kunkRoar)
        case .chupacabras: audio?.play(.chupacabrasScreech)
        case .avalanche: audio?.play(.avalancheRumble)
        }
        audio?.playMusic(nil)
        catchTimer = Self.catchDuration
        skier.speed = 0
        skier.airTime = 0
        input.releaseAll()
        messageLabel.removeAllActions()
        messageLabel.alpha = 0
        if isGamePaused { setPaused(false) }
    }

    private func finishRun(caughtBy kind: ChaserKind) {
        audio?.play(.caught)
        let info = GameOverInfo(
            caughtBy: kind,
            meters: skier.distanceMeters,
            seconds: elapsed,
            crashes: crashes
        )
        gameOver = info
        endRun()
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
        audio?.play(.finish)
        audio?.playMusic(.menu)
        skier.speed = 0
        input.releaseAll()
        endRun()
    }

    private func endRun() {
        messageLabel.removeAllActions()
        messageLabel.alpha = 0
        if let outcome { onRunEnded?(outcome) }
    }

    /// Aplica el efecto de un choque. Es interno para poder testearlo.
    func apply(_ effect: CollisionEffect, obstacleHitbox: CGRect) {
        switch effect {
        case .crash:
            if skier.isAirborne, var score = freestyle {
                // Chocar en pleno salto cuesta los puntos del salto.
                if case let .crash(lost) = score.crash(), lost > 0 {
                    showMessage("¡Choque en el aire! Pierdes \(lost) pts")
                }
                freestyle = score
            }
            crashes += 1
            snowBurst(count: 36)
            audio?.play(.crash)
            audio?.play(.ouch)
            skier.speed = 0
            skier.airTime = 0
            skier.stumbleTime = 0
            skier.fallTime = Self.fallDuration
            // Rueda hasta quedar justo por debajo del obstáculo.
            skier.position.y = min(skier.position.y, obstacleHitbox.minY - 14)
        case .trip:
            audio?.play(.bump)
            skier.speed *= 0.45
            skier.stumbleTime = 0.4
            skier.graceTime = 0.5
        case .jump:
            if physics.launch(&skier) { audio?.play(.jump) }
        }
    }

    /// Tema que corresponde al estado de la bajada.
    var musicForState: MusicTrack? {
        if caughtBy != nil { return nil }
        if isRunOver { return .menu }
        if chupacabras.phase == .warning || chupacabras.phase == .chasing { return .chupacabrasChase }
        if kunk.phase == .chasing { return .kunkChase }
        return .run
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
        cuico.apply(skier, trick: freestyle?.current, trickProgress: freestyle?.currentProgress ?? 0)

        cameraNode.position = cameraCenter
        speckles.wrap(around: cameraNode.position)
        mountain.render(time: elapsed)
        finishNode?.position.x = cameraCenter.x
        renderChasers()

        // El viento blanco tapa la vista poco a poco y trae ventisca.
        let targetAlpha: CGFloat = environment.isWhiteout ? 0.55 : 0
        whiteout.alpha += (targetAlpha - whiteout.alpha) * min(1, CGFloat(frameDelta) * 3)
        if let blizzard {
            blizzard.particleBirthRate = whiteout.alpha * 400
            // Los copos cruzan en el sentido del viento.
            let towardsRight = environment.wind > 0
            blizzard.emissionAngle = towardsRight ? 0 : .pi
            blizzard.position.x = (towardsRight ? -1 : 1) * size.width * 0.6
        }

        // Sonidos continuos: esquís sobre la nieve y viento.
        let running = caughtBy == nil && !isRunOver && !isGamePaused
        let gliding = running && !skier.isAirborne && !skier.isFallen
        audio?.setSlide(gliding ? skier.speed / physics.turboMaxSpeed : 0)
        audio?.setWind(running ? Double(whiteout.alpha / 0.55) : 0)

        // Derrape: más nieve cuanto más fuerte se frena o se gira.
        let skidding = !skier.isAirborne && !skier.isFallen && skier.speed > 80
        let hardEdge = skier.direction.isSideways || abs(skier.direction.rawValue) >= 3
        spray.particleBirthRate = skidding && hardEdge ? CGFloat(min(skier.speed, 500) / 3) : 0

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
        let snapshot = makeHUD()
        guard snapshot != hud else { return }
        hud = snapshot
        onHUDChange?(snapshot)
    }

    /// Datos del HUD según el modo. Es interno para poder testearlo.
    func makeHUD() -> HUDSnapshot {
        let speed = HUDItem(label: "Velocidad", value: String(format: "%.0f km/h", skier.speedKmh))
        var items: [HUDItem]
        if let freestyle {
            let meters = mode.finishMeters ?? 0
            items = [
                HUDItem(label: "Puntos", value: "\(freestyle.total)"),
                HUDItem(label: "Racha", value: "×" + Self.format(freestyle.chain)),
                HUDItem(label: "Distancia", value: String(format: "%.0f/%.0f m", min(skier.distanceMeters, meters), meters)),
                speed,
            ]
        } else if let slalom {
            let total = slalom.course.gates.count
            items = [
                HUDItem(label: "Puerta", value: "\(min(slalom.nextGate + 1, total))/\(total)"),
                HUDItem(label: "Tiempo", value: SlalomResult.formatTime(elapsed + slalom.penaltySeconds)),
                HUDItem(label: "Falladas", value: "\(slalom.missed.count)"),
                speed,
            ]
        } else {
            items = [
                HUDItem(label: "Distancia", value: String(format: "%.0f m", skier.distanceMeters)),
                speed,
                HUDItem(label: "Tiempo", value: GameOverInfo.formatTime(elapsed)),
                HUDItem(label: "Caídas", value: "\(crashes)"),
            ]
        }

        var alert: String?
        if caughtBy == nil, !isRunOver {
            if kunk.phase == .chasing {
                let meters = kunk.distance(to: skier) / GameConfig.pointsPerMeter
                alert = String(format: "¡El Kunk te persigue! a %.0f m", meters)
            } else if chupacabras.phase == .warning {
                alert = "¡Cuidado con el Chupacabras!"
            } else if avalanche.phase == .chasing {
                let meters = avalanche.gap(to: skier) / GameConfig.pointsPerMeter
                alert = String(format: "Avalancha a %.0f m", max(0, meters))
            }
        }
        return HUDSnapshot(mode: mode, items: items, alert: alert, isTurbo: isTurboActive)
    }
}
