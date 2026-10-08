import SwiftUI

/// O número do dia, em grande e alinhado à esquerda, como no Figma:
/// parte inteira em bold e tinta, decimais mais pequenos em tintaSuave.
/// Negativo é mostrado com calma, sem alarmes. Usa os números reconciliados
/// da calculadora (`porDia`, `disponivelAgora`), os mesmos do Resumo.
struct NumeroDiarioView: View {
    let resultado: CalculadoraDoDia.Resultado
    /// Salta para as Definições quando ainda não há rendimento; injetado pela RaizView.
    var aoDefinirRendimento: () -> Void = {}

    // Escalam com o Dynamic Type a partir dos estilos de título.
    @ScaledMetric(relativeTo: .largeTitle) private var tamanhoInteiro = 51
    @ScaledMetric(relativeTo: .title2) private var tamanhoDecimais = 27

    var body: some View {
        switch resultado {
        case .semRendimento:
            semRendimento
        case .calculado(let dia):
            numero(para: dia)
        }
    }

    private func numero(para dia: CalculadoraDoDia.Dia) -> some View {
        let partes = partesDoValor(dia.porDia)
        return VStack(alignment: .leading, spacing: 6) {
            Text(dia.porDia < .zero ? "Acima do orçamento do mês" : "Podes gastar por dia")
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(partes.inteira)
                    .font(Tema.fonte(tamanhoInteiro, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text(partes.decimais)
                    .font(Tema.fonte(tamanhoDecimais))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .monospacedDigit()
            .contentTransition(.numericText())
            .minimumScaleFactor(0.5)
            .lineLimit(1)

            Text("\(fraseDosDias(dia.diasRestantes)) · \(FormatadorDeMoeda.texto(dia.disponivelAgora)) disponíveis")
                .font(Tema.fonte(13))
                .monospacedDigit()
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // VoiceOver lê tudo como uma frase única e natural.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fraseCompleta(para: dia))
    }

    /// Ocupa o lugar do número: um título abaixo do da página (22 pt contra
    /// 27 pt) e a ação dourada única, em vez de mandar procurar nas Definições.
    private var semRendimento: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Define o rendimento do mês")
                .font(Tema.fonte(22, .semibold))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Indica quanto esperas receber e a Lume calcula o teu número diário — quanto podes gastar por dia.")
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)

            BotaoLume(titulo: "Definir rendimento", estilo: .principal) { aoDefinirRendimento() }
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "1 092,90 €" → inteiro "1 092" e decimais ",90 €", como no Figma.
    private func partesDoValor(_ valor: Decimal) -> (inteira: String, decimais: String) {
        let texto = FormatadorDeMoeda.texto(valor)
        guard let virgula = texto.firstIndex(of: ",") else { return (texto, "") }
        return (String(texto[..<virgula]), String(texto[virgula...]))
    }

    private func fraseDosDias(_ dias: Int) -> String {
        dias == 1 ? "Último dia do mês" : "Faltam \(dias) dias"
    }

    private func fraseCompleta(para dia: CalculadoraDoDia.Dia) -> String {
        let inicio = dia.porDia < .zero
            ? "Estás \(FormatadorDeMoeda.falado(-dia.porDia)) por dia acima do orçamento do mês."
            : "Podes gastar \(FormatadorDeMoeda.falado(dia.porDia)) por dia."
        return "\(inicio) \(fraseDosDias(dia.diasRestantes)) e tens \(FormatadorDeMoeda.falado(dia.disponivelAgora)) disponíveis este mês."
    }
}
