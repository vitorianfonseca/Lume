import SwiftUI

// Peças que dão identidade à Lume, para a app não parecer "de série":
// valores com hierarquia (euros grandes, cêntimos pequenos), categorias
// com mosaico e ícone próprios, o anel dourado do mês e mosaicos de cor
// para os ícones das definições.

/// Um valor em euros com hierarquia tipográfica: a parte inteira grande e
/// "‚54 €" menor e mais suave, alinhados pela linha de base.
struct ValorEmEuros: View {
    let valor: Decimal
    var tamanho: CGFloat = 38
    var peso: Font.Weight = .semibold
    var cor: Color = Tema.tinta

    var body: some View {
        let texto = FormatadorDeMoeda.texto(valor)
        let partes = dividir(texto)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(partes.inteiro)
                .font(Tema.fonte(tamanho, peso))
                .foregroundStyle(cor)
                .contentTransition(.numericText())
            Text(partes.resto)
                .font(Tema.fonte(tamanho * 0.48, .medium))
                .foregroundStyle(Tema.tintaSuave)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormatadorDeMoeda.falado(valor))
    }

    /// "1 059,76 €" → ("1 059", ",76 €"). Sem vírgula, fica tudo grande.
    private func dividir(_ texto: String) -> (inteiro: String, resto: String) {
        guard let virgula = texto.lastIndex(of: ",") else { return (texto, "") }
        return (String(texto[..<virgula]), String(texto[virgula...]))
    }
}

/// O ícone de uma categoria, em ouro polido como os do Perfil.
/// - Para os ícones com render próprio (carrinho, talheres, comboio, play,
///   bilhete), usa a imagem.
/// - Para todos os outros, incluindo categorias criadas depois, desenha o
///   símbolo da categoria em marfim, com um contorno dourado em relevo,
///   sobre um mosaico dourado vazio (feito a partir dos mesmos renders).
/// Sem categoria, as iniciais do título num mosaico neutro.
struct IconeDeCategoria: View {
    let categoria: Categoria?
    var textoAlternativo: String = ""
    var lado: CGFloat = 40

    var body: some View {
        if let categoria {
            IconeDourado(simbolo: categoria.simbolo, lado: lado)
        } else {
            AvatarDeIniciais(texto: textoAlternativo, lado: lado)
                .frame(width: lado, height: lado)
                .accessibilityHidden(true)
        }
    }
}

/// Um ícone 3D dourado para "coisas" (categorias, objetivos, poupança):
/// a regra da Lume é linha para a interface (ações, campos) e 3D para coisas.
/// Usa o render próprio quando existe; senão desenha o SF Symbol em marfim,
/// com contorno dourado em relevo, sobre o mosaico dourado vazio.
struct IconeDourado: View {
    let simbolo: String
    var lado: CGFloat = 40

    /// Os símbolos que têm render próprio em Assets.
    static let renders: [String: String] = [
        "cart.fill": "IconeCategoria-supermercado",
        "cart": "IconeCategoria-supermercado",
        "fork.knife": "IconeCategoria-restauracao",
        "tram.fill": "IconeCategoria-transportes",
        "tram": "IconeCategoria-transportes",
        "play.rectangle.fill": "IconeCategoria-subscricoes",
        "play.rectangle": "IconeCategoria-subscricoes",
        "ticket.fill": "IconeCategoria-lazer",
        "ticket": "IconeCategoria-lazer",
        "house.fill": "IconeCategoria-casa",
        "house": "IconeCategoria-casa",
        "tshirt.fill": "IconeCategoria-roupa",
        "tshirt": "IconeCategoria-roupa",
        "cross.case.fill": "IconeCategoria-saude",
        "cross.case": "IconeCategoria-saude",
        "heart.text.square.fill": "IconeCategoria-saude",
        "heart.fill": "IconeCategoria-saude",
        // Sem categoria própria ainda, mas já prontos para quando ela criar
        // "Poupança", "Viagens" ou "Trabalho" com um destes símbolos.
        "banknote.fill": "IconeCategoria-poupanca",
        "eurosign.circle.fill": "IconeCategoria-poupanca",
        "airplane": "IconeCategoria-viagens",
        "airplane.fill": "IconeCategoria-viagens",
        "briefcase.fill": "IconeCategoria-trabalho",
        "briefcase": "IconeCategoria-trabalho",
        "ellipsis": "IconeCategoria-outras",
        "ellipsis.circle.fill": "IconeCategoria-outras",
    ]

    var body: some View {
        Group {
            if let render = Self.renders[simbolo] {
                Image(render)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ZStack {
                    Image("IconeCategoria-vazio")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                    // O símbolo em marfim, com um contorno dourado e uma
                    // sombra curta por baixo, para parecer em relevo.
                    Image(systemName: simbolo)
                        .font(.system(size: lado * 0.38, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(hex: "FFFBF2"), Color(hex: "EBDDC4")],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .shadow(color: Color(hex: "8A5A12").opacity(0.9), radius: 0.4)
                        .shadow(color: Color(hex: "6F4508").opacity(0.45), radius: 0.8, y: 0.8)
                }
            }
        }
        .frame(width: lado, height: lado)
        .shadow(color: Tema.sombraDoOuro.opacity(0.15), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

/// Um ícone num mosaico de cor, para as linhas das definições.
struct IconeEmMosaico: View {
    let simbolo: String
    let cor: Color
    var lado: CGFloat = 30

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: lado * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: lado, height: lado)
            .background(
                LinearGradient(colors: [cor.mix(with: .white, by: 0.15), cor], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: lado * 0.3)
            )
            .accessibilityHidden(true)
    }
}

/// O anel do mês: quanto do orçamento já foi usado, em ouro, com a
/// percentagem ao centro.
struct AnelDoMes: View {
    let fracao: Double
    var lado: CGFloat = 64

    var body: some View {
        let limitada = min(max(fracao, 0), 1)
        // Traço mais fino — ela achou o anel pesado.
        ZStack {
            Circle()
                .stroke(Tema.bege, lineWidth: lado * 0.07)
            Circle()
                .trim(from: 0, to: limitada)
                .stroke(
                    AngularGradient(
                        colors: [Tema.acento.corDe, Tema.acento.corAte, Tema.acento.corDe],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lado * 0.07, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((fracao * 100).rounded()))%")
                    .font(Tema.fonte(lado * 0.24, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
                    .contentTransition(.numericText())
                Text("usado")
                    .font(Tema.fonte(lado * 0.13))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .frame(width: lado, height: lado)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((fracao * 100).rounded())) por cento do orçamento usado")
    }
}

/// Uma pequena cápsula com a percentagem de um limite: neutra por baixo
/// de 75%, âmbar perto do limite e vermelha a partir de 100%.
struct CapsulaDePercentagem: View {
    let fracao: Double

    var body: some View {
        let percentagem = Int((fracao * 100).rounded())
        // Neutra abaixo de 75%, âmbar até 99%, vermelha a partir de 100%.
        let (texto, fundo): (Color, Color) =
            fracao >= 1 ? (Tema.negativo, Tema.fundoNegativo)
            : fracao >= 0.75 ? (Tema.aviso, Tema.fundoDoAviso)
            : (Tema.tintaSuave, Tema.bege)
        Text("\(percentagem)%")
            .font(Tema.fonte(11, .semibold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(texto)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(fundo, in: Capsule())
    }
}
