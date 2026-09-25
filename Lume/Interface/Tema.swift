import SwiftUI
import UIKit

/// Paleta e geometria da Lume, extraídas do sistema visual (site/identidade):
/// marfim, tinta, cinzentos quentes, linhas finas e dourado só em acentos.
nonisolated enum Tema {
    // Novo design (24/09) — cores medidas pixel a pixel no PNG do Figma:
    // fundo e cartões brancos puros, tinta "espresso" quente.
    static let fundo = Color(claro: 0xFFFFFF, escuro: 0x111214)
    static let superficie = Color(claro: 0xFFFFFF, escuro: 0x1A1A1E)
    /// Bege dos avatares e chips neutros — "warm" no quadro de identidade.
    static let bege = Color(claro: 0xF0EBE1, escuro: 0x2B2B27)
    /// Areia dos painéis grandes (voz e talão).
    static let areia = Color(claro: 0xF7EEDB, escuro: 0x26241E)
    /// Dourado claro dos botões de ação (texto escuro por cima).
    static let douradoBotao = Color(claro: 0xE8CD91, escuro: 0xC9A45A)
    static let tinta = Color(claro: 0x302B24, escuro: 0xF2F0EB)
    static let tintaSuave = Color(claro: 0x7A756C, escuro: 0xA9A49A)
    /// Preto fosco quente para ícones e setas — nunca preto puro.
    static let tintaFosca = Color(claro: 0x38342E, escuro: 0xE8E4DC)
    static let dourado = Color(claro: 0xC9A45A, escuro: 0xC9A45A)
    static let douradoEscuro = Color(claro: 0x8E641F, escuro: 0xD4AD5F)
    /// Verde discreto para receitas e confirmações — "positive" na identidade.
    static let positivo = Color(claro: 0x456B56, escuro: 0x8AC69C)
    /// Linhas finas: tinta a 15% — o sistema visual pede 12%, mas sobre
    /// o fundo branco puro é preciso um ponto mais para se ler.
    static var separador: Color { tinta.opacity(0.15) }

    /// Margem horizontal dos ecrãs — 26 pt, a grelha do Figma (6,67 % de 390).
    static let margemDoEcra: CGFloat = 26

    /// Cantos do sistema: cartões 22 · botões e campos 25 · chips 14.
    enum Raio {
        static let cartao: CGFloat = 22
        static let campo: CGFloat = 25
        static let chip: CGFloat = 14
    }

    /// Dourado das barras de progresso: rampa limpa escuro→claro,
    /// sem riscas — as 6 paragens originais ficavam listradas em barras finas.
    static var douradoMetalico: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "A97F35"), Color(hex: "C9A45A"), Color(hex: "EAD59B")],
            startPoint: .leading,
            endPoint: .trailing
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
