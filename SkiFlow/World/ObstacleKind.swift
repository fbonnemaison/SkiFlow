import CoreGraphics

/// Todo lo que puede aparecer en la montaña andina.
enum ObstacleKind: String, CaseIterable, Sendable {
    // Fijos
    case araucaria
    case quenua
    case rock
    case smallRock
    case cactus
    case apacheta
    case penitente
    case refugio
    case liftPylon
    case snowman

    // Terreno
    case ramp
    case iceZone
    case deepSnowZone
    case windZone

    // Móviles
    case llama
    case guanaco
    case vicuna
    case dog
    case fox
    case puma
    case condor

    // Rivales: no los genera la montaña, los maneja la escena (`RivalSkiers`).
    case argentine
    case brazilian
    case gringo

    /// Nombre en pantalla (y para depuración).
    var displayName: String {
        switch self {
        case .araucaria: "Araucaria"
        case .quenua: "Queñua"
        case .rock: "Roca"
        case .smallRock: "Piedra"
        case .cactus: "Cactus de altura"
        case .apacheta: "Apacheta"
        case .penitente: "Penitentes"
        case .refugio: "Refugio"
        case .liftPylon: "Torre del telesilla"
        case .snowman: "Mono de nieve"
        case .ramp: "Rampa"
        case .iceZone: "Hielo"
        case .deepSnowZone: "Nieve profunda"
        case .windZone: "Viento blanco"
        case .llama: "Llama"
        case .guanaco: "Guanaco"
        case .vicuna: "Vicuña"
        case .dog: "Perro de refugio"
        case .fox: "Zorro culpeo"
        case .puma: "Puma"
        case .argentine: "El Argentino"
        case .brazilian: "El Brasileño"
        case .gringo: "El Gringo"
        case .condor: "Cóndor"
        }
    }

    /// Zonas de terreno: no se chocan, cambian cómo se esquía.
    var isZone: Bool {
        switch self {
        case .iceZone, .deepSnowZone, .windZone: true
        default: false
        }
    }

    /// Obstáculos altos: también se chocan en pleno salto.
    var isTall: Bool {
        switch self {
        case .araucaria, .quenua, .cactus, .penitente, .refugio, .liftPylon: true
        default: false
        }
    }

    /// Tamaño de la caja de choque, apoyada en la base del objeto (en puntos).
    /// Solo cubre la base para que se pueda pasar "por detrás" de lo alto.
    var hitboxSize: CGSize {
        switch self {
        case .araucaria: CGSize(width: 18, height: 12)
        case .quenua: CGSize(width: 20, height: 12)
        case .rock: CGSize(width: 36, height: 14)
        case .smallRock: CGSize(width: 20, height: 8)
        case .cactus: CGSize(width: 18, height: 10)
        case .apacheta: CGSize(width: 33, height: 14)
        case .penitente: CGSize(width: 33, height: 14)
        case .refugio: CGSize(width: 114, height: 34)
        case .liftPylon: CGSize(width: 14, height: 10)
        case .snowman: CGSize(width: 24, height: 10)
        case .ramp: CGSize(width: 60, height: 10)
        case .llama, .guanaco: CGSize(width: 33, height: 10)
        case .vicuna: CGSize(width: 27, height: 10)
        case .dog: CGSize(width: 27, height: 10)
        case .fox: CGSize(width: 30, height: 8)
        case .puma: CGSize(width: 44, height: 10)
        case .argentine, .brazilian, .gringo: CGSize(width: 24, height: 10)
        case .condor: CGSize(width: 50, height: 14)
        case .iceZone, .deepSnowZone, .windZone: .zero
        }
    }
}
