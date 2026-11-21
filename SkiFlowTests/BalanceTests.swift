import CoreGraphics
import Foundation
import Testing
@testable import SkiFlow

/// Piloto simulado: esquiva lo que tiene delante apuntando con el "ratón" y usa
/// el turbo cuando el Kunk se acerca. No juega como una persona, pero sirve para
/// detectar extremos (montaña imposible, Kunk imbatible, memoria que crece…).
@MainActor
struct SimulatedRider {
    let scene: GameScene
    private(set) var crashes = 0

    mutating func step(dt: Double) {
        let skier = scene.skier
        let p = skier.position
        // Obstáculos sólidos en el pasillo de delante, tan lejos como se ve en
        // pantalla (unos 540 pt por debajo del Cuico).
        let lookAhead = max(300, min(540, skier.speed * 0.7))
        let ahead = scene.obstacles(near: CGPoint(x: p.x, y: p.y - lookAhead / 2), radius: lookAhead / 2 + 120).filter { snap in
            guard CollisionResolver.effect(of: snap.kind, airborne: false) == .crash else { return false }
            let box = snap.hitbox
            return box.maxY < p.y + 10 && box.minY > p.y - lookAhead
        }
        func blocked(_ x: CGFloat) -> Bool {
            ahead.contains { abs($0.hitbox.midX - x) < $0.hitbox.width / 2 + 26 }
        }
        var targetX = p.x
        if blocked(p.x) {
            let options: [CGFloat] = [-90, 90, -180, 180, -270, 270]
            targetX = p.x + (options.first { !blocked(p.x + $0) } ?? 180)
        }
        scene.aimMouse(atScenePoint: CGPoint(x: targetX, y: p.y - 320))

        // Como haría una persona: turbo a fondo mientras el Kunk persigue.
        let chased = scene.kunk.phase == .chasing
        if chased != scene.heldActions.contains(.turbo) {
            scene.handle(.turbo, pressed: chased)
        }
        let before = scene.crashes
        scene.simulate(dt: dt)
        crashes += scene.crashes - before
    }
}

@MainActor
struct BalanceTests {
    private let dt = 1.0 / 120.0

    @Test func freeDescentIsSurvivableAndMemoryStaysBounded() {
        var results: [(meters: Double, crashes: Int, caught: Bool)] = []
        var worstStepMs = 0.0
        var totalMs = 0.0
        var steps = 0
        var maxChunks = 0
        var maxNodes = 0

        for seed in UInt64(1)...UInt64(4) {
            let scene = GameScene(size: GameConfig.sceneSize, seed: seed, mode: .freeDescent, chupacabrasConfig: .init(chance: 0))
            var rider = SimulatedRider(scene: scene)
            for i in 0..<Int(240 / dt) where !scene.isRunOver && scene.caughtBy == nil {
                let start = DispatchTime.now().uptimeNanoseconds
                rider.step(dt: dt)
                scene.update(0) // la cámara (y el apuntado) se actualizan al dibujar
                let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                totalMs += ms
                worstStepMs = max(worstStepMs, ms)
                steps += 1
                if i % 120 == 0 {
                    maxChunks = max(maxChunks, scene.loadedChunkCount)
                    maxNodes = max(maxNodes, scene.worldNodeCount)
                }
            }
            results.append((scene.skier.distanceMeters, rider.crashes, scene.caughtBy != nil))
        }

        let average = results.map(\.meters).reduce(0, +) / Double(results.count)
        let crashesPerKm = Double(results.map(\.crashes).reduce(0, +)) / (results.map(\.meters).reduce(0, +) / 1000)
        print(String(format: "BALANCE descenso: media %.0f m, %.2f caídas/km, atrapado %d/%d · %.3f ms/paso (peor %.1f) · trozos ≤ %d · nodos ≤ %d",
                     average, crashesPerKm, results.filter(\.caught).count, results.count,
                     totalMs / Double(steps), worstStepMs, maxChunks, maxNodes))
        for r in results { print(String(format: "BALANCE   %.0f m, %d caídas, atrapado: %@", r.meters, r.crashes, r.caught ? "sí" : "no")) }

        // Un buen piloto pasa de los 2.000 m (donde aparece el Kunk).
        #expect(average > 2000)
        // La memoria no crece con la distancia.
        // Vista + márgenes cubren como mucho 4 × 4 trozos.
        #expect(maxChunks <= 16)
        #expect(maxNodes < 3000)
        // Presupuesto de un fotograma a 120 fps (8,3 ms) con mucho margen, incluso en Debug.
        #expect(totalMs / Double(steps) < 2)
    }

    @Test func slalomAndFreestyleCanBeFinished() {
        for mode in [GameMode.slalom, .treeSlalom, .freestyle] {
            let scene = GameScene(size: GameConfig.sceneSize, seed: 5, mode: mode)
            var rider = SimulatedRider(scene: scene)
            for _ in 0..<Int(120 / dt) where !scene.isRunOver && scene.caughtBy == nil {
                // En slalom apunta a la siguiente puerta; si no, esquiva.
                if let progress = scene.slalom, progress.nextGate < progress.course.gates.count {
                    let gate = progress.course.gates[progress.nextGate]
                    scene.aimMouse(atScenePoint: CGPoint(x: gate.centerX, y: gate.y - 60))
                    scene.simulate(dt: dt)
                    scene.update(0) // la cámara se mueve al dibujar
                } else {
                    rider.step(dt: dt)
                    scene.update(0)
                }
            }
            print("BALANCE \(mode.rawValue): \(scene.outcome.map(\.summary) ?? "sin terminar") · caídas \(scene.crashes)")
            #expect(scene.caughtBy == nil, "\(mode) atrapado")
            #expect(scene.isRunOver, "\(mode) sin terminar")
        }
    }
}
