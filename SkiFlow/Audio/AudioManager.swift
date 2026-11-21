import AVFoundation
import Foundation

/// Lo que el juego necesita del audio. La escena y el modelo hablan con este
/// protocolo, así los tests pueden usar uno falso que solo anota lo que se pide.
@MainActor
protocol GameAudio: AnyObject {
    func play(_ effect: SoundEffect)
    /// Cambia de tema con un fundido (`nil` = silencio).
    func playMusic(_ track: MusicTrack?)
    /// Volumen del deslizar de los esquís (0…1).
    func setSlide(_ intensity: Double)
    /// Volumen del viento blanco (0…1).
    func setWind(_ intensity: Double)
    /// En pausa la música baja y los bucles se callan.
    func setPaused(_ paused: Bool)
    /// Volúmenes de los Ajustes (0…1).
    func setVolumes(music: Double, effects: Double)
}

/// Audio real con `AVAudioEngine`. Los sonidos se sintetizan en segundo plano al
/// arrancar; hasta que están listos, el juego simplemente no suena.
@MainActor
final class AudioManager: GameAudio {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
    private let musicBus = AVAudioMixerNode()
    private let effectsBus = AVAudioMixerNode()
    private let musicPlayers = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let effectPlayers = (0..<8).map { _ in AVAudioPlayerNode() }
    private var loopPlayers: [AmbientLoop: AVAudioPlayerNode] = [:]

    private var effectBuffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var musicBuffers: [MusicTrack: AVAudioPCMBuffer] = [:]
    private var loopBuffers: [AmbientLoop: AVAudioPCMBuffer] = [:]

    private var nextEffectPlayer = 0
    private var activeMusicPlayer = 0
    private(set) var currentTrack: MusicTrack?
    private var wantedTrack: MusicTrack?
    private var fadeTask: Task<Void, Never>?
    private var isPaused = false
    private var slide = 0.0
    private var wind = 0.0
    private(set) var isRunning = false

    var musicVolume: Double = 0.7 { didSet { musicBus.outputVolume = Float(musicVolume) } }
    var effectsVolume: Double = 0.8 { didSet { effectsBus.outputVolume = Float(effectsVolume) } }

    init(musicVolume: Double, effectsVolume: Double) {
        self.musicVolume = musicVolume
        self.effectsVolume = effectsVolume

        engine.attach(musicBus)
        engine.attach(effectsBus)
        engine.connect(musicBus, to: engine.mainMixerNode, format: format)
        engine.connect(effectsBus, to: engine.mainMixerNode, format: format)
        for player in musicPlayers + effectPlayers {
            engine.attach(player)
            engine.connect(player, to: musicPlayers.contains(player) ? musicBus : effectsBus, format: format)
        }
        for loop in AmbientLoop.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: effectsBus, format: format)
            player.volume = 0
            loopPlayers[loop] = player
        }
        musicBus.outputVolume = Float(musicVolume)
        effectsBus.outputVolume = Float(effectsVolume)

        do {
            try engine.start()
            isRunning = true
        } catch {
            // Sin salida de audio (por ejemplo, sin dispositivo): el juego sigue mudo.
            isRunning = false
        }
        prepareSounds()
    }

    /// Sintetiza todo en segundo plano y lo instala al terminar.
    private func prepareSounds() {
        Task.detached(priority: .userInitiated) {
            let effects = SoundEffect.allCases.map { ($0, $0.render()) }
            let loops = AmbientLoop.allCases.map { ($0, $0.render()) }
            let music = MusicTrack.allCases.map { ($0, $0.song.render()) }
            await MainActor.run { [weak self] in
                self?.install(effects: effects, loops: loops, music: music)
            }
        }
    }

    private func install(effects: [(SoundEffect, [Float])], loops: [(AmbientLoop, [Float])], music: [(MusicTrack, [Float])]) {
        for (effect, samples) in effects { effectBuffers[effect] = makeBuffer(samples) }
        for (track, samples) in music { musicBuffers[track] = makeBuffer(samples) }
        for (loop, samples) in loops {
            loopBuffers[loop] = makeBuffer(samples)
            if let buffer = loopBuffers[loop], let player = loopPlayers[loop], isRunning {
                player.scheduleBuffer(buffer, at: nil, options: .loops)
                player.play()
            }
        }
        // Si ya se había pedido un tema, empieza ahora.
        if let wantedTrack { startMusic(wantedTrack) }
        applyLoopVolumes()
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        return buffer
    }

    // MARK: GameAudio

    func play(_ effect: SoundEffect) {
        guard isRunning, !isPaused || effect == .uiClick, let buffer = effectBuffers[effect] else { return }
        let player = effectPlayers[nextEffectPlayer]
        nextEffectPlayer = (nextEffectPlayer + 1) % effectPlayers.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    func playMusic(_ track: MusicTrack?) {
        wantedTrack = track
        guard track != currentTrack else { return }
        startMusic(track)
    }

    private func startMusic(_ track: MusicTrack?) {
        guard isRunning else { return }
        let old = musicPlayers[activeMusicPlayer]
        var new: AVAudioPlayerNode?
        if let track, let buffer = musicBuffers[track] {
            activeMusicPlayer = 1 - activeMusicPlayer
            let player = musicPlayers[activeMusicPlayer]
            player.stop()
            player.volume = 0
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            new = player
            currentTrack = track
        } else if track == nil {
            currentTrack = nil
        } else {
            return // aún sintetizando: empezará en `install`
        }
        crossfade(from: old === new ? nil : old, to: new)
    }

    /// Fundido de 0,6 s entre dos temas.
    private func crossfade(from old: AVAudioPlayerNode?, to new: AVAudioPlayerNode?) {
        fadeTask?.cancel()
        let target: Float = isPaused ? 0.35 : 1
        let startOld = old?.volume ?? 0
        fadeTask = Task { @MainActor in
            let steps = 12
            for step in 1...steps {
                if Task.isCancelled { return }
                let progress = Float(step) / Float(steps)
                old?.volume = startOld * (1 - progress)
                new?.volume = target * progress
                try? await Task.sleep(for: .milliseconds(50))
            }
            old?.stop()
        }
    }

    func setSlide(_ intensity: Double) {
        slide = min(max(intensity, 0), 1)
        applyLoopVolumes()
    }

    func setWind(_ intensity: Double) {
        wind = min(max(intensity, 0), 1)
        applyLoopVolumes()
    }

    func setVolumes(music: Double, effects: Double) {
        musicVolume = music
        effectsVolume = effects
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        musicPlayers[activeMusicPlayer].volume = paused ? 0.35 : 1
        applyLoopVolumes()
    }

    private func applyLoopVolumes() {
        loopPlayers[.slide]?.volume = isPaused ? 0 : Float(slide * 0.35)
        loopPlayers[.wind]?.volume = isPaused ? 0 : Float(wind * 0.6)
    }
}
