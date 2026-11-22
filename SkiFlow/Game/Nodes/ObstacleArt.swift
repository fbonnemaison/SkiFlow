/// Dibujos provisionales de los objetos andinos. Los animales y personajes
/// miran a la derecha; el sprite se voltea cuando van a la izquierda.
enum ObstacleArt {
    static func art(for kind: ObstacleKind) -> PixelArt {
        switch kind {
        case .araucaria: araucaria
        case .quenua: quenua
        case .smallRock: smallRock
        case .cactus: cactus
        case .apacheta: apacheta
        case .penitente: penitente
        case .refugio: refugio
        case .liftPylon: liftPylon
        case .ramp: ramp
        case .llama: llama
        case .guanaco: PixelArt(rows: llama.rows, overrides: ["T": 0xC68B59, "t": 0xF2EBDD])
        case .vicuna: PixelArt(rows: llama.rows, scale: 2.5, overrides: ["T": 0xE0B07A, "t": 0xFFFFFF])
        case .dog: dog
        case .fox: fox
        case .puma: puma
        case .argentine: RivalArt.argentine
        case .brazilian: RivalArt.brazilian
        case .gringo: RivalArt.gringo
        case .condor: condor
        // Estos usan tiles de Kenney (ver `SpriteFactory.sprite(for:variant:)`).
        case .rock, .snowman, .iceZone, .deepSnowZone, .windZone: PixelArt(rows: [])
        }
    }

    /// Araucaria: tronco recto y ramas en pisos con la copa en forma de paraguas.
    static let araucaria = PixelArt(rows: [
        ".......GGGGGGG.......",
        ".....GGgGGGGGgGG.....",
        "...GGGGGGGgGGGGGGG...",
        ".GGgGGGGGGGGGGGGGgGG.",
        "GGGGGGGGGBBBGGGGGGGGG",
        "..GGGg...BBB...gGGG..",
        ".........BBB.........",
        "...GGGGGGBBBGGGGGG...",
        "..GGgGGGGBBBGGGGgGG..",
        ".........BBB.........",
        ".........BBB.........",
        "....GGGGGBBBGGGGG....",
        "...GGgGGGBBBGGGgGG...",
        ".........BBB.........",
        ".........BBB.........",
        ".........BBB.........",
        ".........BBB.........",
        ".........BBB.........",
        ".........BBB.........",
        "........DBBBD........",
    ])

    /// Queñua: copa densa y tronco retorcido de corteza rojiza.
    static let quenua = PixelArt(rows: [
        ".....gggGGGg......",
        "...gGGGgggGGGg....",
        "..gGGgGGGGgGGGGg..",
        ".gGGGGgGGGGGgGGGg.",
        "gGGgGGGGgGGGGGgGGg",
        ".GGGGgDGGgGGOGGGg.",
        "..gGG.DD.GGOO.Gg..",
        "......DDO.OD......",
        ".......DOOD.......",
        "........DOD.......",
        ".......ODDO.......",
        "......DDOOD.......",
        ".....DD...DD......",
    ])


    static let smallRock = PixelArt(rows: [
        "..rrR...",
        ".rWrRR..",
        "rrrRRRR.",
    ])

    static let cactus = PixelArt(rows: [
        ".....CC.....",
        "....CCCC....",
        "....CcCC....",
        ".CC.CCCC....",
        ".CC.CcCC.CC.",
        ".CCCCCCC.CC.",
        "....CCCCCCC.",
        "....CcCC....",
        "....CCCC....",
        "....CCCC....",
        "....CcCC....",
        "...DCCCCD...",
    ])

    static let apacheta = PixelArt(rows: [
        ".....rR.....",
        "....rrRR....",
        "...RrrRrR...",
        "..rrRRrrRR..",
        ".RrrRrRRrrR.",
        "rrRRrrRrRRrr",
    ])

