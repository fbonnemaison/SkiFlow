import AppKit
import SpriteKit
import Testing
@testable import SkiFlow

@MainActor
struct PixelArtTests {
    @Test func outlineSurroundsTheDrawing() {
        let art = PixelArt(rows: ["W"], scale: 1, overrides: ["W": 0xFFFFFF])
        #expect(art.width == 3)
        #expect(art.height == 3)
        let pixels = art.pixels()
        #expect(pixels[1][1] == 0xFFFFFF)
        // Los 8 vecinos llevan el color de contorno de Kenney.
        for y in 0..<3 {
            for x in 0..<3 where !(x == 1 && y == 1) {
                #expect(pixels[y][x] == PixelArt.outlineColor)
            }
        }
    }

    @Test func outlineCanBeTurnedOff() {
        let art = PixelArt(rows: ["WW"], scale: 2, outlined: false)
        #expect(art.width == 2)
        #expect(art.size == CGSize(width: 4, height: 2))
        #expect(art.pixels().flatMap { $0 }.allSatisfy { $0 == 0xFFFFFF })
    }

    @Test func holesInsideAreOutlinedToo() {
        // Un anillo: el hueco central queda rodeado de píxeles y se rellena de contorno.
        let art = PixelArt(rows: ["WWW", "W.W", "WWW"], scale: 1)
        #expect(art.pixels()[2][2] == PixelArt.outlineColor)
    }

    @Test func cuicoArtUsesTheIconColours() {
        let colours = Set(CuicoNode.bodyArt.pixels().flatMap { $0 }.compactMap { $0 })
        #expect(colours.contains(0xE31E21)) // parka roja
        #expect(colours.contains(0x3A8CF2)) // antiparras
        #expect(colours.contains(PixelArt.outlineColor))
    }
}

@MainActor
struct BundledAssetTests {
    @Test func everyKenneyTileIsInTheAtlas() {
        for sprite in KenneySprite.allCases {
            let image = NSImage(named: sprite.rawValue)
            #expect(image != nil, "Falta \(sprite.rawValue)")
            #expect(image?.size == CGSize(width: 16, height: 16))
        }
    }

    @Test func kenneySpritesUseTheSharedPixelScale() {
        let node = SpriteFactory.shared.sprite(.flagRed)
        #expect(node.size.width == 16 * GameConfig.pixelScale)
        #expect(node.texture?.filteringMode == .nearest)
    }

    @Test func skierOutfitsVary() {
        let a = SpriteFactory.shared.sprite(for: .skier, variant: 0).texture
        let b = SpriteFactory.shared.sprite(for: .skier, variant: 1).texture
        #expect(a !== b)
    }

    @Test func pixelFontIsRegistered() {
        PixelFont.register()
        #expect(NSFont(name: PixelFont.name, size: 16) != nil)
    }

    @Test func snowEffectsUsePixelFlakes() {
        let spray = SnowEffects.spray()
        #expect(spray.particleBirthRate == 0)
        #expect(spray.particleTexture?.filteringMode == .nearest)
        #expect(SnowEffects.burst(count: 10).numParticlesToEmit == 10)
    }
}

struct SnowmanTests {
    @Test func snowmenAppearInTheLowerMountain() {
        let generator = MountainGenerator(seed: 77)
        let kinds = (50..<80).flatMap { y in
            (-2...2).flatMap { generator.obstacles(in: ChunkCoord(x: $0, y: y)) }
        }.map(\.kind)
        #expect(kinds.contains(.snowman))
        #expect(CollisionResolver.effect(of: .snowman, airborne: false) == .crash)
        #expect(CollisionResolver.effect(of: .snowman, airborne: true) == nil)
    }
}
