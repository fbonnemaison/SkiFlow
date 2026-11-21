import CoreGraphics
import Foundation

/// Orientación de los esquís del Cuico respecto a la línea de máxima pendiente.
///
/// Hay 9 posiciones: recto hacia abajo, 3 inclinaciones por lado y la posición
/// atravesada (de lado), que sirve para frenar. Los valores negativos apuntan a la
/// izquierda de la pantalla y los positivos a la derecha.
enum SkiDirection: Int, CaseIterable, Sendable {
    case hardLeft = -4
    case left3 = -3
    case left2 = -2
    case left1 = -1
    case down = 0
    case right1 = 1
    case right2 = 2
    case right3 = 3
    case hardRight = 4

    /// Ángulo entre dos posiciones consecutivas (22,5°).
    static let stepAngle = Double.pi / 8

    /// Ángulo en radianes respecto a la pendiente (0 = abajo, positivo = derecha).
    var angle: Double { Double(rawValue) * Self.stepAngle }

    /// `true` cuando los esquís están atravesados a la pendiente.
    var isSideways: Bool { abs(rawValue) == 4 }

    /// Vector unitario de avance en coordenadas de escena (y crece hacia arriba).
    var unitVector: (dx: Double, dy: Double) { (sin(angle), -cos(angle)) }

    /// Gira un paso hacia la izquierda de la pantalla (sin pasar de `hardLeft`).
    func turnedLeft() -> SkiDirection {
        SkiDirection(rawValue: max(rawValue - 1, Self.hardLeft.rawValue)) ?? .hardLeft
    }

    /// Gira un paso hacia la derecha de la pantalla (sin pasar de `hardRight`).
    func turnedRight() -> SkiDirection {
        SkiDirection(rawValue: min(rawValue + 1, Self.hardRight.rawValue)) ?? .hardRight
    }

    /// Dirección más parecida a un vector en coordenadas de escena (y hacia arriba).
    /// Si el vector apunta cuesta arriba, el Cuico se atraviesa hacia ese lado y frena.
    static func aiming(at vector: CGVector) -> SkiDirection {
        if vector.dy >= 0 {
            return vector.dx < 0 ? .hardLeft : .hardRight
        }
        let angle = atan2(Double(vector.dx), -Double(vector.dy))
        let steps = Int((angle / stepAngle).rounded())
        return SkiDirection(rawValue: min(max(steps, hardLeft.rawValue), hardRight.rawValue)) ?? .down
    }

    /// Posición atravesada del lado hacia el que se mira (izquierda si va recto).
    func braking() -> SkiDirection {
        rawValue > 0 ? .hardRight : .hardLeft
    }
}
