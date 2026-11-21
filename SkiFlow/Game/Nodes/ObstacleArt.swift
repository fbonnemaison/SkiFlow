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
        case .condor: condor
        // Estos usan tiles de Kenney (ver `SpriteFactory.sprite(for:variant:)`).
        case .rock, .skier, .snowman, .iceZone, .deepSnowZone, .windZone: PixelArt(rows: [])
        }
    }

    static let araucaria = PixelArt(rows: [
        "......GGGG......",
        "....GGGGGGGG....",
        "..GGGgGGGGgGGG..",
        ".GGgGGGGGGGGgGG.",
        "GGGGGGGBBGGGGGGG",
        ".....GGBBGG.....",
        "...GGGGBBGGGG...",
        "..GGgGGBBGGgGG..",
        ".......BB.......",
        ".......BB.......",
        "....GGGBBGGG....",
        "...GGgGBBGgGG...",
        ".......BB.......",
        ".......BB.......",
        ".......BB.......",
        ".......BB.......",
        "......DBBD......",
    ], scale: 4)

    static let quenua = PixelArt(rows: [
        "....gggGG.....",
        "..gGGgggGGg...",
        ".gGGGgGGGgGG..",
        "gGGgGGGgGGGGg.",
        ".GGGgDGGgGGg..",
        "..gG.DD.GDg...",
        ".....DDODD....",
        "......DDO.....",
        "......ODD.....",
        ".....DDOD.....",
        "....DD..DD....",
    ], scale: 4)


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
