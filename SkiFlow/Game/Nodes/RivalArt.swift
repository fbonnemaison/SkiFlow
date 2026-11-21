/// Los dos esquiadores rivales, vistos de frente como el Cuico.
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
}
