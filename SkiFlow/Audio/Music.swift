import Foundation

/// Instrumentos chiptune con aire andino.
enum Instrument: Sendable {
    /// Flauta de caña: onda triangular soplada con vibrato.
    case quena
    /// Cuerdas pulsadas: cuadrada fina y corta.
    case charango
    /// Bajo suave.
    case bass
    /// Bombo legüero y percusión: K (bombo), S (caja), H (charrasca).
    case drums
}

/// Una voz de una canción: un instrumento y sus notas en texto.
///
/// Notación: `nota.duración` separadas por espacios, con la duración en
/// semicorcheas. `A4.2` es un La4 de dos semicorcheas, `D#5.1` un Re♯5, `-.4` un
/// silencio. En la batería, `K`, `S` y `H` son los golpes. Las barras `|` solo
/// sirven para leer mejor los compases.
struct Voice: Sendable {
    let instrument: Instrument
    let notes: String
    var volume: Double = 1
}

/// Un evento ya interpretado: nota MIDI (o golpe), inicio y duración en semicorcheas.
struct NoteEvent: Equatable, Sendable {
    enum Pitch: Equatable, Sendable {
        case midi(Int)
        case kick
        case snare
        case hat
    }

    let pitch: Pitch
    let start: Int
    let length: Int
}

/// Una canción en bucle.
struct Song: Sendable {
    let bpm: Double
    let voices: [Voice]

    /// Segundos por semicorchea.
    var stepDuration: Double { 60 / bpm / 4 }

    /// Longitud del bucle en semicorcheas (la voz más larga).
    var lengthInSteps: Int {
        voices.map { Self.parse($0.notes).reduce(0) { max($0, $1.start + $1.length) } }.max() ?? 0
    }

    /// Interpreta la notación de una voz.
    static func parse(_ text: String) -> [NoteEvent] {
        var events: [NoteEvent] = []
        var cursor = 0
        for token in text.split(whereSeparator: { $0 == " " || $0 == "|" || $0 == "\n" }) {
            let parts = token.split(separator: ".")
            guard parts.count == 2, let length = Int(parts[1]), length > 0 else { continue }
            let name = String(parts[0])
            let pitch: NoteEvent.Pitch?
            switch name {
            case "-": pitch = nil
            case "K": pitch = .kick
            case "S": pitch = .snare
            case "H": pitch = .hat
            default: pitch = midi(for: name).map(NoteEvent.Pitch.midi)
            }
            if let pitch {
                events.append(NoteEvent(pitch: pitch, start: cursor, length: length))
            }
            cursor += length
        }
        return events
    }

    /// `A4` → 69, `C#5` → 73, `Bb3` → 58.
    static func midi(for name: String) -> Int? {
        let semitones: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let letter = name.first, let base = semitones[letter] else { return nil }
        var rest = name.dropFirst()
        var offset = 0
        if rest.first == "#" { offset = 1; rest = rest.dropFirst() } else if rest.first == "b" { offset = -1; rest = rest.dropFirst() }
        guard let octave = Int(rest) else { return nil }
        return 12 * (octave + 1) + base + offset
    }

    /// Renderiza el bucle completo. Las colas de las notas finales vuelven al
    /// principio para que el bucle no tenga cortes.
    func render() -> [Float] {
        let step = stepDuration
        let total = Synth.sampleCount(seconds: Double(lengthInSteps) * step)
        guard total > 0 else { return [] }
        var buffer = [Float](repeating: 0, count: total)
        for (voiceIndex, voice) in voices.enumerated() {
            for (eventIndex, event) in Self.parse(voice.notes).enumerated() {
                let tone = Self.tone(for: event, instrument: voice.instrument, step: step,
                                     seed: UInt64(voiceIndex * 10_000 + eventIndex + 1))
                var samples = Synth.render(tone)
                if voice.volume != 1 { samples = samples.map { $0 * Float(voice.volume) } }
                Synth.mix(samples, into: &buffer, at: Synth.sampleCount(seconds: Double(event.start) * step), wrap: true)
            }
        }
        return Synth.limit(buffer, gain: 0.9)
    }

