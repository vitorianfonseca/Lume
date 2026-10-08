import SwiftUI
import UIKit

/// Paleta e geometria da Lume. As cores vêm da `Paleta` escolhida no
/// Perfil → Tema; a original é a "Marfim" do Figma.
nonisolated enum Tema {
    /// A paleta em uso. Lida uma vez no arranque; muda pelo ecrã de temas,
    /// que a seguir reconstrói a interface (ver `LumeApp`).
    nonisolated(unsafe) static var paleta = Paleta.guardada()

    static var fundo: Color { paleta.fundo }
    static var superficie: Color { paleta.superficie }
    /// Bege dos avatares e chips neutros — "warm" no quadro de identidade.
    static var bege: Color { paleta.bege }
    /// Areia dos painéis grandes (voz e talão) e dos chips selecionados.
    static var areia: Color { paleta.areia }
    /// Fundo dos botões principais.
    static var douradoBotao: Color { paleta.douradoBotao }
    /// Texto por cima dos botões principais.
    static var textoNoBotao: Color { paleta.textoNoBotao }
    static var tinta: Color { paleta.tinta }
    /// "muted" no quadro de identidade.
    static var tintaSuave: Color { paleta.tintaSuave }
    /// Preto fosco para ícones e setas — nunca preto puro.
    static var tintaFosca: Color { paleta.tintaFosca }
    static var dourado: Color { paleta.dourado }
    /// O acento para texto: títulos pequenos, ligações e chips selecionados.
    static var douradoEscuro: Color { paleta.douradoEscuro }
    /// Verde discreto para receitas e confirmações — "positive" na identidade.
    static var positivo: Color { paleta.positivo }
    /// Linhas e contornos.
    static var separador: Color { paleta.separador }

    // MARK: Papéis (auditoria UX, 01/10)
    //
    // superfície = branco (`superficie`) · superfície de apoio = cinza-pedra
    // (`bege`) · superfície de destaque = um só tom (`cafe`, os cartões
    // oliva) · ação = um só dourado (`douradoBotao`) · texto de destaque =
    // castanho (`ouro`) · estados: `positivo`, `aviso`, `negativo`.

    /// Âmbar: perto do limite (75–99%).
    // Mais subtil ainda — quase um rosa empoeirado, só o suficiente para
    // se notar sem gritar.
    static let aviso = Color(claro: 0xC98F87, escuro: 0xD9A8A0)
    static let fundoDoAviso = Color(claro: 0xFBEAE7, escuro: 0x3A2422)
    /// Vermelho suave: limite ultrapassado, saldo negativo, ações destrutivas.
    static let negativo = Color(claro: 0xB4432E, escuro: 0xF0A597)
    static let fundoNegativo = Color(claro: 0xF8E6E1, escuro: 0x3A2422)
    /// Placeholders dos campos: ≥3,5:1 sobre branco (o cinzento do sistema
    /// ficava a 1,8:1, ilegível ao sol).
    static let placeholder = Color(claro: 0x86868B, escuro: 0x8E8E93)

    /// A cor de estado de um limite: neutro abaixo de 75%, âmbar até 99%,
    /// vermelho a partir de 100%.
    static func corDoLimite(_ fracao: Double) -> Color? {
        if fracao >= 1 { return negativo }
        if fracao >= 0.75 { return aviso }
        return nil
    }

    /// Margem horizontal dos ecrãs — 24 pt, medida nos frames (342 em 390).
    static let margemDoEcra: CGFloat = 24

    /// Cantos medidos nos frames: cartões 24 · botões e campos 16 · chips 13.
    enum Raio {
        static let cartao: CGFloat = 24
        static let campo: CGFloat = 16
        static let chip: CGFloat = 13
    }

    /// A fonte do sistema (SF Pro) — ela trocou a Instrument Sans por um
    /// aspeto mais nativo da Apple. Um só sítio para mudar, se voltar atrás.
    static func fonte(_ tamanho: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        .system(size: tamanho, weight: peso)
    }

    /// A cor do texto de destaque (títulos pequenos, ligações, separador
    /// ativo). Nos temas cujo acento não é dourado (pastel, Terracota), é a
    /// cor do tema.
    static var ouro: AnyShapeStyle {
        guard paleta.acentoDourado else { return AnyShapeStyle(paleta.douradoEscuro) }
        return AnyShapeStyle(castanho)
    }

    /// O texto de destaque: castanho-bege liso, no tom do couro da
    /// carteira; no escuro, um bege claro. O dourado fica para as peças
    /// (barras, anel, moedas, "+").
    static let castanho = Color(claro: 0x8A6A4C, escuro: 0xD9C2A3)

    /// As cores dos cartões de destaque e das barras: a Areia, escolhida
    /// por ela entre 20 opções.
    static let acento = AcentoDosCartoes.areia

    /// O fundo dos cartões de destaque.
    static var cafe: Color { acento.corDoCartao }

    static let ouroDasMoedas = LinearGradient(
        stops: [
            .init(color: Color(claro: 0x8F4F0F, escuro: 0xD9A450), location: 0.00),
            .init(color: Color(claro: 0xA87132, escuro: 0xE3B466), location: 0.16),
            .init(color: Color(claro: 0xC78F44, escuro: 0xEDC27A), location: 0.31),
            .init(color: Color(claro: 0xF9CC81, escuro: 0xFFDDA0), location: 0.44),
            .init(color: Color(claro: 0xFFF1C2, escuro: 0xFFF4D2), location: 0.51),
            .init(color: Color(claro: 0xE5AE5D, escuro: 0xF2C57E), location: 0.61),
            .init(color: Color(claro: 0xA45D14, escuro: 0xD99F4E), location: 0.78),
            .init(color: Color(claro: 0xDB8215, escuro: 0xECB45C), location: 0.89),
            .init(color: Color(claro: 0xF5C873, escuro: 0xFBDB94), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A sombra bronze que dá relevo ao texto dourado.
    static let sombraDoOuro = Color(claro: 0x6F3906, escuro: 0x000000)

    /// O preenchimento das barras, na cor escolhida em Cartões e barras.
    static var douradoDaBarra: AnyShapeStyle {
        AnyShapeStyle(cafeDaBarra)
    }

    /// As barras, o anel e a linha do ritmo, na cor escolhida (Areia).
    /// Tinha ficado mais escura para mais contraste, mas ela achou-a
    /// "castanha" — voltou ao tom original, que ela já tinha escolhido.
    static var cafeDaBarra: LinearGradient { acento.gradienteDaBarra }

    static let ouroDaBarra = LinearGradient(
        stops: [
            .init(color: Color(hex: "945311"), location: 0.00),
            .init(color: Color(hex: "C78F44"), location: 0.17),
            .init(color: Color(hex: "F9CC81"), location: 0.36),
            .init(color: Color(hex: "FFF2C7"), location: 0.48),
            .init(color: Color(hex: "E5AE5D"), location: 0.61),
            .init(color: Color(hex: "A87132"), location: 0.78),
            .init(color: Color(hex: "E2A34A"), location: 1.00),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// O dourado das peças (moedas, cadeado, chip dos cartões), com as cores
    /// da logo: sombra profunda, amarelo-ouro vivo e um realce quase branco.
    static var douradoMetalico: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "8A5A12"), location: 0),
                .init(color: Color(hex: "C98F2A"), location: 0.3),
                .init(color: Color(hex: "F4CF6E"), location: 0.55),
                .init(color: Color(hex: "FFF1C2"), location: 0.68),
                .init(color: Color(hex: "E2AC45"), location: 0.82),
                .init(color: Color(hex: "9C6718"), location: 1),
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    /// Dourado polido para botões: reflexo diagonal, claro em cima.
    static var douradoPolido: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F3E3B3"), Color(hex: "C9A45A"), Color(hex: "9A7433")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

nonisolated extension Color {
    /// Cor dinâmica claro/escuro a partir de valores hexadecimais.
    init(claro: UInt32, escuro: UInt32) {
        self.init(uiColor: UIColor { tracos in
            let hex = tracos.userInterfaceStyle == .dark ? escuro : claro
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    init(hex: String) {
        var valor: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&valor)
        self.init(
            red: Double((valor >> 16) & 0xFF) / 255,
            green: Double((valor >> 8) & 0xFF) / 255,
            blue: Double(valor & 0xFF) / 255
        )
    }
}

/// A cor vive aqui e não no modelo, para os `@Model` não dependerem de SwiftUI.
extension Categoria {
    var cor: Color { Color(hex: corHex) }
}
