/// Acumulador para simular con un paso de tiempo fijo, independiente de los fps.
struct FixedTimestep: Sendable {
    /// Duración de cada paso de simulación (segundos).
    let step: Double
    /// Máximo tiempo de fotograma aceptado, para no "teletransportarse" tras una pausa.
    let maxFrameDelta: Double

    private(set) var accumulator: Double = 0

    init(step: Double = 1.0 / 120.0, maxFrameDelta: Double = 0.25) {
        self.step = step
        self.maxFrameDelta = maxFrameDelta
    }

    /// Añade el tiempo del fotograma y devuelve cuántos pasos fijos hay que simular.
    mutating func advance(by frameDelta: Double) -> Int {
        accumulator += min(max(frameDelta, 0), maxFrameDelta)
        let steps = Int(accumulator / step)
        accumulator -= Double(steps) * step
        return steps
    }

    mutating func reset() {
        accumulator = 0
    }
}