    private static func tone(for event: NoteEvent, instrument: Instrument, step: Double, seed: UInt64) -> Tone {
        let duration = Double(event.length) * step
        switch (instrument, event.pitch) {
        case let (.quena, .midi(note)):
            return Tone(wave: .triangle, frequency: Synth.frequency(midi: note), duration: duration * 0.95,
                        envelope: .breath, volume: 0.32, vibrato: (rate: 5.5, depth: 0.25), seed: seed)
        case let (.charango, .midi(note)):
            return Tone(wave: .square(duty: 0.125), frequency: Synth.frequency(midi: note), duration: min(duration, 0.12),
                        envelope: .pluck, volume: 0.10, seed: seed)
        case let (.bass, .midi(note)):
            return Tone(wave: .triangle, frequency: Synth.frequency(midi: note), duration: duration * 0.85,
                        envelope: Envelope(attack: 0.005, decay: 0.1, sustain: 0.6, release: 0.04), volume: 0.38, seed: seed)
        case (_, .kick):
            return Tone(wave: .sine, frequency: 110, duration: 0.12, envelope: .hit, volume: 0.6, slide: 0.45, seed: seed)
        case (_, .snare):
            return Tone(wave: .noise, frequency: 0, duration: 0.08, envelope: .hit, volume: 0.22, lowpass: 0.5, seed: seed)
        case (_, .hat):
            return Tone(wave: .noise, frequency: 0, duration: 0.03, envelope: .hit, volume: 0.1, seed: seed)
        case let (.drums, .midi(note)):
            return Tone(wave: .sine, frequency: Synth.frequency(midi: note), duration: 0.1, envelope: .hit, volume: 0.4, seed: seed)
        }
    }
}

/// Temas musicales del juego (todos originales, en La menor pentatónica).
enum MusicTrack: String, CaseIterable, Sendable {
    /// Menú: tranquilo, como un amanecer en la cordillera.
    case menu
    /// Bajada normal: huayno alegre.
    case run
    /// Persecución del Kunk: rápido y con bajo insistente.
    case kunkChase
    /// Acecho del Chupacabras: inquietante, con tritonos y latido.
    case chupacabrasChase

    var song: Song {
        switch self {
        case .menu: Self.menuSong
        case .run: Self.runSong
        case .kunkChase: Self.kunkSong
        case .chupacabrasChase: Self.chupacabrasSong
        }
    }

    // Acordes arpegiados del charango (un compás de 2/4 = 8 semicorcheas).
    private static let am = "A3.1 E4.1 A4.1 E4.1 C4.1 E4.1 A4.1 E4.1"
    private static let c = "C4.1 G4.1 C5.1 G4.1 E4.1 G4.1 C5.1 G4.1"
    private static let g = "G3.1 D4.1 G4.1 D4.1 B3.1 D4.1 G4.1 D4.1"
    private static let em = "E3.1 B3.1 E4.1 B3.1 G3.1 B3.1 E4.1 B3.1"
    private static let f = "F3.1 C4.1 F4.1 C4.1 A3.1 C4.1 F4.1 C4.1"

    private static func bars(_ chords: [String]) -> String { chords.joined(separator: " | ") }

