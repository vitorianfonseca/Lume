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
            VStack(alignment: .leading, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 12) {
            if case .calculado(let dia) = resultado {
                HStack {
                    Text(mesDoCartao)
                        .font(Tema.fonte(11, .semibold))
                        .foregroundStyle(Tema.douradoEscuro)
                    Spacer()
                    Text("Este mês")
                        .font(Tema.fonte(12, .semibold))
                        .foregroundStyle(Tema.douradoEscuro)
                        .frame(width: 80, height: 32)
                        .background(Tema.areia, in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(FormatadorDeMoeda.texto(gastoDoMes))
                        .font(Tema.fonte(38, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                        .contentTransition(.numericText())
                    Text("gastos de um orçamento de \(FormatadorDeMoeda.texto(rendimentoDoMes))")
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                }

                BarraDeProgresso(fracao: fracaoDoOrcamento)

                // Duas colunas alinhadas à esquerda, a segunda a meio do cartão.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ainda disponíveis")
                            .font(Tema.fonte(11))
                            .foregroundStyle(Tema.tintaSuave)
                        Text(FormatadorDeMoeda.texto(dia.disponivelDoMes))
                            .font(Tema.fonte(20, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tinta)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Por dia · \(dia.diasRestantes) \(dia.diasRestantes == 1 ? "dia" : "dias")")
                            .font(Tema.fonte(11))
                            .foregroundStyle(Tema.tintaSuave)
                        Text(FormatadorDeMoeda.texto(porDia(de: dia)))
                            .font(Tema.fonte(20, .medium))
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
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ritmo do mês")
                    .font(Tema.fonte(10))
                    .foregroundStyle(Tema.tintaSuave)
                Text(dentroDoLimite ? "Dentro do limite" : "Acima do ritmo")
                    .font(Tema.fonte(10, .medium))
                    .foregroundStyle(dentroDoLimite ? Tema.positivo : Tema.douradoEscuro)
            }
            .frame(width: 102, alignment: .leading)
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
                    .foregroundStyle(Tema.douradoBotao)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 36)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ritmo do mês: \(dentroDoLimite ? "dentro do limite" : "acima do ritmo")")
    }

    // MARK: - Ações rápidas

    private var acoesRapidas: some View {
        // Três blocos de 48 pt, como no frame.
        HStack(spacing: 8) {
            acao("Escrever", simbolo: nil) { aoRegistar(.texto) }
            acao("Falar", simbolo: "mic") { aoRegistar(.voz) }
            acao("Talão", simbolo: "camera") { aoRegistar(.talao) }
        }
    }

    /// Como no frame: ícone dourado + texto 13 Medium, num bloco branco
    /// de 48 pt. Sem símbolo SF, usa-se o "T" serifado do design.
    private func acao(_ titulo: String, simbolo: String?, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack(spacing: 8) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(Tema.fonte(14))
                        .foregroundStyle(Tema.douradoEscuro)
                } else {
                    IconeDeTexto(tamanho: 14)
                        .foregroundStyle(Tema.douradoEscuro)
                }
                Text(titulo)
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.tinta)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 16))
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
            VStack(alignment: .leading, spacing: 10) {
                TituloDeSeccao(titulo: "Os teus limites", acao: "Ver todos") { aoPlanear() }

                ForEach(linhas) { linha in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(linha.categoria.nome)
                                .font(Tema.fonte(13, .medium))
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Text("\(FormatadorDeMoeda.textoEmEurosInteiros(linha.gasto)) / \(FormatadorDeMoeda.textoEmEurosInteiros(linha.orcamento)) €")
                                .font(Tema.fonte(12))
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        BarraDeProgresso(fracao: linha.fracao)
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
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.top, 4)
            } else {
                // Sem divisórias, como no frame — as linhas respiram sozinhas.
                VStack(spacing: 0) {
                    ForEach(visiveis) { transacao in
                        LinhaDeTransacao(transacao: transacao)
                            .contentShape(Rectangle())
                            .onTapGesture { transacaoEmEdicao = transacao }
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
