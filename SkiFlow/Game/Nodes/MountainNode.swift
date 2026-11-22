import SpriteKit

/// Profundidad de dibujo: lo que está más abajo en la pendiente se pinta delante.
enum Depth {
    static let speckles: CGFloat = 0
    static let zones: CGFloat = 0.5
    static let trail: CGFloat = 1
    static let shadows: CGFloat = 2
    static let overhead: CGFloat = 5000

    static func object(atY y: CGFloat) -> CGFloat {
        10 - y * 0.001
    }
}

/// Muestra la montaña cargando los trozos cercanos a la cámara y descargando los
/// lejanos, de modo que el mundo es infinito con memoria acotada.
final class MountainNode: SKNode {
    /// Margen extra (en puntos) alrededor de la vista que se mantiene cargado.
    static let loadMargin: CGFloat = 400

    @MainActor
    private final class LoadedChunk {
        let obstacles: [Obstacle]
        let loadTime: Double
        let node = SKNode()
        /// Nodos de obstáculos móviles por índice de obstáculo.
        var movingNodes: [(index: Int, node: SKNode)] = []
        /// Tramos del cable del telesilla con sus sillas: (nodo, desfase en puntos).
        var liftPieces: [(bottom: CGPoint, top: CGPoint, chairs: [(node: SKNode, offset: Double)])] = []

        init(obstacles: [Obstacle], loadTime: Double) {
            self.obstacles = obstacles
            self.loadTime = loadTime
        }
    }

    private(set) var generator: MountainGenerator
    private var loaded: [ChunkCoord: LoadedChunk] = [:]

    var loadedCoords: Set<ChunkCoord> { Set(loaded.keys) }

