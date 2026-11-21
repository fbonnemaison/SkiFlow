import Foundation
import Testing
@testable import SkiFlow

/// Audio falso: anota lo que pide el juego.
@MainActor
final class FakeAudio: GameAudio {
    var effects: [SoundEffect] = []
    var music: [MusicTrack?] = []
    var slide = 0.0
    var wind = 0.0
    var paused = false
    var volumes: (music: Double, effects: Double)?

    func play(_ effect: SoundEffect) { effects.append(effect) }
    func playMusic(_ track: MusicTrack?) { music.append(track) }
    func setSlide(_ intensity: Double) { slide = intensity }
    func setWind(_ intensity: Double) { wind = intensity }
    func setPaused(_ paused: Bool) { self.paused = paused }
    func setVolumes(music: Double, effects: Double) { volumes = (music, effects) }
}

struct SynthTests {
    @Test func noteFrequencies() {
        #expect(Synth.frequency(midi: 69) == 440)
        #expect(abs(Synth.frequency(midi: 81) - 880) < 1e-9)
        #expect(abs(Synth.frequency(midi: 60) - 261.6256) < 0.001)
    }

    @Test func envelopeShape() {
        let envelope = Envelope(attack: 0.1, decay: 0.1, sustain: 0.5, release: 0.2)
        #expect(envelope.level(at: 0.05, duration: 1) == 0.5) // mitad del ataque
        #expect(envelope.level(at: 0.1, duration: 1) == 1)
        #expect(abs(envelope.level(at: 0.5, duration: 1) - 0.5) < 1e-9)
        #expect(abs(envelope.level(at: 1.1, duration: 1) - 0.25) < 1e-6) // mitad del release
        #expect(envelope.level(at: 1.5, duration: 1) == 0)
    }

    @Test func toneLengthAndRange() {
        let tone = Tone(wave: .square(duty: 0.5), frequency: 440, duration: 0.5, envelope: Envelope(release: 0.1), volume: 0.8)
        let samples = Synth.render(tone)
        #expect(samples.count == Synth.sampleCount(seconds: 0.6))
        #expect(samples.allSatisfy { abs($0) <= 0.8 + 1e-6 })
        #expect(samples.contains { $0 > 0.5 })
    }

    @Test func renderingIsDeterministic() {
        let tone = Tone(wave: .noise, frequency: 0, duration: 0.2, lowpass: 0.3, seed: 42)
        #expect(Synth.render(tone) == Synth.render(tone))
        var other = tone
        other.seed = 43
        #expect(Synth.render(tone) != Synth.render(other))
    }

    @Test func mixingWrapsForLoops() {
        var buffer = [Float](repeating: 0, count: 4)
        Synth.mix([1, 1, 1], into: &buffer, at: 2, wrap: true)
        #expect(buffer == [1, 0, 1, 1])
        var clipped = [Float](repeating: 0, count: 4)
        Synth.mix([1, 1, 1], into: &clipped, at: 2)
        #expect(clipped == [0, 0, 1, 1])
    }

    @Test func limiterKeepsSamplesInRange() {
        #expect(Synth.limit([5, -5, 0]).allSatisfy { abs($0) <= 1 })
    }
}

struct SoundEffectTests {
    @Test func everyEffectRendersShortAndSafe() {
        for effect in SoundEffect.allCases {
            let samples = effect.render()
            #expect(!samples.isEmpty, "\(effect) vacío")
            #expect(Double(samples.count) / Synth.sampleRate < 2.5, "\(effect) demasiado largo")
            #expect(samples.allSatisfy { abs($0) <= 1 }, "\(effect) satura")
        }
    }

    @Test func loopsRender() {
        #expect(AmbientLoop.slide.render().count == Synth.sampleCount(seconds: 1))
        #expect(AmbientLoop.wind.render().count == Synth.sampleCount(seconds: 3))
    }
}

struct MusicTests {
    @Test func noteNames() {
        #expect(Song.midi(for: "A4") == 69)
        #expect(Song.midi(for: "C4") == 60)
        #expect(Song.midi(for: "D#5") == 75)
        #expect(Song.midi(for: "Bb3") == 58)
        #expect(Song.midi(for: "X9") == nil)
    }

