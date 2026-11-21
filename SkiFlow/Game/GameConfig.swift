import CoreGraphics
import SpriteKit

/// Constantes globales del juego.
enum GameConfig {
    /// Tamaño lógico de la escena (en puntos). La vista lo escala para llenar la ventana.
    static let sceneSize = CGSize(width: 1024, height: 768)

    /// Puntos de escena por píxel de sprite (todos los sprites usan la misma
    /// escala para que el pixel art sea coherente; los árboles grandes usan 4).
    static let pixelScale: CGFloat = 3

    /// Escala del mundo: puntos de escena por metro.
    static let pointsPerMeter: Double = 16

    /// Fracción de la altura de pantalla que la cámara se adelanta por debajo del
    /// Cuico, para que se vea más montaña por delante.
    static let cameraLookAhead: CGFloat = 0.2

    /// Color de la nieve de fondo.
    static let snowColor = SKColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1.0)
}