    init(seed: UInt64) {
        generator = MountainGenerator(seed: seed)
        super.init()
        name = "mountain"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Vacía la montaña y empieza otra con una semilla nueva.
    func reset(seed: UInt64) {
        reset(generator: MountainGenerator(seed: seed))
    }

    /// Vacía la montaña y empieza otra con el generador indicado (modo de juego).
    func reset(generator: MountainGenerator) {
        removeAllChildren()
        loaded.removeAll()
        self.generator = generator
    }

    /// Carga los trozos visibles alrededor de `center` y descarga el resto.
    func updateLoadedChunks(center: CGPoint, viewSize: CGSize, time: Double) {
        let area = CGRect(
            x: center.x - viewSize.width / 2 - Self.loadMargin,
            y: center.y - viewSize.height / 2 - Self.loadMargin,
            width: viewSize.width + 2 * Self.loadMargin,
            height: viewSize.height + 2 * Self.loadMargin
        )
        let wanted = Set(MountainGenerator.coords(intersecting: area))

        for (coord, chunk) in loaded where !wanted.contains(coord) {
            chunk.node.removeFromParent()
            loaded[coord] = nil
        }
        for coord in wanted where loaded[coord] == nil {
            load(coord, time: time)
        }
    }

    /// Obstáculos cercanos a un punto, resueltos en el instante `time`.
    func snapshots(near point: CGPoint, radius: CGFloat, time: Double) -> [ObstacleSnapshot] {
        var result: [ObstacleSnapshot] = []
        for chunk in loaded.values {
            let localTime = time - chunk.loadTime
            for obstacle in chunk.obstacles {
                let snapshot = ObstacleSnapshot(obstacle: obstacle, time: localTime)
                if snapshot.hitbox.insetBy(dx: -radius, dy: -radius).contains(point) {
                    result.append(snapshot)
                }
            }
        }
        return result
    }

    /// Actualiza la posición de lo que se mueve.
    func render(time: Double) {
        for chunk in loaded.values {
            let localTime = time - chunk.loadTime
            for (index, node) in chunk.movingNodes {
                let obstacle = chunk.obstacles[index]
                let position = obstacle.position(at: localTime)
                node.position = position
                node.xScale = obstacle.facesLeft(at: localTime) ? -1 : 1
                if obstacle.kind != .condor {
                    node.zPosition = Depth.object(atY: position.y)
                }
            }
            for piece in chunk.liftPieces {
                // Las sillas suben por el cable (avanzan 45 pt/s en vertical).
                let height = Double(piece.top.y - piece.bottom.y)
                guard height > 0 else { continue }
                for (chair, offset) in piece.chairs {
                    let f = CGFloat((offset + localTime * 45).truncatingRemainder(dividingBy: height) / height)
                    chair.position = CGPoint(
                        x: piece.bottom.x + (piece.top.x - piece.bottom.x) * f,
                        y: piece.bottom.y + (piece.top.y - piece.bottom.y) * f
                    )
                }
            }
        }
    }

    // MARK: Construcción

    private func load(_ coord: ChunkCoord, time: Double) {
        let chunk = LoadedChunk(obstacles: generator.obstacles(in: coord), loadTime: time)
        for (index, obstacle) in chunk.obstacles.enumerated() {
            let node = makeNode(for: obstacle)
            chunk.node.addChild(node)
            if obstacle.motion != .stationary {
                chunk.movingNodes.append((index, node))
            }
        }
        addLift(to: chunk, coord: coord)
        loaded[coord] = chunk
        addChild(chunk.node)
    }

    private func makeNode(for obstacle: Obstacle) -> SKNode {
        switch obstacle.kind {
        case .iceZone, .deepSnowZone, .windZone:
            return makeZoneNode(obstacle)
        case .condor:
            return makeCondorNode()
        default:
            let variant = Int(obstacle.origin.x.rounded()) &+ Int(obstacle.origin.y.rounded())
            let sprite = SpriteFactory.shared.sprite(for: obstacle.kind, variant: variant)
            sprite.position = obstacle.origin
            sprite.zPosition = Depth.object(atY: obstacle.origin.y)
            return sprite
        }
    }

    private func makeZoneNode(_ obstacle: Obstacle) -> SKNode {
        let size = obstacle.zoneSize
        let shape = SKShapeNode(ellipseOf: size)
        shape.position = obstacle.origin
        shape.zPosition = Depth.zones
        switch obstacle.kind {
        case .iceZone:
            shape.fillColor = SKColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 0.55)
            shape.strokeColor = SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 0.8)
        case .deepSnowZone:
            shape.fillColor = .white
            shape.strokeColor = SKColor(red: 0.82, green: 0.86, blue: 0.95, alpha: 1)
            shape.lineWidth = 2
            // Montoncitos de nieve polvo.
            var rng = SeededRandom(seed: UInt64(bitPattern: Int64(obstacle.origin.x * 31 + obstacle.origin.y)))
            for _ in 0..<Int(size.width * size.height / 2500) {
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let radius = Double.random(in: 0..<0.8, using: &rng)
                let bump = SKSpriteNode(
                    color: SKColor(red: 0.84, green: 0.88, blue: 0.96, alpha: 1),
                    size: CGSize(width: 6, height: 2)
                )
                bump.position = CGPoint(
                    x: cos(angle) * radius * size.width / 2,
                    y: sin(angle) * radius * size.height / 2
                )
                shape.addChild(bump)
            }
        default:
            shape.fillColor = SKColor(white: 0.9, alpha: 0.25)
            shape.strokeColor = .clear
            var rng = SeededRandom(seed: UInt64(bitPattern: Int64(obstacle.origin.x * 17 - obstacle.origin.y)))
            for _ in 0..<14 {
                let streak = SKSpriteNode(
                    color: SKColor(white: 0.8, alpha: 0.6),
                    size: CGSize(width: Double.random(in: 20...50, using: &rng), height: 2)
                )
                streak.position = CGPoint(
                    x: Double.random(in: -0.4...0.4, using: &rng) * size.width,
                    y: Double.random(in: -0.4...0.4, using: &rng) * size.height
                )
                shape.addChild(streak)
            }
        }
        return shape
    }

    private func makeCondorNode() -> SKNode {
        let node = SKNode()
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 50, height: 14))
        shadow.fillColor = SKColor(white: 0.2, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 6)
        shadow.zPosition = Depth.shadows
        node.addChild(shadow)

        let bird = SpriteFactory.shared.sprite(for: .condor)
        bird.position = CGPoint(x: 0, y: 110)
        bird.zPosition = Depth.overhead
        node.addChild(bird)
        return node
    }

    private func addLift(to chunk: LoadedChunk, coord: ChunkCoord) {
        guard generator.profile.hasLift else { return }
        let cableTop: CGFloat = 60
        for segment in generator.liftSegments(in: MountainGenerator.rect(for: coord)) {
            let bottom = CGPoint(x: segment.bottom.x, y: segment.bottom.y + cableTop)
            let top = CGPoint(x: segment.top.x, y: segment.top.y + cableTop)
            let path = CGMutablePath()
            path.move(to: bottom)
            path.addLine(to: top)
            let cable = SKShapeNode(path: path)
            cable.strokeColor = SKColor(white: 0.25, alpha: 0.9)
            cable.lineWidth = 1.5
            cable.zPosition = Depth.overhead - 1
            chunk.node.addChild(cable)

            // Una silla cada ~190 pt de subida.
            let height = Double(top.y - bottom.y)
            let count = max(1, Int((height / 190).rounded()))
            var chairs: [(node: SKNode, offset: Double)] = []
            for i in 0..<count {
                let chair = SpriteFactory.shared.sprite(.liftChair)
                chair.anchorPoint = CGPoint(x: 0.5, y: 0.85)
                chair.position = bottom
                chair.zPosition = Depth.overhead
                chunk.node.addChild(chair)
                chairs.append((chair, Double(i) * height / Double(count)))
            }
            chunk.liftPieces.append((bottom, top, chairs))
        }
    }
}