    @Test func notationParsing() {
        let events = Song.parse("A4.2 -.2 | C5.1 K.1 S.2")
        #expect(events == [
            NoteEvent(pitch: .midi(69), start: 0, length: 2),
            NoteEvent(pitch: .midi(72), start: 4, length: 1),
            NoteEvent(pitch: .kick, start: 5, length: 1),
            NoteEvent(pitch: .snare, start: 6, length: 2),
        ])
    }

    @Test func everyVoiceFillsWholeBars() {
        for track in MusicTrack.allCases {
            let lengths = track.song.voices.map { voice in
                Song.parse(voice.notes).last.map { $0.start + $0.length } ?? 0
            }
            // Las voces pueden acabar en silencio, así que se cuentan los pasos totales.
            let totals = track.song.voices.map { voice in
                voice.notes.split(whereSeparator: { $0 == " " || $0 == "|" || $0 == "\n" })
                    .compactMap { $0.split(separator: ".").last.flatMap { Int($0) } }
                    .reduce(0, +)
            }
            #expect(Set(totals).count == 1, "\(track): voces de distinta longitud \(totals)")
            #expect(totals.first.map { $0 % 8 == 0 } == true, "\(track): compases incompletos")
            #expect(lengths.allSatisfy { $0 <= totals[0] })
        }
    }

    @Test func tracksRenderAsSeamlessLoops() {
        let song = MusicTrack.chupacabrasChase.song
        let samples = song.render()
        let expected = Synth.sampleCount(seconds: Double(song.lengthInSteps) * song.stepDuration)
        #expect(samples.count == expected)
        #expect(samples.allSatisfy { abs($0) <= 1 })
        #expect(samples.contains { abs($0) > 0.05 })
    }

    @Test func chaseThemesAreFasterThanTheMenu() {
        #expect(MusicTrack.kunkChase.song.bpm > MusicTrack.run.song.bpm)
        #expect(MusicTrack.run.song.bpm > MusicTrack.menu.song.bpm)
    }
}

@MainActor
struct GameAudioEventTests {
    private let dt = 1.0 / 120.0

    private func makeScene(mode: GameMode = .freeDescent, kunk: KunkChaser.Config = .init()) -> (GameScene, FakeAudio) {
        let scene = GameScene(size: GameConfig.sceneSize, seed: 3, mode: mode, kunkConfig: kunk, chupacabrasConfig: .init(chance: 0))
        let audio = FakeAudio()
        scene.audio = audio
        return (scene, audio)
    }

    @Test func runMusicWhenARunStarts() {
        let (scene, audio) = makeScene()
        scene.restart()
        #expect(audio.music.last == .run)
    }

    @Test func crashesHurt() {
        let (scene, audio) = makeScene()
        scene.apply(.crash, obstacleHitbox: .zero)
        #expect(audio.effects.suffix(2) == [.crash, .ouch])
        scene.apply(.trip, obstacleHitbox: .zero)
        #expect(audio.effects.last == .bump)
    }

    @Test func turningHopAndTurbo() {
        let (scene, audio) = makeScene()
        scene.handle(.left, pressed: true)
        #expect(audio.effects.last == .swish)
        scene.handle(.jump, pressed: true)
        #expect(audio.effects.last == .hop)
        scene.handle(.turbo, pressed: true)
        #expect(audio.effects.last == .turbo)
    }

    @Test func kunkRoarsAndTheMusicChanges() {
        let (scene, audio) = makeScene(kunk: .init(spawnMeters: 0))
        scene.simulate(dt: dt)
        #expect(audio.effects.contains(.kunkRoar))
        #expect(audio.music.last == .kunkChase)
    }

    @Test func slalomGatesSound() {
        let (scene, audio) = makeScene(mode: .slalom)
        scene.restart()
        guard let gate = scene.slalom?.course.gates.first else {
            Issue.record("Sin trazado")
            return
        }
        // Apunta a la primera puerta y baja hasta cruzarla.
        for _ in 0..<Int(4 / dt) where scene.slalom?.nextGate == 0 {
            scene.aimMouse(atScenePoint: CGPoint(x: gate.centerX, y: gate.y - 60))
            scene.simulate(dt: dt)
        }
        #expect(audio.effects.contains(.gate) || audio.effects.contains(.gateMissed))
    }

    @Test func slideFollowsTheSpeed() {
        let (scene, audio) = makeScene()
        for _ in 0..<120 { scene.simulate(dt: dt) }
        scene.update(1)
        #expect(audio.slide > 0.2)
        scene.setPaused(true)
        scene.update(2)
        #expect(audio.slide == 0)
    }

    @Test func modelDrivesMenuMusicAndPause() throws {
        let name = "SkiFlowTests.audio"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let audio = FakeAudio()
        let scene = GameScene(size: GameConfig.sceneSize, seed: 3, kunkConfig: .init(), chupacabrasConfig: .init(chance: 0))
        let model = GameModel(settings: SettingsStore(defaults: defaults), scene: scene, audio: audio)
        #expect(audio.music.last == .menu)
        #expect(audio.volumes?.music == model.settings.musicVolume)

        model.start(.freeDescent)
        #expect(audio.music.last == .run)
        model.togglePause()
        #expect(audio.paused)
        model.backToMenu()
        #expect(audio.music.last == .menu)
        #expect(!audio.paused)

        model.settings.musicVolume = 0.1
        model.applyVolumes()
        #expect(audio.volumes?.music == 0.1)
    }
}
