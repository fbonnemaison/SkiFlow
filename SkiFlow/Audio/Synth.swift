import Foundation

/// Formas de onda del sintetizador chiptune.
enum Waveform: Sendable {
    /// Onda cuadrada con ciclo de trabajo (0,125 / 0,25 / 0,5), como las consolas de 8 bits.
    case square(duty: Double)
    case triangle
    case sine
    /// Ruido blanco (golpes, viento, nieve).
    case noise
}

/// Envolvente ADSR en segundos (el sostenido es un nivel de 0 a 1).
struct Envelope: Sendable {
    var attack: Double = 0.005
    var decay: Double = 0.05
    var sustain: Double = 0.7
    var release: Double = 0.05

    /// Pulsado: ataque inmediato y caída rápida (charango, golpes).
    static let pluck = Envelope(attack: 0.002, decay: 0.12, sustain: 0.15, release: 0.08)
    /// Soplado: entra suave y sostiene (quena).
    static let breath = Envelope(attack: 0.04, decay: 0.08, sustain: 0.8, release: 0.08)
    /// Golpe seco.
    static let hit = Envelope(attack: 0.001, decay: 0.08, sustain: 0, release: 0.02)

    /// Nivel en el instante `t` de una nota que dura `duration` (sin contar el release).
    func level(at t: Double, duration: Double) -> Double {
        if t < 0 { return 0 }
        if t < duration {
            if t < attack { return attack > 0 ? t / attack : 1 }
            let d = t - attack
            if d < decay { return 1 - (1 - sustain) * (d / max(decay, 1e-9)) }
            return sustain
        }
        let r = t - duration
        guard r < release, release > 0 else { return 0 }
        let start = level(at: duration - 1e-9, duration: duration)
        return start * (1 - r / release)
    }
}

/// Un sonido sintetizado: forma de onda, tono, duración y modulaciones.
struct Tone: Sendable {
    var wave: Waveform
    /// Frecuencia inicial en Hz (se ignora en el ruido).
    var frequency: Double
    var duration: Double
    var envelope = Envelope()
    var volume: Double = 0.5
    /// La frecuencia final es `frequency * slide` (glissando lineal).
    var slide: Double = 1
    /// Vibrato: (velocidad en Hz, profundidad en semitonos).
    var vibrato: (rate: Double, depth: Double)?
    /// Filtro paso bajo de un polo (0…1; menor = más apagado). `nil` = sin filtro.
    var lowpass: Double?
    var seed: UInt64 = 1
}

/// Sintetizador sencillo que genera muestras PCM en memoria. Todo es
/// determinista: el mismo sonido produce siempre las mismas muestras.
enum Synth {
    static let sampleRate: Double = 44_100

    /// Frecuencia de una nota MIDI (69 = La4 = 440 Hz).
    static func frequency(midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }

    static func sampleCount(seconds: Double) -> Int {
        Int((seconds * sampleRate).rounded())
    }

    /// Muestras de un tono, incluido su release.
    static func render(_ tone: Tone) -> [Float] {
        let total = sampleCount(seconds: tone.duration + tone.envelope.release)
        guard total > 0 else { return [] }
        var output = [Float](repeating: 0, count: total)
        var phase = 0.0
        var filtered = 0.0
        var rng = SeededRandom(seed: tone.seed)
        var noiseValue = 0.0
        var noiseCounter = 0
        let span = max(tone.duration, 1e-9)

        for i in 0..<total {
            let t = Double(i) / sampleRate
            let progress = min(t / span, 1)
            var frequency = tone.frequency * (1 + (tone.slide - 1) * progress)
            if let vibrato = tone.vibrato {
                frequency *= pow(2, vibrato.depth * sin(2 * .pi * vibrato.rate * t) / 12)
            }

            var sample: Double
            switch tone.wave {
            case let .square(duty):
                sample = phase < duty ? 1 : -1
            case .triangle:
                sample = phase < 0.5 ? 4 * phase - 1 : 3 - 4 * phase
            case .sine:
                sample = sin(2 * .pi * phase)
            case .noise:
                // Ruido "de consola": se mantiene cada valor unas pocas muestras.
                if noiseCounter <= 0 {
                    noiseValue = Double.random(in: -1...1, using: &rng)
                    noiseCounter = 2
                }
                noiseCounter -= 1
                sample = noiseValue
            }
            phase += frequency / sampleRate
            phase -= phase.rounded(.down)

            if let lowpass = tone.lowpass {
                filtered += lowpass * (sample - filtered)
                sample = filtered
            }

            let level = tone.envelope.level(at: t, duration: tone.duration)
            output[i] = Float(sample * level * tone.volume)
        }
        return output
    }

    /// Suma `samples` en `buffer` a partir de `offset`. Con `wrap`, lo que se pasa
    /// del final vuelve al principio (para bucles sin cortes).
    static func mix(_ samples: [Float], into buffer: inout [Float], at offset: Int, wrap: Bool = false) {
        guard !buffer.isEmpty else { return }
        for (i, value) in samples.enumerated() {
            var index = offset + i
            if index >= buffer.count {
                guard wrap else { return }
                index %= buffer.count
            }
            buffer[index] += value
        }
    }

    /// Concatena sonidos (con un silencio opcional entre ellos).
    static func sequence(_ parts: [[Float]], gap: Double = 0) -> [Float] {
        let silence = [Float](repeating: 0, count: sampleCount(seconds: gap))
        return parts.enumerated().flatMap { index, part in
            index == parts.count - 1 ? part : part + silence
        }
    }

    /// Superpone sonidos que empiezan a la vez.
    static func layer(_ parts: [[Float]]) -> [Float] {
        var buffer = [Float](repeating: 0, count: parts.map(\.count).max() ?? 0)
        for part in parts { mix(part, into: &buffer, at: 0) }
        return buffer
    }

    /// Limitador suave: evita saturar sin cortar a lo bruto.
    static func limit(_ samples: [Float], gain: Float = 1) -> [Float] {
        samples.map { tanhf($0 * gain) }
    }
}
