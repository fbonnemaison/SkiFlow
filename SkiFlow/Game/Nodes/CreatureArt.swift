/// Dibujos provisionales del Kunk y el Chupacabras (miran a la derecha).
/// Diseño propio: el Kunk es una mole peluda pardo-gris de ojos rojos; el
/// Chupacabras, un bicho reptiliano gris verdoso con púas en el lomo.
enum CreatureArt {
    // MARK: Kunk

    private static let kunkPalette: [Character: UInt32] = [
        "K": 0x2B211A, // contorno
        "F": 0x6E5A48, // pelaje
        "f": 0x9C8670, // pelaje claro
        "E": 0xE0281E, // ojos
        "W": 0xF2EEE6, // dientes y garras
        "M": 0x3A1010, // boca
    ]

    private static let kunkTop = [
        "......KKKKKK......",
        "....KFFFFFFFFK....",
        "...KFFfFFFFfFFK...",
        "...KFFEEFFEEFFK...",
        "...KFFFFFFFFFFK...",
        "....KFFWMMWFFK....",
        "..KKFFFFFFFFFFKK..",
        ".KFFFFfFFFFfFFFFK.",
        "KFFfFFFFFFFFFFfFFK",
        "KFF.KFFFFFFFFK.FFK",
        "KFF.KFFfFFfFFK.FFK",
        ".WW.KFFFFFFFFK.WW.",
        "....KFFFFFFFFK....",
        "....KFFFKKFFFK....",
    ]

    static let kunkRun1 = PixelArt(rows: kunkTop + [
        "....KFFK..KFFK....",
        "...KFFK....KFFK...",
        "..KWWK......KWWK..",
    ], scale: 3.5, overrides: kunkPalette)

    static let kunkRun2 = PixelArt(rows: kunkTop + [
        ".....KFFKKFFK.....",
        ".....KFFKKFFK.....",
        ".....KWWKKWWK.....",
    ], scale: 3.5, overrides: kunkPalette)

    /// Brazos arriba y boca muy abierta: ¡ñam!
    static let kunkEat = PixelArt(rows: [
        "WW....KKKKKK....WW",
        "KFK.KFFFFFFFFK.KFK",
        "KFFKFFfFFFFfFFKFFK",
        ".KFFFFEEFFEEFFFFK.",
        "..KFFFFFFFFFFFFK..",
        "...KFWMMMMMMWFK...",
        "...KFMMMMMMMMFK...",
        "...KFFWMMMMWFFK...",
        "...KFFFFFFFFFFK...",
        "....KFFFFFFFFK....",
        "....KFFfFFfFFK....",
        "....KFFFFFFFFK....",
        "....KFFFKKFFFK....",
        "....KFFK..KFFK....",
        "....KFFK..KFFK....",
        "...KWWK....KWWK...",
    ], scale: 3.5, overrides: kunkPalette)

    // MARK: Chupacabras

    private static let chupaPalette: [Character: UInt32] = [
        "S": 0x2F4F3A, // púas
        "c": 0x6B8F71, // piel
        "d": 0x4B6B51, // sombra
        "E": 0xE01010, // ojo
        "W": 0xF2EEE6, // colmillo
    ]

    private static let chupaBody = [
        "....S.S.S.S.......",
        "...SSSSSSSSS..cc..",
        "..ccccccccccccccc.",
        ".cccdcccccdccccEcc",
        "cc.ccccccccccccccW",
        "c...ddddddddd.....",
    ]

    static let chupaRun1 = PixelArt(rows: chupaBody + [
        "...c.c.....c.c....",
        "..c...c...c...c...",
    ], scale: 3, overrides: chupaPalette)

    static let chupaRun2 = PixelArt(rows: chupaBody + [
        "....cc......cc....",
        "....cc......cc....",
    ], scale: 3, overrides: chupaPalette)
}
