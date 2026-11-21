import SpriteKit

/// Huellas que dejan los esquís en la nieve. Mantiene un número máximo de marcas
/// y recicla las más antiguas.
final class SkiTrailNode: SKNode {
    private let spacing: CGFloat = 5
    private let maxMarks = 600
    private let markColor = SKColor(red: 0.80, green: 0.84, blue: 0.92, alpha: 1)

    private var marks: [SKSpriteNode] = []
    private var nextIndex = 0
    private var lastPoint: CGPoint?

    /// Añade marcas si el Cuico se ha desplazado lo suficiente desde la última.
    func record(position: CGPoint, direction: SkiDirection) {
        guard let last = lastPoint else {
            lastPoint = position
            return
        }
        let distance = hypot(position.x - last.x, position.y - last.y)
        guard distance >= spacing else { return }
        lastPoint = position

        // Una marca por esquí, separadas en perpendicular a la dirección.
        let angle = CGFloat(direction.angle)
        let perpendicular = CGVector(dx: cos(angle) * 5, dy: sin(angle) * 5)
        let base = CGPoint(x: position.x, y: position.y - 4)
        addMark(at: CGPoint(x: base.x - perpendicular.dx, y: base.y - perpendicular.dy))
        addMark(at: CGPoint(x: base.x + perpendicular.dx, y: base.y + perpendicular.dy))
    }

    func clear() {
        removeAllChildren()
        marks.removeAll()
        nextIndex = 0
        lastPoint = nil
    }

    private func addMark(at point: CGPoint) {
        if marks.count < maxMarks {
            let mark = SKSpriteNode(color: markColor, size: CGSize(width: 2, height: 2))
            mark.position = point
            marks.append(mark)
            addChild(mark)
        } else {
            marks[nextIndex].position = point
            nextIndex = (nextIndex + 1) % maxMarks
        }
    }
}
