import SwiftUI

@main
struct SkiFlowApp: App {
    var body: some Scene {
        WindowGroup("SkiFlow") {
            ContentView()
        }
        .defaultSize(width: GameConfig.sceneSize.width, height: GameConfig.sceneSize.height)
    }
}
