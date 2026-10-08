import SwiftUI

/// Um tema de cores da Lume. Cada cor tem versão clara e escura. A logo
/// dourada fica igual em todos: muda o que está à volta dela.
nonisolated struct Paleta: Identifiable, Equatable, Sendable {
    let id: String
    let nome: String
    let descricao: String

    let fundo: Color
    let superficie: Color
    let bege: Color
    let areia: Color
    let douradoBotao: Color
    let textoNoBotao: Color
    let tinta: Color
    let tintaSuave: Color
    let tintaFosca: Color
    let dourado: Color
    let douradoEscuro: Color
    let positivo: Color
    let separador: Color

    /// Nos temas com um tom escuro de destaque, o cartão principal do
    /// Resumo desenha-se com as cores escuras da paleta: por exemplo, azul-
    /// -noite com números claros e detalhes dourados.
    let cartaoPrincipalEscuro: Bool

    /// A família do tema, para os arrumar no ecrã de escolha.
    enum Grupo: String, CaseIterable, Sendable {
        case claros = "Claros"
        case clarinhos = "Clarinhos"
        case destaque = "Com destaque escuro"
        case escuros = "Escuros"

        var descricao: String {
            switch self {
            case .claros: "Brancos e neutros, com o dourado nos acentos."
            case .clarinhos: "Tons pastel, suaves e luminosos."
            case .destaque: "Fundo claro com o cartão do mês num tom profundo."
            case .escuros: "Sempre escuros, também com o iPhone em modo claro."
            }
        }
    }

    let grupo: Grupo

    /// Se o acento de texto é dourado (e ganha o brilho metálico da logo).
    let acentoDourado: Bool

    /// Os temas escuros ignoram o modo claro: são escuros por natureza.
    var sempreEscura: Bool { grupo == .escuros }

    /// Uma cor clara/escura em hexadecimal.
    struct Par {
        let claro: UInt32
        let escuro: UInt32
        init(_ claro: UInt32, _ escuro: UInt32) {
            self.claro = claro
            self.escuro = escuro
        }
        var cor: Color { Color(claro: claro, escuro: escuro) }
    }

    init(
        id: String, nome: String, descricao: String,
        fundo: Par, superficie: Par, bege: Par, areia: Par,
        douradoBotao: Par, textoNoBotao: Par,
        tinta: Par, tintaSuave: Par, tintaFosca: Par,
        dourado: Par = Par(0xC9A45A, 0xC9A45A), douradoEscuro: Par,
        positivo: Par, separador: Par,
        cartaoPrincipalEscuro: Bool = false,
        grupo: Grupo? = nil,
        acentoDourado: Bool = true
    ) {
        self.grupo = grupo ?? (cartaoPrincipalEscuro ? .destaque : .claros)
        self.acentoDourado = acentoDourado
        self.id = id
        self.nome = nome
        self.descricao = descricao
        self.fundo = fundo.cor
        self.superficie = superficie.cor
        self.bege = bege.cor
        self.areia = areia.cor
        self.douradoBotao = douradoBotao.cor
        self.textoNoBotao = textoNoBotao.cor
        self.tinta = tinta.cor
        self.tintaSuave = tintaSuave.cor
        self.tintaFosca = tintaFosca.cor
        self.dourado = dourado.cor
        self.douradoEscuro = douradoEscuro.cor
        self.positivo = positivo.cor
        self.separador = separador.cor
        self.cartaoPrincipalEscuro = cartaoPrincipalEscuro
    }

    static func == (a: Paleta, b: Paleta) -> Bool { a.id == b.id }

    // MARK: - Guardar a escolha

    static let chave = "paletaDaLume"

    /// O tema de origem: "Ouro no branco".
    static var padrao: Paleta { ouroBranco }

    static func guardada() -> Paleta {
        let id = UserDefaults.standard.string(forKey: chave)
        return todas.first { $0.id == id } ?? padrao
    }

    static func com(id: String) -> Paleta {
        todas.first { $0.id == id } ?? padrao
    }

    // MARK: - Construtores

    /// Um tema pastel: fundo quase branco tingido, painéis e botões num
    /// tom clarinho da mesma cor, texto escuro. No modo escuro fica num
    /// cinzento profundo com o mesmo acento.
    private static func pastel(
        id: String, nome: String, descricao: String,
        fundo: UInt32, painel: UInt32, neutro: UInt32, linha: UInt32,
        botao: UInt32, acento: UInt32, acentoEscuro: UInt32,
        tinta: UInt32, suave: UInt32
    ) -> Paleta {
        Paleta(
            id: id, nome: nome, descricao: descricao,
            fundo: Par(fundo, 0x111214), superficie: Par(0xFFFFFF, 0x1B1B1F),
            bege: Par(neutro, 0x2A2A2F), areia: Par(painel, 0x25252A),
            douradoBotao: Par(botao, acentoEscuro), textoNoBotao: Par(tinta, 0x141416),
            tinta: Par(tinta, 0xF2F1F4), tintaSuave: Par(suave, 0xA6A4AC), tintaFosca: Par(tinta, 0xE6E5EA),
            douradoEscuro: Par(acento, acentoEscuro),
            positivo: Par(0x3F7A55, 0x8FD0A5), separador: Par(linha, 0x323238),
            grupo: .clarinhos,
            acentoDourado: false
        )
    }

    /// Um tema sempre escuro: as mesmas cores nos dois modos.
    private static func escura(
        id: String, nome: String, descricao: String,
        fundo: UInt32, superficie: UInt32, neutro: UInt32, painel: UInt32, linha: UInt32,
        botao: UInt32, acento: UInt32, tinta: UInt32, suave: UInt32
    ) -> Paleta {
        Paleta(
            id: id, nome: nome, descricao: descricao,
            fundo: Par(fundo, fundo), superficie: Par(superficie, superficie),
            bege: Par(neutro, neutro), areia: Par(painel, painel),
            douradoBotao: Par(botao, botao), textoNoBotao: Par(superficie, superficie),
            tinta: Par(tinta, tinta), tintaSuave: Par(suave, suave), tintaFosca: Par(tinta, tinta),
            douradoEscuro: Par(acento, acento),
            positivo: Par(0x8FD0A5, 0x8FD0A5), separador: Par(linha, linha),
            grupo: .escuros
        )
    }

    // MARK: - Os temas
    //
    // No modo escuro nunca há preto puro: fundos em preto fosco (#1C1C1E e
    // vizinhos) e cartões um degrau acima, em cinzento escuro.

    /// Branco com dourado só nos acentos: limpo e sóbrio. O tema de origem.
    static let ouroBranco = Paleta(
        id: "ouro-branco", nome: "Ouro no branco", descricao: "Branco e cinzentos neutros; o dourado só onde importa.",
        fundo: Par(0xFFFFFF, 0x1C1C1E), superficie: Par(0xFFFFFF, 0x2A2A2D),
        // bege = cinza-pedra das áreas de apoio; areia = seleção (chips,
        // separador ativo), no mesmo neutro quente, sem o bege-pêssego que
        // lutava com os cartões oliva.
        bege: Par(0xF1F1EF, 0x36363A), areia: Par(0xECEAE3, 0x3A3934),
        douradoBotao: Par(0xE3C47E, 0xD8B86F), textoNoBotao: Par(0x1C1C1E, 0x1C1C1E),
        tinta: Par(0x1C1C1E, 0xF4F4F2), tintaSuave: Par(0x76767A, 0xA6A6AB), tintaFosca: Par(0x2C2C2E, 0xE6E6E8),
        douradoEscuro: Par(0x8E641F, 0xE0BF74),
        positivo: Par(0x3F7A55, 0x8FD0A5), separador: Par(0xE8E8E6, 0x3C3C40)
    )

    /// O tema original do Figma: creme, areia e dourado.
    static let marfim = Paleta(
        id: "marfim", nome: "Marfim", descricao: "O original: creme, areia e dourado.",
        fundo: Par(0xFFFFFF, 0x1E1D1B), superficie: Par(0xFFFFFF, 0x2B2A27),
        bege: Par(0xF0EBE1, 0x383632), areia: Par(0xF7EEDB, 0x33302B),
        douradoBotao: Par(0xE8CD91, 0xD2B06A), textoNoBotao: Par(0x302B24, 0x1E1D1B),
        tinta: Par(0x302B24, 0xF2F0EB), tintaSuave: Par(0x7B7367, 0xAEA89E), tintaFosca: Par(0x38342E, 0xE8E4DC),
        douradoEscuro: Par(0x8E641F, 0xDDB96C),
        positivo: Par(0x456B56, 0x8FD0A5), separador: Par(0xE7E0D5, 0x3E3B36)
    )

    static let todas: [Paleta] = [
        // MARK: Claros
        ouroBranco,
        marfim,
        Paleta(
            id: "salva", nome: "Salva", descricao: "Verde acinzentado; fresco e tranquilo.",
            fundo: Par(0xF4F6F2, 0x1C201D), superficie: Par(0xFFFFFF, 0x282D29),
            bege: Par(0xE6EBE2, 0x343B36), areia: Par(0xE9EFE5, 0x2F3531),
            douradoBotao: Par(0xE5C986, 0xD2B06A), textoNoBotao: Par(0x26302A, 0x1C201D),
            tinta: Par(0x26302A, 0xEEF2EC), tintaSuave: Par(0x6B756D, 0xA7B2A9), tintaFosca: Par(0x2F3932, 0xE0E6E1),
            douradoEscuro: Par(0x7F6A2A, 0xDCC07A),
            positivo: Par(0x3F6B4E, 0x93CFA4), separador: Par(0xDDE3D8, 0x3A423C)
        ),
        Paleta(
            id: "terracota", nome: "Terracota", descricao: "Acentos cor de barro; mediterrânico.",
            fundo: Par(0xFBF8F5, 0x201B18), superficie: Par(0xFFFFFF, 0x2D2622),
            bege: Par(0xF1E6DD, 0x3A312B), areia: Par(0xF6E7DC, 0x352C26),
            douradoBotao: Par(0xE9B99A, 0xD39A78), textoNoBotao: Par(0x2F2320, 0x201B18),
            tinta: Par(0x2F2320, 0xF6EFEA), tintaSuave: Par(0x7D6C64, 0xB9A79D), tintaFosca: Par(0x3A2C27, 0xEDE3DD),
            douradoEscuro: Par(0xA4532F, 0xE59C78),
            positivo: Par(0x4F6B4A, 0x9CCB96), separador: Par(0xEBDFD6, 0x423731),
            acentoDourado: false
        ),
        Paleta(
            id: "nevoa", nome: "Névoa", descricao: "Azul frio e claro; o dourado ganha contraste.",
            fundo: Par(0xF4F6F9, 0x1C1F25), superficie: Par(0xFFFFFF, 0x282C34),
            bege: Par(0xE7ECF2, 0x343A44), areia: Par(0xE9EEF5, 0x2F343D),
            douradoBotao: Par(0xE3C47E, 0xD7B46C), textoNoBotao: Par(0x1E2633, 0x1C1F25),
            tinta: Par(0x1E2633, 0xEEF1F6), tintaSuave: Par(0x687385, 0xA6B0C0), tintaFosca: Par(0x283141, 0xE1E6EE),
            douradoEscuro: Par(0x8A651F, 0xE0BF74),
            positivo: Par(0x3C7457, 0x8FCEA7), separador: Par(0xDCE3EC, 0x3A404B)
        ),

        // MARK: Clarinhos (pastel)
        pastel(
            id: "rosa-po", nome: "Rosa-pó", descricao: "Rosa muito suave, delicado.",
            fundo: 0xFDF8F8, painel: 0xF9E9EC, neutro: 0xF4E6E9, linha: 0xF0E0E3,
            botao: 0xF2C9D1, acento: 0xA2566A, acentoEscuro: 0xE7A3B3,
            tinta: 0x3A2A2E, suave: 0x8A767B
        ),
        pastel(
            id: "lavanda", nome: "Lavanda", descricao: "Lilás clarinho, calmo e sonhador.",
            fundo: 0xF9F8FD, painel: 0xEDEAF9, neutro: 0xE8E4F5, linha: 0xE4E0F1,
            botao: 0xD3CAF3, acento: 0x6A5AAE, acentoEscuro: 0xB7A9EE,
            tinta: 0x2C2840, suave: 0x7A7690
        ),
        pastel(
            id: "menta", nome: "Menta", descricao: "Verde-água leve e fresco.",
            fundo: 0xF6FBF8, painel: 0xE3F4EB, neutro: 0xDFF0E6, linha: 0xD8EBE0,
            botao: 0xC3E7D3, acento: 0x2F7A58, acentoEscuro: 0x8FD6B2,
            tinta: 0x1F332A, suave: 0x6B8277
        ),
        pastel(
            id: "ceu", nome: "Céu", descricao: "Azul-bebé, limpo e luminoso.",
            fundo: 0xF6FAFD, painel: 0xE3F0FA, neutro: 0xDEEBF6, linha: 0xD7E5F1,
            botao: 0xC3DEF5, acento: 0x2E6FA3, acentoEscuro: 0x94C4EC,
            tinta: 0x1D2E3D, suave: 0x687C8E
        ),
        pastel(
            id: "pessego", nome: "Pêssego", descricao: "Pêssego quente e macio.",
            fundo: 0xFFF9F5, painel: 0xFCEADF, neutro: 0xF7E4D8, linha: 0xF2DDD0,
            botao: 0xF6CFB6, acento: 0xB0643A, acentoEscuro: 0xF0AE87,
            tinta: 0x3A2A22, suave: 0x8C766A
        ),
        pastel(
            id: "baunilha", nome: "Baunilha", descricao: "Amarelo-manteiga, o mais próximo do dourado.",
            fundo: 0xFFFDF4, painel: 0xFBF3D4, neutro: 0xF5EED2, linha: 0xEEE7C8,
            botao: 0xF2E094, acento: 0x8A7419, acentoEscuro: 0xE6CF70,
            tinta: 0x33301F, suave: 0x858068
        ),

        // MARK: Com destaque escuro
        Paleta(
            id: "noite", nome: "Noite", descricao: "Cartão do mês azul-noite com dourado.",
            fundo: Par(0xF7F7F5, 0x1A202A), superficie: Par(0xFFFFFF, 0x243042),
            bege: Par(0xEEEEEA, 0x2F3B4E), areia: Par(0xF1F0EC, 0x2A3649),
            douradoBotao: Par(0xE3C47E, 0xE3C47E), textoNoBotao: Par(0x1F2A3A, 0x1F2A3A),
            tinta: Par(0x1F2A3A, 0xF3F1EC), tintaSuave: Par(0x6E7582, 0xADB5C2), tintaFosca: Par(0x2A3444, 0xE4E7EC),
            douradoEscuro: Par(0x8E641F, 0xE3C47E),
            positivo: Par(0x3F7A55, 0x8FD0A5), separador: Par(0xE4E4E0, 0x384558),
            cartaoPrincipalEscuro: true
        ),
        Paleta(
            id: "esmeralda", nome: "Esmeralda", descricao: "Verde-garrafa no destaque, como uma nota antiga.",
            fundo: Par(0xF6F7F4, 0x18211E), superficie: Par(0xFFFFFF, 0x21392F),
            bege: Par(0xE9EEE8, 0x2D4640), areia: Par(0xEEF2EC, 0x28413A),
            douradoBotao: Par(0xE3C47E, 0xE3C47E), textoNoBotao: Par(0x1D2B25, 0x1D2B25),
            tinta: Par(0x1D2B25, 0xF1F3EE), tintaSuave: Par(0x67736C, 0xABBAB2), tintaFosca: Par(0x26352F, 0xE2E8E4),
            douradoEscuro: Par(0x8A6A1E, 0xE3C47E),
            positivo: Par(0x2F6B4A, 0x8FD0A5), separador: Par(0xE0E5DE, 0x375249),
            cartaoPrincipalEscuro: true
        ),
        Paleta(
            id: "carvao", nome: "Carvão", descricao: "Grafite no destaque; moderno e minimalista.",
            fundo: Par(0xF5F5F4, 0x1C1C1E), superficie: Par(0xFFFFFF, 0x2C2D31),
            bege: Par(0xECECEA, 0x38393E), areia: Par(0xEFEFED, 0x333439),
            douradoBotao: Par(0xE3C47E, 0xE3C47E), textoNoBotao: Par(0x1C1C1E, 0x1C1C1E),
            tinta: Par(0x1C1C1E, 0xF4F4F2), tintaSuave: Par(0x707074, 0xA9A9AE), tintaFosca: Par(0x2A2A2D, 0xE6E6E8),
            douradoEscuro: Par(0x80601F, 0xE3C47E),
            positivo: Par(0x3F7A55, 0x8FD0A5), separador: Par(0xE3E3E1, 0x3F4045),
            cartaoPrincipalEscuro: true
        ),
        Paleta(
            id: "bordo", nome: "Bordô", descricao: "Vinho no destaque; quente e elegante.",
            fundo: Par(0xFAF7F6, 0x211A1C), superficie: Par(0xFFFFFF, 0x4A2230),
            bege: Par(0xF1E8E8, 0x582C3B), areia: Par(0xF6EDED, 0x522836),
            douradoBotao: Par(0xE6C585, 0xE6C585), textoNoBotao: Par(0x2E1F23, 0x2E1F23),
            tinta: Par(0x2E1F23, 0xF6EFEF), tintaSuave: Par(0x7A6A6E, 0xC6AEB5), tintaFosca: Par(0x3A2A2E, 0xEEE3E5),
            douradoEscuro: Par(0x8E5A1F, 0xE6C585),
            positivo: Par(0x456B56, 0x9AD2AC), separador: Par(0xEADFDF, 0x613647),
            cartaoPrincipalEscuro: true
        ),

        // MARK: Escuros (sempre escuros, sem preto puro)
        escura(
            id: "obsidiana", nome: "Grafite", descricao: "Cinzento-grafite fosco com dourado.",
            fundo: 0x1C1C1F, superficie: 0x28292D, neutro: 0x35363B, painel: 0x303136, linha: 0x3B3C42,
            botao: 0xD8B46A, acento: 0xE0BD72, tinta: 0xF2F0EB, suave: 0xA7A7AF
        ),
        escura(
            id: "meia-noite", nome: "Meia-noite", descricao: "Azul muito escuro, profundo e sereno.",
            fundo: 0x161D2A, superficie: 0x1F2838, neutro: 0x2A3548, painel: 0x253043, linha: 0x303C51,
            botao: 0xE3C47E, acento: 0xE3C47E, tinta: 0xEEF2F8, suave: 0x9EAABE
        ),
        escura(
            id: "floresta", nome: "Floresta", descricao: "Verde escuro, natural e rico.",
            fundo: 0x152019, superficie: 0x1D2B23, neutro: 0x28392F, painel: 0x23342A, linha: 0x2D4035,
            botao: 0xE3C47E, acento: 0xE3C47E, tinta: 0xEEF4F0, suave: 0xA0B5AA
        ),
        escura(
            id: "vinho", nome: "Vinho", descricao: "Tinto escuro, aveludado.",
            fundo: 0x1F1519, superficie: 0x2B1D23, neutro: 0x3A2830, painel: 0x33232A, linha: 0x432E37,
            botao: 0xE6C585, acento: 0xE6C585, tinta: 0xF6EEF0, suave: 0xBEA6AD
        ),
        escura(
            id: "cafe", nome: "Café", descricao: "Castanho-café, quente e acolhedor.",
            fundo: 0x1E1914, superficie: 0x2A231C, neutro: 0x382F26, painel: 0x322920, linha: 0x40362C,
            botao: 0xE3C47E, acento: 0xE3C47E, tinta: 0xF4EDE4, suave: 0xB5A796
        ),
    ]
}

/// Claro, escuro ou seguir o iPhone. Escolhido em Perfil → Tema.
nonisolated enum ModoDeAparencia: String, CaseIterable, Identifiable, Sendable {
    case automatico, claro, escuro

    static let chave = "modoDeAparencia"

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .automatico: "Automático"
        case .claro: "Claro"
        case .escuro: "Escuro"
        }
    }

    var simbolo: String {
        switch self {
        case .automatico: "circle.lefthalf.filled"
        case .claro: "sun.max"
        case .escuro: "moon"
        }
    }

    /// `nil` segue o modo do iPhone.
    var esquema: ColorScheme? {
        switch self {
        case .automatico: nil
        case .claro: .light
        case .escuro: .dark
        }
    }
}
