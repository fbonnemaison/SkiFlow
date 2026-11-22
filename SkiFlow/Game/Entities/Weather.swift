import Foundation

/// Algo que cambia en el clima.
enum WeatherEvent: Equatable, Sendable {
    /// Empieza una racha de viento (positivo = hacia la derecha).
    case gustStarted(direction: Double)
    case gustEnded
    case cloudsRolledIn
    case cloudsCleared
}

/// Clima de la bajada: a ratos se nubla un poco y de vez en cuando sopla una
/// racha de viento que empuja al Cuico hacia un lado. Es determinista con la
/// semilla de la montaña.
struct Weather: Sendable {
    struct Config: Sendable {
        /// Segundos de cielo despejado entre dos nublados.
        var clearDuration: ClosedRange<Double> = 25...60
        /// Duración de cada nublado.
        var cloudyDuration: ClosedRange<Double> = 15...35
        /// Cuánto se nubla (0 = despejado, 1 = el máximo).
        var cloudLevel: ClosedRange<Double> = 0.5...1
        /// Rapidez con la que cambian las nubes (fracción por segundo).
        var cloudFade: Double = 0.25
        /// ¿Hay rachas de viento? (no en los slalom, que son de precisión)
        var hasGusts = true
        /// Segundos de calma entre dos rachas.
        var calmDuration: ClosedRange<Double> = 18...40
        /// Duración de cada racha.
        var gustDuration: ClosedRange<Double> = 3...6
        /// Empuje lateral de la racha, en puntos/s.
        var gustStrength: ClosedRange<Double> = 45...85
        /// Segundos que tarda la racha en llegar a su fuerza y en calmarse.
        var gustRamp: Double = 0.8
    }

    let config: Config
    private var rng: SeededRandom

    /// Cuánto está nublado ahora (0…1), con fundido suave.
    private(set) var cloudCover: Double = 0
    private(set) var isCloudy = false
    private var cloudTarget: Double = 0
    private var cloudTimer: Double

    /// Empuje lateral actual de la racha (puntos/s, positivo = derecha).
    private(set) var gust: Double = 0
    private(set) var isGusting = false
    private var gustPeak: Double = 0
    private var gustElapsed: Double = 0
    private var gustLength: Double = 0
    private var gustTimer: Double

    init(config: Config = Config(), seed: UInt64) {
        self.config = config
        rng = SeededRandom(seed: seed ^ 0x3C1E_A7F0_9B2D_5E11)
        cloudTimer = 0
        gustTimer = 0
        cloudTimer = Double.random(in: config.clearDuration, using: &rng)
        gustTimer = Double.random(in: config.calmDuration, using: &rng)
    }

    /// Fuerza de la racha entre 0 y 1 (para el sonido y las partículas).
    var gustIntensity: Double {
        let peak = config.gustStrength.upperBound
        return peak > 0 ? min(1, abs(gust) / peak) : 0
    }

    /// Avanza un paso.
    mutating func update(dt: Double) -> [WeatherEvent] {
        var events: [WeatherEvent] = []

        // Nubes.
        cloudTimer -= dt
        if cloudTimer <= 0 {
            isCloudy.toggle()
            if isCloudy {
                cloudTarget = Double.random(in: config.cloudLevel, using: &rng)
                cloudTimer = Double.random(in: config.cloudyDuration, using: &rng)
                events.append(.cloudsRolledIn)
            } else {
                cloudTarget = 0
                cloudTimer = Double.random(in: config.clearDuration, using: &rng)
                events.append(.cloudsCleared)
            }
        }
        let step = config.cloudFade * dt
        cloudCover += max(-step, min(step, cloudTarget - cloudCover))

        // Rachas de viento.
        guard config.hasGusts else { return events }
        if isGusting {
            gustElapsed += dt
            let ramp = max(0.001, config.gustRamp)
            let rise = min(1, gustElapsed / ramp)
            let fall = min(1, max(0, gustLength - gustElapsed) / ramp)
            gust = gustPeak * min(rise, fall)
            if gustElapsed >= gustLength {
                isGusting = false
                gust = 0
                gustTimer = Double.random(in: config.calmDuration, using: &rng)
                events.append(.gustEnded)
            }
        } else {
            gustTimer -= dt
            if gustTimer <= 0 {
                isGusting = true
                let direction: Double = Bool.random(using: &rng) ? 1 : -1
                gustPeak = direction * Double.random(in: config.gustStrength, using: &rng)
                gustLength = Double.random(in: config.gustDuration, using: &rng)
                gustElapsed = 0
                events.append(.gustStarted(direction: direction))
            }
        }
        return events
    }
}
