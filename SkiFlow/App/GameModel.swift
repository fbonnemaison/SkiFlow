import AppKit
import Observation

/// Estado de la app: qué pantalla se ve, el HUD, la pausa y el resultado de la
/// bajada. Hace de puente entre las vistas SwiftUI y la escena de SpriteKit.
@MainActor
@Observable
final class GameModel {
    enum Screen: Equatable {
        case title
        case playing
    }

    private(set) var screen: Screen = .title
    private(set) var hud = HUDSnapshot()
    private(set) var isPaused = false
    private(set) var outcome: RunOutcome?
    /// La bajada que acaba de terminar es el nuevo récord del modo.
    private(set) var isNewBest = false
    /// Puesto de la última bajada en el top 10 de su modo.
    private(set) var lastRank: Int?
    /// Mejores marcas en memoria, solo si no hay almacén (tests sin SwiftData).
    private(set) var sessionBests: [GameMode: Double] = [:]
    /// Se muestra la pantalla de récords.
    var isShowingRecords = false
    /// Cambia cada vez que se guardan o borran récords, para refrescar las vistas.
    private(set) var recordsVersion = 0

    var selectedMode: GameMode
    /// Semilla opcional escrita en el menú para repetir una montaña concreta.
    var seedText = ""

    @ObservationIgnored let scene: GameScene
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let audio: GameAudio?
    @ObservationIgnored let records: RecordStore?

    init(settings: SettingsStore, scene: GameScene? = nil, audio: GameAudio? = nil, records: RecordStore? = nil) {
        self.settings = settings
        self.audio = audio
        self.records = records
        let scene = scene ?? GameScene(size: GameConfig.sceneSize)
        self.scene = scene
        selectedMode = scene.mode
        scene.pixelZoom = CGFloat(settings.pixelZoom)

        scene.onHUDChange = { [weak self] hud in self?.hud = hud }
        scene.onPauseChange = { [weak self] paused in
            self?.isPaused = paused
            self?.audio?.setPaused(paused)
        }
        scene.onRunEnded = { [weak self] outcome in self?.runEnded(outcome) }
        scene.onRunStarted = { [weak self] mode in self?.runStarted(mode) }
        hud = scene.makeHUD()
        audio?.setVolumes(music: settings.musicVolume, effects: settings.effectsVolume)
        audio?.playMusic(.menu)
    }

    /// Aplica los volúmenes de los Ajustes.
    func applyVolumes() {
        audio?.setVolumes(music: settings.musicVolume, effects: settings.effectsVolume)
    }

    /// Semilla escrita en el menú, si es un número válido.
    var parsedSeed: UInt64? {
        UInt64(seedText.trimmingCharacters(in: .whitespaces))
    }

    /// Semilla de la montaña actual (para poder apuntarla y repetirla).
    var currentSeed: UInt64 { scene.seed }

    // MARK: Acciones

    func start(_ mode: GameMode) {
        audio?.play(.uiClick)
        // La escena solo suena mientras se juega.
        scene.audio = audio
        selectedMode = mode
        scene.pixelZoom = CGFloat(settings.pixelZoom)
        scene.restart(mode: mode, seed: parsedSeed)
        screen = .playing
    }

    /// Repite la bajada: misma montaña en los modos con meta, nueva en Descenso libre.
    func restartRun() {
        guard screen == .playing else { return }
        scene.restart()
    }

    /// Estrena montaña en el mismo modo.
    func newMountain() {
        guard screen == .playing else { return }
        scene.restart(mode: scene.mode)
    }

    func togglePause() {
        guard screen == .playing, outcome == nil else { return }
        scene.setPaused(!scene.isGamePaused)
    }

    func resume() {
        scene.setPaused(false)
    }

    func pauseIfPlaying() {
        guard screen == .playing, outcome == nil, !scene.isGamePaused else { return }
        scene.releaseAllInput()
        scene.setPaused(true)
    }

