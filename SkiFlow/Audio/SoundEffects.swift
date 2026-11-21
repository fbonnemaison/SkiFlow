import Foundation

/// Efectos de sonido del juego, sintetizados al arrancar.
enum SoundEffect: String, CaseIterable, Sendable {
    /// Girar los esquís.
    case swish
    case turbo
    /// Brinco a voluntad.
    case hop
    /// Salto de rampa.
    case jump
    case land
    case crash
    /// La queja del Cuico al caerse.
    case ouch
    /// Tropiezo con una piedra.
    case bump
    case gate
    case gateMissed
    case finish
    case caught
    case trick
    case cleanLanding
    case selfie
    case kunkRoar
    case chupacabrasScreech
    case avalancheRumble
    case uiClick

    /// Muestras del efecto (mono, 44,1 kHz).
    func render() -> [Float] {
        let n = Synth.frequency(midi:)
        switch self {
        case .swish:
            return Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.1, envelope: .hit, volume: 0.18, lowpass: 0.35))
        case .turbo:
            return Synth.layer([
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.35, envelope: .breath, volume: 0.25, lowpass: 0.25)),
                Synth.render(Tone(wave: .square(duty: 0.25), frequency: 220, duration: 0.3, envelope: .breath, volume: 0.12, slide: 3)),
            ])
        case .hop:
            return Synth.render(Tone(wave: .square(duty: 0.5), frequency: 330, duration: 0.1, envelope: .pluck, volume: 0.25, slide: 2))
        case .jump:
            return Synth.render(Tone(wave: .square(duty: 0.25), frequency: 220, duration: 0.25, envelope: .breath, volume: 0.3, slide: 4))
        case .land:
            return Synth.layer([
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.08, envelope: .hit, volume: 0.35, lowpass: 0.2)),
                Synth.render(Tone(wave: .sine, frequency: 110, duration: 0.1, envelope: .hit, volume: 0.5, slide: 0.6)),
            ])
        case .crash:
            return Synth.layer([
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.35, envelope: Envelope(attack: 0.001, decay: 0.3, sustain: 0, release: 0.05), volume: 0.5, lowpass: 0.4)),
                Synth.render(Tone(wave: .square(duty: 0.5), frequency: 400, duration: 0.3, envelope: .pluck, volume: 0.25, slide: 0.2)),
            ])
        case .ouch:
            // "¡Ay!": un quejido agudo que baja.
            return Synth.render(Tone(wave: .square(duty: 0.25), frequency: 880, duration: 0.28, envelope: .breath, volume: 0.22, slide: 0.55, vibrato: (rate: 14, depth: 0.6)))
        case .bump:
            return Synth.layer([
                Synth.render(Tone(wave: .sine, frequency: 140, duration: 0.08, envelope: .hit, volume: 0.45)),
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.05, envelope: .hit, volume: 0.2, lowpass: 0.3)),
            ])
        case .gate:
            return Synth.sequence([
                Synth.render(Tone(wave: .triangle, frequency: n(84), duration: 0.06, envelope: .pluck, volume: 0.35)),
                Synth.render(Tone(wave: .triangle, frequency: n(88), duration: 0.12, envelope: .pluck, volume: 0.35)),
            ])
        case .gateMissed:
            return Synth.render(Tone(wave: .square(duty: 0.5), frequency: 110, duration: 0.25, envelope: .breath, volume: 0.25, slide: 0.9))
        case .finish:
            return Synth.sequence([69, 72, 76, 81].map { midi in
                Synth.layer([
                    Synth.render(Tone(wave: .triangle, frequency: n(midi), duration: 0.13, envelope: .pluck, volume: 0.35)),
                    Synth.render(Tone(wave: .square(duty: 0.125), frequency: n(midi + 12), duration: 0.13, envelope: .pluck, volume: 0.12)),
                ])
            } + [Synth.render(Tone(wave: .triangle, frequency: n(81), duration: 0.4, envelope: .breath, volume: 0.35, vibrato: (rate: 6, depth: 0.2)))])
        case .caught:
            return Synth.sequence([64, 62, 60, 57].map { midi in
                Synth.render(Tone(wave: .square(duty: 0.5), frequency: n(midi), duration: 0.18, envelope: .breath, volume: 0.22))
            })
        case .trick:
            return Synth.sequence([76, 81].map { midi in
                Synth.render(Tone(wave: .triangle, frequency: n(midi), duration: 0.05, envelope: .pluck, volume: 0.3))
            })
        case .cleanLanding:
            return Synth.layer([
                Synth.render(Tone(wave: .triangle, frequency: n(81), duration: 0.3, envelope: .pluck, volume: 0.3)),
                Synth.render(Tone(wave: .triangle, frequency: n(88), duration: 0.3, envelope: .pluck, volume: 0.2)),
            ])
        case .selfie:
            // Obturador: dos clics.
            return Synth.sequence([
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.015, envelope: .hit, volume: 0.35)),
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.02, envelope: .hit, volume: 0.3)),
            ], gap: 0.05)
        case .kunkRoar:
            return Synth.layer([
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.9, envelope: Envelope(attack: 0.05, decay: 0.3, sustain: 0.6, release: 0.3), volume: 0.45, lowpass: 0.08)),
                Synth.render(Tone(wave: .square(duty: 0.5), frequency: 75, duration: 0.9, envelope: .breath, volume: 0.25, slide: 0.75, vibrato: (rate: 9, depth: 0.8))),
            ])
        case .chupacabrasScreech:
            return Synth.layer([
                Synth.render(Tone(wave: .square(duty: 0.125), frequency: 1800, duration: 0.5, envelope: .breath, volume: 0.15, slide: 1.4, vibrato: (rate: 22, depth: 1.2))),
                Synth.render(Tone(wave: .noise, frequency: 0, duration: 0.4, envelope: .breath, volume: 0.12, lowpass: 0.7)),
            ])
        case .avalancheRumble:
            return Synth.render(Tone(wave: .noise, frequency: 0, duration: 1.6, envelope: Envelope(attack: 0.3, decay: 0.4, sustain: 0.7, release: 0.5), volume: 0.6, lowpass: 0.04))
        case .uiClick:
            return Synth.render(Tone(wave: .square(duty: 0.5), frequency: 1000, duration: 0.025, envelope: .hit, volume: 0.15))
        }
    }
}

/// Sonidos continuos en bucle cuyo volumen sigue al juego.
enum AmbientLoop: String, CaseIterable, Sendable {
    /// Los esquís sobre la nieve (sube con la velocidad).
    case slide
    /// Viento blanco.
    case wind

    /// Muestras del bucle; el final enlaza con el principio.
    func render() -> [Float] {
        switch self {
        case .slide:
            return Synth.render(Tone(wave: .noise, frequency: 0, duration: 1, envelope: Envelope(attack: 0, decay: 0, sustain: 1, release: 0), volume: 0.5, lowpass: 0.3, seed: 7))
        case .wind:
            // Ruido muy filtrado con una ondulación lenta, como ráfagas.
            let base = Synth.render(Tone(wave: .noise, frequency: 0, duration: 3, envelope: Envelope(attack: 0, decay: 0, sustain: 1, release: 0), volume: 0.7, lowpass: 0.05, seed: 11))
            return base.enumerated().map { i, value in
                let t = Double(i) / Synth.sampleRate
                return value * Float(0.6 + 0.4 * sin(2 * .pi * t / 3))
            }
        }
    }
}
