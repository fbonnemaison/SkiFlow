import CoreGraphics
import SpriteKit

/// Constantes globales del juego.
enum GameConfig {
    /// Tamaño lógico de la escena (en puntos). La vista lo escala para llenar la ventana.
    static let sceneSize = CGSize(width: 1024, height: 768)

    /// Color de la nieve de fondo.
    static let snowColor = SKColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1.0)
}