    func backToMenu() {
        audio?.play(.uiClick)
        scene.audio = nil
        audio?.setSlide(0)
        audio?.setWind(0)
        audio?.playMusic(.menu)
        audio?.setPaused(false)
        scene.releaseAllInput()
        if !scene.isGamePaused { scene.setPaused(true) }
        outcome = nil
        isNewBest = false
        lastRank = nil
        screen = .title
    }

    /// Récord de un modo ya formateado (guardado, o de la sesión si no hay almacén).
    func best(for mode: GameMode) -> String? {
        _ = recordsVersion
        if let records {
            return records.best(mode).map { mode.formatRecord($0.value) }
        }
        return sessionBests[mode].map(mode.formatRecord)
    }

    /// Top 10 de un modo.
    func topRecords(for mode: GameMode) -> [RunRecord] {
        _ = recordsVersion
        return records?.top(mode) ?? []
    }

    var stats: PlayerStats? {
        _ = recordsVersion
        return records?.stats
    }

    /// Vuelve a jugar la montaña de un récord.
    func replay(_ record: RunRecord) {
        isShowingRecords = false
        seedText = String(record.seed)
        start(record.mode)
    }

    func resetRecords() {
        records?.reset()
        sessionBests.removeAll()
        recordsVersion += 1
    }

    // MARK: Entrada

    /// Traduce una tecla según la asignación de los Ajustes. Devuelve `true` si el
    /// juego la usó (y no debe llegar a nadie más).
    ///
    /// Las repeticiones automáticas se tragan (para que no pite) pero no se
    /// reenvían: el juego gestiona su propia repetición de giro.
    func handleKey(_ keyCode: UInt16, pressed: Bool, isRepeat: Bool = false, window: NSWindow?) -> Bool {
        guard !settings.isCapturingKey else { return false }

        switch screen {
        case .title:
            // ↩︎ empieza el modo elegido.
            guard keyCode == 36, pressed, !isRepeat, window?.isKeyWindow ?? true else { return false }
            start(selectedMode)
            return true
        case .playing:
            guard window == nil || window === scene.view?.window,
                  let action = settings.keyBindings.action(for: keyCode)
            else { return false }
            if !isRepeat {
                scene.handle(action, pressed: pressed, source: .keyboard)
            }
            return true
        }
    }

    func handleMouseMove(windowPoint: CGPoint, window: NSWindow?) -> Bool {
        guard screen == .playing, outcome == nil, !isPaused else { return false }
        return scene.aimMouse(windowPoint: windowPoint, window: window)
    }

    func handleMouseButton(pressed: Bool) {
        guard screen == .playing, outcome == nil, !isPaused else {
            if !pressed { scene.handle(.jump, pressed: false, source: .mouse) }
            return
        }
        scene.handle(.jump, pressed: pressed, source: .mouse)
    }

    // MARK: Avisos de la escena

    private func runStarted(_ mode: GameMode) {
        selectedMode = mode
        outcome = nil
        isNewBest = false
        lastRank = nil
    }

    private func runEnded(_ outcome: RunOutcome) {
        let mode = scene.mode
        if let records {
            let placement = records.register(RunReport(
                mode: mode,
                outcome: outcome,
                seed: scene.seed,
                meters: scene.skier.distanceMeters,
                seconds: scene.elapsed,
                crashes: scene.crashes,
                chupacabrasEncounters: scene.chupacabrasEncounters
            ))
            lastRank = placement.rank
            isNewBest = placement.isNewBest
            recordsVersion += 1
        } else if let value = outcome.recordValue(in: mode) {
            isNewBest = mode.isBetter(value, than: sessionBests[mode])
            lastRank = isNewBest ? 1 : nil
            if isNewBest { sessionBests[mode] = value }
        } else {
            isNewBest = false
            lastRank = nil
        }
        self.outcome = outcome
    }
}
