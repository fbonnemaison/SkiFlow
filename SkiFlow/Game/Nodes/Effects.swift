import SpriteKit

/// Partículas de nieve: derrape, golpes, avalancha y viento blanco.
/// Las partículas son cuadraditos (pixel art) en vez de puntos suaves.
@MainActor
enum SnowEffects {
    static let flakeArt = PixelArt(rows: ["WW", "WW"], scale: 1, overrides: ["W": 0xFFFFFF], outlined: false)

    static var flakeTexture: SKTexture {
        SpriteFactory.shared.texture(named: "snow-flake", art: flakeArt)
    }

    private static func base() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = flakeTexture
        emitter.particleColor = SKColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleScale = GameConfig.pixelScale / 2
        emitter.particleScaleRange = 1
        emitter.particleAlphaSpeed = -1.6
        return emitter
    }

    /// Nieve que levantan los esquís al frenar o girar fuerte. Se regula con `birthRate`.
    static func spray() -> SKEmitterNode {
        let emitter = base()
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 0.45
        emitter.particleLifetimeRange = 0.2
        emitter.particleSpeed = 90
        emitter.particleSpeedRange = 60
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.particlePositionRange = CGVector(dx: 16, dy: 4)
        emitter.yAcceleration = -120
        return emitter
    }

    /// Estallido de nieve (caídas y aterrizajes). Se borra solo.
    static func burst(count: Int = 28) -> SKEmitterNode {
        let emitter = base()
        emitter.particleBirthRate = 600
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.3
        emitter.particleSpeed = 140
        emitter.particleSpeedRange = 80
        emitter.emissionAngleRange = 2 * .pi
        emitter.yAcceleration = -200
        emitter.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
        return emitter
    }

    /// Polvo de nieve a lo largo del frente de la avalancha.
    static func avalancheDust(width: CGFloat) -> SKEmitterNode {
        let emitter = base()
        emitter.particleBirthRate = 220
        emitter.particleLifetime = 0.9
        emitter.particleLifetimeRange = 0.4
        emitter.particleSpeed = 80
        emitter.particleSpeedRange = 60
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 2
        emitter.particlePositionRange = CGVector(dx: width, dy: 10)
        emitter.particleScale = GameConfig.pixelScale
        emitter.particleAlphaSpeed = -1
        return emitter
    }

    /// Ventisca de copos cruzando la pantalla (viento blanco). Va en la cámara.
    static func blizzard(size: CGSize) -> SKEmitterNode {
        let emitter = base()
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 2.5
        emitter.particleSpeed = 260
        emitter.particleSpeedRange = 120
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 0.3
        emitter.particlePositionRange = CGVector(dx: 0, dy: size.height * 1.2)
        emitter.position = CGPoint(x: size.width * 0.6, y: 0)
        emitter.particleAlphaSpeed = -0.3
        emitter.particleAlpha = 0.8
        return emitter
    }
}

/// Registro de la fuente pixel incluida en la app (Public Pixel, CC0).
@MainActor
enum PixelFont {
    /// Nombre PostScript de la fuente.
    nonisolated static let name = "PublicPixel"

    private static var registered = false

    /// Registra las fuentes de `Resources/Fonts` para esta app. Se puede llamar
    /// varias veces.
    static func register() {
        guard !registered else { return }
        registered = true
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
