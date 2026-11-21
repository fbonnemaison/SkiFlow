import Foundation

/// Momentos en los que el Cuico dice algo.
enum CuicoMoment: CaseIterable, Sendable {
    case runStart
    case crash
    case trip
    case gateMissed
    case kunk
    case chupacabras
    case selfie
    case cleanLanding
    /// Parado un rato: saca el teléfono para la foto.
    case idle
    /// Easter egg: bajó la altura del Aconcagua.
    case aconcagua

    /// Frases del Cuico (borrador: la personalidad definitiva la afina App-Zilla).
    var lines: [String] {
        switch self {
        case .runStart:
            ["¡Vamos que se puede!", "Primera bajada de la temporada, ¿cachai?",
             "Este outfit es para la foto, no para caerse.", "¡Qué nieve más bacán!"]
        case .crash:
            ["¡Pucha, mi parka nueva!", "¡Nadie vio eso!", "Fue a propósito…",
             "¡Auch! Mis antiparras…", "La nieve estaba mala, po."]
        case .trip:
            ["¡Uy!", "Casi, casi…", "Ni se notó."]
        case .gateMissed:
            ["Esa puerta no contaba.", "¿Había una puerta ahí?"]
        case .kunk:
            ["¡¿Qué es esa cosa?!", "¡El Kunk! ¡Turbo, turbo!", "¡No me alcanza, no me alcanza!"]
        case .chupacabras:
            ["¿Escuchaste eso?", "Algo me está mirando…"]
        case .selfie:
            ["¡Para las redes!", "¡Sonrían!", "Esta va de perfil."]
        case .cleanLanding:
            ["¡Clavado!", "¡Eso es estilo!"]
        case .idle:
            ["Una fotito con la cordillera…", "Espérate, que salgo mal.",
             "¿Me veo bien con estas antiparras?"]
        case .aconcagua:
            ["¡Bajé un Aconcagua entero!"]
        }
    }

    /// Los avisos importantes se dicen aunque haga poco que habló.
    var isUrgent: Bool {
        switch self {
        case .kunk, .chupacabras, .aconcagua: true
        default: false
        }
    }
}

/// Decide qué dice el Cuico y cuándo, para que no hable sin parar.
struct CuicoVoice: Sendable {
    /// Segundos mínimos entre frases normales.
    static let cooldown: Double = 3

    private var rng: SeededRandom
    private var lastTime: Double = -.infinity
    private var lastLine: String?

    init(seed: UInt64) {
        rng = SeededRandom(seed: seed ^ 0xC0C0_CAFE)
    }

    /// Frase para un momento en el instante `time`, o `nil` si toca callarse.
    mutating func line(for moment: CuicoMoment, at time: Double) -> String? {
        guard moment.isUrgent || time - lastTime >= Self.cooldown else { return nil }
        var options = moment.lines
        if options.count > 1, let lastLine { options.removeAll { $0 == lastLine } }
        guard !options.isEmpty else { return nil }
        let line = options[Int.random(in: 0..<options.count, using: &rng)]
        lastTime = time
        lastLine = line
        return line
    }
}

/// Easter egg: escribir una palabra secreta en el menú.
struct SecretCode: Sendable {
    let keyCodes: [UInt16]
    private var progress = 0

    /// C-U-I-C-O (códigos de tecla físicos).
    static let cuico = SecretCode(keyCodes: [8, 32, 34, 8, 31])

    init(keyCodes: [UInt16]) {
        self.keyCodes = keyCodes
    }

    /// Anota una tecla. Devuelve `true` cuando se completa el código.
    mutating func register(_ keyCode: UInt16) -> Bool {
        if keyCode == keyCodes[progress] {
            progress += 1
        } else {
            progress = keyCode == keyCodes[0] ? 1 : 0
        }
        if progress == keyCodes.count {
            progress = 0
            return true
        }
        return false
    }
}
