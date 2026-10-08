import SwiftUI

/// As ilustrações da Lume: renders 3D fotorrealistas no mesmo ouro da
/// logo (imagens em Assets, "Ilustracao3D-…", já sem fundo), para
/// funcionarem em claro e em escuro.
struct Ilustracao: View {
    enum Tipo {
        /// Sem movimentos: uma carteira com uma moeda a espreitar.
        case carteira
        /// Pesquisa sem resultados: uma lupa de ouro sobre um talão.
        case lupa
        /// Objetivos e bom ritmo: um frasco de vidro com moedas.
        case frasco
        /// Limites e ritmo: barras a subir, com uma moeda no topo.
        case graficos
        /// Contas: dois cartões empilhados.
        case cartoes
        /// Registar por texto: um balão de conversa com uma moeda.
        case balao
        /// Privacidade: um cadeado de ouro.
        case cadeado

        var imagem: String {
            switch self {
            case .carteira: "Ilustracao3D-carteira"
            case .lupa: "Ilustracao3D-lupa"
            case .frasco: "Ilustracao3D-frasco"
            case .graficos: "Ilustracao3D-graficos"
            case .cartoes: "Ilustracao3D-cartoes"
            case .balao: "Ilustracao3D-balao"
            case .cadeado: "Ilustracao3D-cadeado"
            }
        }
    }

    let tipo: Tipo
    var escala: CGFloat = 1

    var body: some View {
        Image(tipo.imagem)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            // Uma sombra de contacto suave assenta o objeto no cartão.
            .shadow(color: .black.opacity(0.12), radius: 8, y: 6)
            .padding(6)
            .frame(width: 180 * escala, height: 130 * escala)
            .accessibilityHidden(true)
    }
}

// MARK: - Estado vazio

/// Ilustração + título + frase, centrados. O padrão de todos os vazios da app.
struct EstadoVazio: View {
    let ilustracao: Ilustracao.Tipo
    let titulo: String
    let texto: String
    var escala: CGFloat = 1

    var body: some View {
        VStack(spacing: 8) {
            Ilustracao(tipo: ilustracao, escala: escala)
                .padding(.bottom, 6)
            Text(titulo)
                .font(Tema.fonte(17, .semibold))
                .foregroundStyle(Tema.tinta)
            Text(texto)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Ilustrações") {
    ScrollView {
        VStack(spacing: 24) {
            EstadoVazio(ilustracao: .carteira, titulo: "Sem movimentos", texto: "Regista o primeiro com os botões acima.")
            EstadoVazio(ilustracao: .lupa, titulo: "Nada encontrado", texto: "Tenta outra palavra.")
            EstadoVazio(ilustracao: .frasco, titulo: "Sem objetivos", texto: "Começa por um pequeno.")
            EstadoVazio(ilustracao: .graficos, titulo: "Sem limites", texto: "Distribui o orçamento.")
            EstadoVazio(ilustracao: .cartoes, titulo: "Sem contas", texto: "Cria a tua primeira conta.")
            EstadoVazio(ilustracao: .balao, titulo: "Escreve como falas", texto: "“café 1,20”")
            EstadoVazio(ilustracao: .cadeado, titulo: "Os teus dados são teus", texto: "Ficam no teu iPhone.")
        }
        .padding(24)
    }
    .background(Tema.fundo)
}

#Preview("Gráficos e cartões") {
    VStack(spacing: 24) {
        EstadoVazio(ilustracao: .graficos, titulo: "Sem limites", texto: "Distribui o orçamento.")
        EstadoVazio(ilustracao: .cartoes, titulo: "Sem contas", texto: "Cria a tua primeira conta.")
    }
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(Tema.fundo)
}
