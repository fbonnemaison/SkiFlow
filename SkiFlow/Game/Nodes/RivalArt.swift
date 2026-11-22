/// Los rivales, vistos de frente como el Cuico.
enum RivalArt {
    /// El Argentino: gorro y chaqueta albiceleste con el sol de mayo.
    static let argentine = PixelArt(
        rows: [
            "...CCCC...",
            "..CWWWWC..",
            "..SKKKKS..",
            "..SSSSSS..",
            "...SSSS...",
            "..CWCWCW..",
            ".CWCYYWCW.",
            "CWCWYYCWCW",
            "C.CWCWCW.C",
            "K.WCWCWC.K",
            "..CWCWCW..",
            "..PPPPPP..",
            "..PP..PP..",
            "..PP..PP..",
        ],
        overrides: [
            "C": 0x74ACDF, // celeste
            "W": 0xFFFFFF,
            "Y": 0xF6B40E, // sol de mayo
            "S": 0xF1C27D, // piel
            "K": 0x1A1B20,
            "P": 0x2A2C35,
        ]
    )

    /// El Brasileño: gorro y chaqueta verde y amarilla con el círculo azul.
    static let brazilian = PixelArt(
        rows: [
            "...YYYY...",
            "..GGGGGG..",
            "..SKKKKS..",
            "..SSSSSS..",
            "...SSSS...",
            "..GGYYGG..",
            ".GGYBBYGG.",
            "GGGYBBYGGG",
            "G.GGYYGG.G",
            "K.GGGGGG.K",
            "..YYYYYY..",
            "..PPPPPP..",
            "..PP..PP..",
            "..PP..PP..",
        ],
        overrides: [
            "G": 0x009C3B, // verde
            "Y": 0xFFDF00, // amarillo
            "B": 0x002776, // azul
            "S": 0xC68642, // piel
            "K": 0x1A1B20,
            "P": 0x2A2C35,
        ]
    )

    /// El Gringo: turista perdido con gorro, parka y jeans azules, abriendo un
    /// mapa del cerro. Va a pie, con botas en vez de esquís.
    static let gringo = PixelArt(
        rows: [
            "...nBBn...",
            "..BBBBBBB.",
            "..HSSSSH..",
            "..SKSSKS..",
            "...SSSS...",
            "..BBWBBB..",
            ".BBBWBBBB.",
            "SMMMMMMMMS",
            ".MmMMmmMM.",
            "..BBBBBB..",
            "..JJJJJJ..",
            "..JJ..JJ..",
            "..JJ..JJ..",
            "..KK..KK..",
        ],
        overrides: [
            "B": 0x2F6FD6, // azul
            "n": 0x1F4FA8, // azul oscuro
            "W": 0xFFFFFF,
            "H": 0xF2D16B, // pelo rubio
            "S": 0xF5C9A8, // piel
            "K": 0x1A1B20,
            "M": 0xF3E6C0, // mapa
            "m": 0xC94A3A, // ruta marcada en el mapa
            "J": 0x2A3F7A, // jeans
        ]
    )
}
