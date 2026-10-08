import SwiftUI

/// As cores dos cartões de destaque ("Bom ritmo", resumo do mês, objetivos)
/// e das barras de progresso. Ela experimentou 20 combinações e ficou com a
/// Areia; independentes do tema.
nonisolated struct AcentoDosCartoes: Identifiable, Equatable, Sendable {
    let id: String
    let nome: String
    /// Fundo do cartão de destaque no modo claro.
    let cartao: UInt32
    /// As duas pontas do degradê das barras e do anel.
    let barraDe: UInt32
    let barraAte: UInt32
    /// Cartão escuro: o texto dentro dele passa a claro.
    let cartaoEscuro: Bool

    init(_ id: String, _ nome: String, cartao: UInt32, barra: (UInt32, UInt32), escuro: Bool = false) {
        self.id = id
        self.nome = nome
        self.cartao = cartao
        self.barraDe = barra.0
        self.barraAte = barra.1
        self.cartaoEscuro = escuro
    }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }

    /// O fundo do cartão; no modo escuro do iPhone, os cartões claros passam
    /// a um oliva profundo (os escuros ficam como estão).
    var corDoCartao: Color {
        Color(claro: cartao, escuro: cartaoEscuro ? cartao : 0x34352A)
    }

    var corDe: Color { Color(claro: barraDe, escuro: barraDe) }
    var corAte: Color { Color(claro: barraAte, escuro: barraAte) }

    var gradienteDaBarra: LinearGradient {
        LinearGradient(colors: [corDe, corAte], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - A cor escolhida

    /// Cartões em verde-oliva #E9E7D3 (de volta — o menta não era o que
    /// ela queria). Barras num creme puxado para o branco — a mesma cor
    /// do centro dos ícones dourados (medida nos PNG: #EDE4D7/#EFE5D5).
    static let areia = AcentoDosCartoes("areia", "Areia", cartao: 0xE9E7D3, barra: (0xE9DFCC, 0xF5EFE4))
}

#Preview("Cores candidatas do cartão") {
    let candidatas: [(String, UInt32, Bool)] = [
        ("1 · Branco", 0xFFFFFF, false),
        ("2 · Marfim", 0xFAF6EE, false),
        ("3 · Rosa-champanhe", 0xF4E8E3, false),
        ("4 · Sálvia", 0xE5EBE2, false),
        ("5 · Névoa azul", 0xE6EBF1, false),
        ("6 · Verde-floresta", 0x22332B, true),
        ("7 · Azul-noite", 0x1E2633, true),
        ("8 · Grafite", 0x2A2A2C, true),
    ]
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(candidatas, id: \.0) { nome, cor, escuro in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(Ilustracao.Tipo.graficos.imagem)
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: 44, height: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bom ritmo").font(Tema.fonte(13, .semibold))
                            Text("Continua assim.").font(Tema.fonte(10)).opacity(0.7)
                        }
                    }
                    BarraDeProgresso(fracao: 0.6)
                }
                .foregroundStyle(escuro ? .white : Tema.tinta)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartao(Color(claro: cor, escuro: cor))
                .overlay(alignment: .bottomTrailing) {
                    Text(nome).font(Tema.fonte(9, .semibold)).padding(6)
                        .foregroundStyle(escuro ? .white.opacity(0.6) : Tema.tintaSuave)
                }
            }
        }
        .padding(16)
    }
    .background(Tema.fundo)
}
