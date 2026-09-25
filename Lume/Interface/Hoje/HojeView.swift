import Charts
import SwiftData
import SwiftUI

/// O ecrã Resumo do novo design: o mês em destaque num cartão (total gasto,
/// disponível, por dia e o ritmo com gráfico), ações rápidas de registo,
/// limites e últimos movimentos. O registo em si vive no separador Registar.
struct HojeView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]

    /// Injetados pela RaizView: navegação entre separadores.
    var aoVerTudo: () -> Void = {}
    var aoDefinirRendimento: () -> Void = {}
    var aoRegistar: (ModoDeRegisto) -> Void = { _ in }
    var aoPlanear: () -> Void = {}

    @State private var viewModel = HojeViewModel()
    @State private var transacaoEmEdicao: Transacao?

    private var resultado: CalculadoraDoDia.Resultado {
        viewModel.resultadoDoDia(
            transacoes: transacoes,
            recorrentes: recorrentes,
            definicoes: definicoes
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecalho
                cartaoDoMes
                acoesRapidas
                limites
                ultimosMovimentos
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .animation(.snappy, value: resultado)
        .sheet(item: $transacaoEmEdicao) { transacao in
            CartaoDeConfirmacaoView(
                proposta: PropostaDeTransacao(de: transacao),
                categorias: categorias,
                titulo: "EDITAR MOVIMENTO",
                textoDeConfirmacao: "Guardar",
                aoConfirmar: { proposta in
                    transacao.aplicar(proposta, categorias: categorias)
                    try? contexto.save()
                    transacaoEmEdicao = nil
                },
                aoCancelar: { transacaoEmEdicao = nil },
                aoEliminar: {
                    contexto.delete(transacao)
                    try? contexto.save()
                    transacaoEmEdicao = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Cabeçalho

    private var dataDoCabecalho: String {
        let localidade = FormatadorDeMoeda.localidade
        let semana = Date.now.formatted(.dateTime.weekday(.wide).locale(localidade))
        let dia = Date.now.formatted(.dateTime.day().locale(localidade))
        let mes = Date.now.formatted(.dateTime.month(.wide).locale(localidade))
        return "\(semana), \(dia) \(mes)".uppercased()
    }

    /// "SETEMBRO 2026", sem o "de" — igual ao frame.
    private var mesDoCartao: String {
        let localidade = FormatadorDeMoeda.localidade
        let mes = Date.now.formatted(.dateTime.month(.wide).locale(localidade))
        let ano = Date.now.formatted(.dateTime.year().locale(localidade))
        return "\(mes) \(ano)".uppercased()
    }

    private var cabecalho: some View {
        // "QUINTA-FEIRA, 24 SETEMBRO", exatamente como no Figma (sem "de").
        CabecalhoDeEcra(legenda: dataDoCabecalho, titulo: "O teu mês")
    }

    // MARK: - Cartão do mês

    /// Todas as despesas do mês corrente, recorrentes incluídas.
    private var gastoDoMes: Decimal {
        let calendario = Calendar.current
        return transacoes
            .filter { $0.tipo == .despesa && calendario.isDate($0.data, equalTo: .now, toGranularity: .month) }
            .reduce(Decimal.zero) { $0 + $1.valor }
    }

    private var rendimentoDoMes: Decimal {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }?.rendimentoEsperado ?? .zero
    }

    @ViewBuilder
    private var cartaoDoMes: some View {
        VStack(alignment: .leading, spacing: 14) {
            if case .calculado(let dia) = resultado {
                HStack {
                    Text(mesDoCartao)
                        .font(.caption2.weight(.semibold))
                        .kerning(1.2)
                        .foregroundStyle(Tema.douradoEscuro)
                    Spacer()
                    Text("Este mês")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Tema.tinta)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Tema.areia, in: Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(FormatadorDeMoeda.texto(gastoDoMes))
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                        .contentTransition(.numericText())
                    Text("gastos de um orçamento de \(FormatadorDeMoeda.texto(rendimentoDoMes))")
                        .font(.footnote)
                        .foregroundStyle(Tema.tintaSuave)
                }

                BarraDeProgresso(fracao: fracaoDoOrcamento)

                // Duas colunas alinhadas à esquerda, a segunda a meio do cartão.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ainda disponíveis")
                            .font(.caption)
                            .foregroundStyle(Tema.tintaSuave)
                        Text(FormatadorDeMoeda.texto(dia.disponivelDoMes))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tinta)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Por dia · \(dia.diasRestantes) \(dia.diasRestantes == 1 ? "dia" : "dias")")
                            .font(.caption)
                            .foregroundStyle(Tema.tintaSuave)
                        Text(FormatadorDeMoeda.texto(porDia(de: dia)))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tinta)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ritmoDoMes
            } else {
                NumeroDiarioView(resultado: resultado, aoDefinirRendimento: aoDefinirRendimento)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }

    private var fracaoDoOrcamento: Double {
        guard rendimentoDoMes > .zero else { return 0 }
        return (gastoDoMes as NSDecimalNumber).doubleValue
            / (rendimentoDoMes as NSDecimalNumber).doubleValue
    }

    /// A fatia diária inteira (antes dos gastos de hoje), como no design.
    private func porDia(de dia: CalculadoraDoDia.Dia) -> Decimal {
        guard dia.diasRestantes > 0 else { return dia.disponivelDoMes }
        return (dia.disponivelDoMes / Decimal(dia.diasRestantes)).arredondadoACentimos()
    }

    // MARK: - Ritmo do mês

    private struct PontoDoRitmo: Identifiable {
        let dia: Int
        let acumulado: Double
        var id: Int { dia }
    }

    private var pontosDoRitmo: [PontoDoRitmo] {
        let calendario = Calendar.current
        let diaAtual = calendario.component(.day, from: .now)
        let despesas = transacoes.filter {
            $0.tipo == .despesa && calendario.isDate($0.data, equalTo: .now, toGranularity: .month)
        }
        var acumulado = 0.0
        return (1...max(diaAtual, 1)).map { dia in
            let doDia = despesas
                .filter { calendario.component(.day, from: $0.data) == dia }
                .reduce(Decimal.zero) { $0 + $1.valor }
            acumulado += (doDia as NSDecimalNumber).doubleValue
            return PontoDoRitmo(dia: dia, acumulado: acumulado)
        }
    }

    private var dentroDoLimite: Bool {
        let calendario = Calendar.current
        let diaAtual = calendario.component(.day, from: .now)
        let diasNoMes = calendario.range(of: .day, in: .month, for: .now)?.count ?? 30
        let ritmoIdeal = (rendimentoDoMes as NSDecimalNumber).doubleValue
            * Double(diaAtual) / Double(diasNoMes)
        return (gastoDoMes as NSDecimalNumber).doubleValue <= ritmoIdeal
    }

    @ViewBuilder
    private var ritmoDoMes: some View {
        let diasNoMes = Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30
        // Como no frame: legendas à esquerda, gráfico à direita.
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ritmo do mês")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
                Text(dentroDoLimite ? "Dentro do limite" : "Acima do ritmo")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(dentroDoLimite ? Tema.positivo : Tema.douradoEscuro)
            }
            .fixedSize()
            Chart {
                // A referência: gastar o orçamento a ritmo constante.
                ForEach([1, diasNoMes], id: \.self) { dia in
                    LineMark(
                        x: .value("Dia", dia),
                        y: .value("Ideal", dia == 1 ? 0 : (rendimentoDoMes as NSDecimalNumber).doubleValue),
                        series: .value("Série", "ideal")
                    )
                    .foregroundStyle(Tema.tintaSuave.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                ForEach(pontosDoRitmo) { ponto in
                    LineMark(
                        x: .value("Dia", ponto.dia),
                        y: .value("Gasto", ponto.acumulado),
                        series: .value("Série", "gasto")
                    )
                    .foregroundStyle(Tema.douradoMetalico)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ritmo do mês: \(dentroDoLimite ? "dentro do limite" : "acima do ritmo")")
    }

    // MARK: - Ações rápidas

    private var acoesRapidas: some View {
        HStack(spacing: 10) {
            acao("Escrever", simbolo: "textformat") { aoRegistar(.texto) }
            acao("Falar", simbolo: "mic") { aoRegistar(.voz) }
            acao("Talão", simbolo: "camera") { aoRegistar(.talao) }
        }
    }

    /// Como no frame: ícone dourado + texto, sem cápsulas nem contornos.
    private func acao(_ titulo: String, simbolo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack(spacing: 8) {
                Image(systemName: simbolo)
                    .font(.subheadline)
                    .foregroundStyle(Tema.douradoEscuro)
                Text(titulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Tema.tinta)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Limites

    private struct LinhaDeLimite: Identifiable {
        let categoria: Categoria
        let gasto: Decimal
        let orcamento: Decimal
        let fracao: Double
        var id: PersistentIdentifier { categoria.persistentModelID }
    }

    private var linhasDeLimite: [LinhaDeLimite] {
        let linhas = categorias.compactMap { categoria -> LinhaDeLimite? in
            guard let orcamento = categoria.orcamentoMensal, orcamento > .zero else { return nil }
            let gasto = gastoDoMes(em: categoria)
            let fracao = (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
            return LinhaDeLimite(categoria: categoria, gasto: gasto, orcamento: orcamento, fracao: fracao)
        }
        return Array(linhas.sorted { $0.fracao > $1.fracao }.prefix(2))
    }

    @ViewBuilder
    private var limites: some View {
        let linhas = linhasDeLimite
        if !linhas.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                TituloDeSeccao(titulo: "Os teus limites", acao: "Ver todos") { aoPlanear() }

                ForEach(linhas) { linha in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(linha.categoria.nome)
                                .font(.subheadline)
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Text("\(FormatadorDeMoeda.textoEmEurosInteiros(linha.gasto)) / \(FormatadorDeMoeda.textoEmEurosInteiros(linha.orcamento)) €")
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        BarraDeProgresso(fracao: linha.fracao, dourada: true, altura: 4)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func gastoDoMes(em categoria: Categoria) -> Decimal {
        let calendario = Calendar.current
        return transacoes
            .filter { transacao in
                transacao.tipo == .despesa
                    && transacao.categoria?.persistentModelID == categoria.persistentModelID
                    && calendario.isDate(transacao.data, equalTo: .now, toGranularity: .month)
            }
            .reduce(Decimal.zero) { $0 + $1.valor }
    }

    // MARK: - Últimos movimentos

    private var ultimosMovimentos: some View {
        let visiveis = Array(transacoes.prefix(2))
        return VStack(alignment: .leading, spacing: 8) {
            if visiveis.isEmpty {
                TituloDeSeccao(titulo: "Últimos movimentos")
            } else {
                TituloDeSeccao(titulo: "Últimos movimentos", acao: "Ver todos") { aoVerTudo() }
            }

            if visiveis.isEmpty {
                Text("Ainda sem movimentos. Regista o primeiro no separador Registar.")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(visiveis) { transacao in
                        LinhaDeTransacao(transacao: transacao)
                            .contentShape(Rectangle())
                            .onTapGesture { transacaoEmEdicao = transacao }
                        if transacao.persistentModelID != visiveis.last?.persistentModelID {
                            Divider().overlay(Tema.separador)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Com dados") {
    HojeView()
        .modelContainer(ContentorDeDados.emMemoria())
}

#Preview("Vazio") {
    HojeView()
        .modelContainer(ContentorDeDados.emMemoria(comDadosDeExemplo: false))
}
