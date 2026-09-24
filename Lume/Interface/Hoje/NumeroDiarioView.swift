import SwiftUI

/// O número do dia, em grande e alinhado à esquerda, como no Figma:
/// parte inteira em bold e tinta, decimais mais pequenos em tintaSuave.
/// Negativo é mostrado com calma, sem alarmes.
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
        let partes = partesDoValor(dia.hojePodesGastar)
        return VStack(alignment: .leading, spacing: 6) {
            Text(dia.hojePodesGastar < .zero ? "Hoje já passaste" : "Hoje podes gastar")
                .font(.subheadline)
                .foregroundStyle(Tema.tintaSuave)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(partes.inteira)
                    .font(.system(size: tamanhoInteiro, weight: .bold))
                    .foregroundStyle(Tema.tinta)
                Text(partes.decimais)
                    .font(.system(size: tamanhoDecimais))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .monospacedDigit()
            .contentTransition(.numericText())
            .minimumScaleFactor(0.5)
            .lineLimit(1)

            Text("\(fraseDosDias(dia.diasRestantes)) · \(FormatadorDeMoeda.texto(dia.disponivelDoMes)) disponíveis")
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)

            // A barra dourada do Figma: quanto da fatia de hoje já foi gasta.
            BarraDeProgresso(fracao: fracaoGastaDeHoje(dia))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // VoiceOver lê tudo como uma frase única e natural.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fraseCompleta(para: dia))
    }

    /// Ocupa o lugar do número: título grande e uma ação dourada direta,
    /// em vez de mandar procurar nas Definições.
    private var semRendimento: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Define o rendimento do mês")
                .font(.title.weight(.bold))
                .foregroundStyle(Tema.tinta)

            Text("Indica quanto esperas receber e a Lume calcula o teu número diário — quanto podes gastar por dia.")
                .font(.subheadline)
                .foregroundStyle(Tema.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)

            Button { aoDefinirRendimento() } label: {
                Text("Definir rendimento")
                    .font(.subheadline.weight(.semibold))
                    // Tinta escura fixa: sobre dourado, o contraste é igual nos dois modos.
                    .foregroundStyle(Color(hex: "141416"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Tema.dourado, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Quanto da fatia de hoje já foi gasta, para a barra dourada.
    private func fracaoGastaDeHoje(_ dia: CalculadoraDoDia.Dia) -> Double {
        let orcamentoDeHoje = dia.hojePodesGastar + dia.gastoHoje
        guard orcamentoDeHoje > .zero else { return 1 }
        return (dia.gastoHoje as NSDecimalNumber).doubleValue
            / (orcamentoDeHoje as NSDecimalNumber).doubleValue
    }

    /// "1 092,90 €" → inteiro "1 092" e decimais ",90 €", como no Figma.
    private func partesDoValor(_ valor: Decimal) -> (inteira: String, decimais: String) {
        let texto = FormatadorDeMoeda.textoAbsoluto(valor)
        guard let virgula = texto.firstIndex(of: ",") else { return (texto, "") }
        return (String(texto[..<virgula]), String(texto[virgula...]))
    }

    private func fraseDosDias(_ dias: Int) -> String {
        dias == 1 ? "Último dia do mês" : "Faltam \(dias) dias"
    }

    private func fraseCompleta(para dia: CalculadoraDoDia.Dia) -> String {
        let valor = FormatadorDeMoeda.textoAbsoluto(dia.hojePodesGastar)
        let inicio = dia.hojePodesGastar < .zero
            ? "Hoje já passaste \(valor) do teu limite."
            : "Hoje podes gastar \(valor)."
        return "\(inicio) \(fraseDosDias(dia.diasRestantes)) e tens \(FormatadorDeMoeda.texto(dia.disponivelDoMes)) disponíveis este mês."
    }
}