    static let runSong = Song(bpm: 132, voices: [
        Voice(instrument: .quena, notes: """
            A4.2 C5.1 D5.1 E5.2 E5.2 | G5.2 E5.1 D5.1 C5.2 A4.2 | C5.2 D5.1 E5.1 G5.2 A5.2 | G5.2 E5.2 D5.4 |
            E5.2 G5.1 A5.1 G5.2 E5.2 | D5.2 E5.1 D5.1 C5.2 A4.2 | C5.2 A4.1 C5.1 D5.2 E5.2 | A4.6 -.2
            """),
        Voice(instrument: .charango, notes: bars([am, c, g, em, c, g, c, am])),
        Voice(instrument: .bass, notes: "A2.4 A2.4 | C3.4 C3.4 | G2.4 G2.4 | E2.4 E2.4 | C3.4 C3.4 | G2.4 G2.4 | C3.4 C3.4 | A2.4 A2.4"),
        // Ritmo de huayno: largo-corto-corto.
        Voice(instrument: .drums, notes: Array(repeating: "K.2 H.1 H.1 K.1 K.1 S.2", count: 8).joined(separator: " | ")),
    ])

    static let menuSong = Song(bpm: 92, voices: [
        Voice(instrument: .quena, notes: """
            E5.4 D5.2 C5.2 | A4.8 | C5.4 D5.2 E5.2 | G5.8 | A5.4 G5.2 E5.2 | D5.8 | C5.4 D5.2 C5.2 | A4.8
            """),
        Voice(instrument: .charango, notes: bars([am, c, g, em, c, g, c, am]), volume: 0.7),
        Voice(instrument: .bass, notes: "A2.8 | C3.8 | G2.8 | E2.8 | C3.8 | G2.8 | C3.8 | A2.8"),
        Voice(instrument: .drums, notes: Array(repeating: "K.4 H.4", count: 8).joined(separator: " | "), volume: 0.6),
    ])

    static let kunkSong = Song(bpm: 160, voices: [
        Voice(instrument: .quena, notes: """
            A5.1 -.1 A5.1 G5.1 E5.2 D5.2 | C5.1 -.1 C5.1 D5.1 E5.4 | F5.1 -.1 F5.1 E5.1 C5.2 A4.2 | G4.2 A4.2 B4.2 G4.2 |
            A5.1 -.1 A5.1 G5.1 E5.2 D5.2 | C5.1 -.1 C5.1 D5.1 E5.4 | F5.2 E5.2 D5.2 C5.2 | B4.2 G4.2 A4.4
            """),
        Voice(instrument: .charango, notes: bars([am, am, f, g, am, am, f, g])),
        Voice(instrument: .bass, notes: Array(repeating: "A2.1 A2.1 A3.1 A2.1", count: 4).joined(separator: " ") + " "
            + Array(repeating: "F2.1 F2.1 F3.1 F2.1", count: 2).joined(separator: " ") + " "
            + Array(repeating: "G2.1 G2.1 G3.1 G2.1", count: 2).joined(separator: " ") + " "
            + Array(repeating: "A2.1 A2.1 A3.1 A2.1", count: 4).joined(separator: " ") + " "
            + Array(repeating: "F2.1 F2.1 F3.1 F2.1", count: 2).joined(separator: " ") + " "
            + Array(repeating: "G2.1 G2.1 G3.1 G2.1", count: 2).joined(separator: " ")),
        Voice(instrument: .drums, notes: Array(repeating: "K.1 H.1 S.1 H.1 K.1 K.1 S.1 H.1", count: 8).joined(separator: " | ")),
    ])

    static let chupacabrasSong = Song(bpm: 116, voices: [
        Voice(instrument: .quena, notes: """
            A4.4 D#5.4 | E5.2 D#5.2 A4.4 | -.8 | C5.2 B4.2 A4.4 | A4.4 D#5.4 | F5.2 E5.2 D#5.4 | -.8 | B4.2 A4.2 -.4
            """, volume: 0.9),
        Voice(instrument: .bass, notes: "A2.8 | A2.8 | D#3.8 | A2.8 | A2.8 | A2.8 | D#3.8 | E2.8"),
        // Latido: dos golpes y silencio.
        Voice(instrument: .drums, notes: Array(repeating: "K.1 -.1 K.1 -.3 H.2", count: 8).joined(separator: " | ")),
    ])
}