    static let penitente = PixelArt(rows: [
        "..W.....W...",
        "..WI...WI...",
        ".WII..WII..W",
        ".WIi..WIi.WI",
        "WIIi.WIIiWII",
        "WIIiiWIIiWIi",
        "WIIiiWIIiIIi",
        "SSSSSSSSSSSS",
    ])

    static let refugio = PixelArt(rows: [
        "..........WWWWWWWWWWWWWWWWWWWW..........",
        "........WWWWWWWWWWWWWWWWWWWWWWWW........",
        "......WWEEEEEEEEEEEEEEEEEEEEEEEEWW......",
        "....WWEEEEEEEEEEEEEEEEEEEEEEEEEEEEWW....",
        "..WWEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEWW..",
        "WWEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEWW",
        "....DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD....",
        "....DttDDDDDDDDDDDDDDDDDDDDDDDDDDttD....",
        "....DtYYYYtDDDDDKKKKKKDDDDDtYYYYtD......",
        "....DtYNNYtDDDDDKKKKKKDDDDDtYNNYtD......",
        "....DtYYYYtDDDDDKKKKKKDDDDDtYYYYtD......",
        "....DttttttDDDDDKKKKYKDDDDDttttttD......",
        "....DDDDDDDDDDDDKKKKKKDDDDDDDDDDDD......",
        "....DDDDDDDDDDDDKKKKKKDDDDDDDDDDDD......",
        "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
    ])

    static let liftPylon = PixelArt(rows: [
        "KKKKKKKK",
        "...RR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "...rR...",
        "..rrRR..",
        ".RRRRRR.",
    ])

    /// Rampa de nieve con postes naranjas a los lados para verla de lejos.
    static let ramp = PixelArt(rows: [
        "Y....................Y",
        "O.....WWWWWWWWWW.....O",
        "O...WWSSSSSSSSSSWW...O",
        "O.WWSSSSSSSSSSSSSSWW.O",
        "OiiiiiiiiiiiiiiiiiiiiO",
        ".RRRRRRRRRRRRRRRRRRRR.",
    ])

    static let llama = PixelArt(rows: [
        "........TT..",
        "........TTK.",
        "........TT..",
        "........TT..",
        ".TTTTTTTTT..",
        "TTTTTTTTTT..",
        "TtttttttTT..",
        ".T.T..T.T...",
        ".T.T..T.T...",
        ".D.D..D.D...",
    ])

    static let dog = PixelArt(rows: [
        "........DD.",
        ".......DDDK",
        "D.DDDDDDDD.",
        ".DDDDDDDD..",
        ".DWDDDDWD..",
        ".D.D..D.D..",
    ])


    /// Zorro culpeo: pelaje rojizo, hocico blanco y cola espesa de punta oscura.
    static let fox = PixelArt(rows: [
        "...........O.O",
        "..........OOOO",
        "DO........OOKO",
        "DOO.OOOOOOOOOW",
        ".OOOOOOOOOOOWW",
        "..OOOOOOOOO...",
        "..O.O...O.O...",
        "..K.K...K.K...",
    ], overrides: ["O": 0xC4622D])

    /// Puma: pardo claro, cuerpo largo y cola larga.
    static let puma = PixelArt(rows: [
        "..............tt..",
        ".............tttt.",
        "t...........ttKtt.",
        "tt.tttttttttttttW.",
        ".ttttttttttttttt..",
        "..ttttttttttttt...",
        "...tt.tt..tt.tt...",
        "...tt.tt..tt.tt...",
        "...DD.DD..DD.DD...",
    ], overrides: ["t": 0xC9A36B])

    static let condor = PixelArt(rows: [
        "KK..................KK",
        ".KKK..............KKK.",
        "..KKKKK...WW...KKKKK..",
        "....KKKKKKKKKKKKKK....",
        ".......KKKKKKKK.......",
        ".........KKKK.........",
        "..........KK..........",
    ])

}
