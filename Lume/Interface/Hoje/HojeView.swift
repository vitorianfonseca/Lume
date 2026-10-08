import Charts
import SwiftData
import SwiftUI

/// O ecrã Resumo: um só herói (quanto podes gastar por dia), a conta do mês
/// à vista (disponível + gasto + reservado = rendimento), ações rápidas de
/// registo, limites e últimos movimentos. Os números são os mesmos do
/// Planear e do widget — saem todos do `CalculadoraDoDia.Dia`.
struct HojeView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @AppStorage("esconderValoresNoWidget") private var esconderValoresNoWidget = false

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
                notaDoRitmo
                primeirosPassos
                limites
                ultimosMovimentos
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .animation(.snappy, value: resultado)
        .onAppear { publicarParaOWidget() }
        .onChange(of: resultado) { publicarParaOWidget() }
        // Para refletir de imediato quem muda "Esconder valores" no Perfil
        // e volta ao Resumo, sem esperar por um movimento novo.
        .onChange(of: esconderValoresNoWidget) { publicarParaOWidget() }
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
                },
                conta: transacao.conta,
                aoEscolherConta: { transacao.conta = $0 }
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

    private var cabecalho: some View {
        // "QUINTA-FEIRA, 24 SETEMBRO", sem "de". A data só aparece aqui —
        // o cartão já não repete o mês. O Resumo é o único ecrã com a marca.
        CabecalhoDeEcra(legenda: dataDoCabecalho, titulo: "O teu mês", mostrarMarca: true)
    }

    /// O widget do ecrã inicial mostra os mesmos números — publicados aqui.
    private func publicarParaOWidget() {
        guard case .calculado(let dia) = resultado else { return }
        PartilhaComWidget.publicar(PartilhaComWidget.retrato(
            dia: dia,
            transacoes: transacoes,
            categorias: categorias,
            rendimento: rendimentoDoMes,
            valoresEscondidos: esconderValoresNoWidget
        ))
    }

    // MARK: - Cartão do mês

    private var rendimentoDoMes: Decimal {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }?.rendimentoEsperado ?? .zero
    }

    private var diaAtual: Int { Calendar.current.component(.day, from: .now) }
    private var diasNoMes: Int { Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30 }

    @ViewBuilder
    private var cartaoDoMes: some View {
        VStack(alignment: .leading, spacing: 14) {
            if case .calculado(let dia) = resultado {
                numeroDoDia(dia)

                Rectangle()
                    .fill(Tema.separador)
                    .frame(height: 1)

                contaDoMes(dia)

                // Antes do dia 3 o gráfico é só uma linha tracejada com um
                // ponto: não diz nada, por isso não aparece.
                if diaAtual >= 3 {
                    Rectangle()
                        .fill(Tema.separador)
                        .frame(height: 1)
                    ritmoDoMes(dia)
                }
            } else {
                NumeroDiarioView(resultado: resultado, aoDefinirRendimento: aoDefinirRendimento)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
        // Nos temas com destaque escuro (Noite, Esmeralda…), o cartão do mês
        // usa as cores escuras da paleta: fundo profundo, números claros.
        .environment(\.colorScheme, Tema.paleta.cartaoPrincipalEscuro ? .dark : esquema)
    }

    @Environment(\.colorScheme) private var esquema

    /// O herói: o disponível repartido pelos dias que faltam, com uma barra
    /// larga da percentagem usada — era um anel pequeno, mas deixava sempre
    /// um vazio de um dos lados; a barra ocupa o espaço que sobra em vez de
    /// o deixar em branco.
    private func numeroDoDia(_ dia: CalculadoraDoDia.Dia) -> some View {
        let dias = dia.diasRestantes == 1 ? "último dia do mês" : "faltam \(dia.diasRestantes) dias"
        let legenda = dia.porDia < .zero ? "ACIMA DO ORÇAMENTO DO MÊS" : "PODES GASTAR POR DIA"
        let fracao = fracaoDoRendimento(dia)
        return HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                // O rótulo vem primeiro e em dourado — o número grande, por
                // si só, podia confundir-se com "Ainda disponível" ou "Já
                // gastaste" no cartão por baixo (ela achou que não se
                // destacava o suficiente como "o" número do ecrã).
                Text(legenda)
                    .font(Tema.fonte(11, .semibold))
                    .foregroundStyle(Tema.ouro)
                ValorEmEuros(valor: dia.porDia, tamanho: 48)
                Text(dias)
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .fixedSize()

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(Int((fracao * 100).rounded()))% usado")
                    .font(Tema.fonte(12, .medium))
                    .foregroundStyle(Tema.tintaSuave)
                    .contentTransition(.numericText())
                BarraDeProgresso(fracao: fracao, altura: 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// O cartão do ritmo: a cápsula, o conselho e a ilustração — num cartão
    /// próprio em verde-oliva, separado do cartão principal (ela quer esta
    /// parte "fora desse cartão", como um destaque à parte).
    @ViewBuilder
    private var notaDoRitmo: some View {
        if case .calculado(let dia) = resultado {
            let noRitmo = dentroDoLimite(dia)
            let conselho = noRitmo
                ? (dia.gastoDoMes > .zero
                    ? "Abaixo do ritmo ideal. O que sobrar pode ir para um objetivo."
                    : "Ainda sem gastos este mês.")
                : "Abranda um pouco nos próximos dias e voltas ao caminho."
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(noRitmo ? "No ritmo" : "Acima do ritmo")
                        .font(Tema.fonte(11, .semibold))
                        .foregroundStyle(noRitmo ? AnyShapeStyle(Tema.positivo) : Tema.ouro)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Tema.superficie.opacity(0.6), in: Capsule())
                        .fixedSize()
                    Text(conselho)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(noRitmo ? Ilustracao.Tipo.frasco.imagem : Ilustracao.Tipo.graficos.imagem)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 64, height: 78)
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .cartaoCafe()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(noRitmo ? "No ritmo" : "Acima do ritmo"). \(conselho)")
        }
    }

    /// A conta à vista: disponível e gasto lado a lado, a barra do que já
    /// saiu do rendimento e, por baixo, o que está reservado.
    private func contaDoMes(_ dia: CalculadoraDoDia.Dia) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Duas metades iguais, separadas por um fio vertical que acompanha
            // a altura do texto (sem alturas fixas, para o Dynamic Type).
            HStack(spacing: 0) {
                coluna("Ainda disponível", valor: dia.disponivelAgora)
                Rectangle()
                    .fill(Tema.separador)
                    .frame(width: 1)
                coluna("Já gastaste", valor: dia.gastoDoMes)
                    .padding(.leading, 16)
            }
            .fixedSize(horizontal: false, vertical: true)

            // O traço marca onde o mês vai: barra à frente do traço = acima do ritmo.
            BarraDeProgresso(
                fracao: fracaoDoRendimento(dia),
                marcador: Double(diaAtual) / Double(diasNoMes)
            )
            .accessibilityLabel("Rendimento já gasto")

            if dia.reservado > .zero {
                Text("Reservado \(FormatadorDeMoeda.texto(dia.reservado)) · contas fixas e poupança")
                    .font(Tema.fonte(11))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func coluna(_ titulo: String, valor: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
            // Mais discretos do que o número do topo — este cartão só tem
            // um herói, estes são contexto de apoio.
            ValorEmEuros(valor: valor, tamanho: 19, peso: .medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func fracaoDoRendimento(_ dia: CalculadoraDoDia.Dia) -> Double {
        guard rendimentoDoMes > .zero else { return 0 }
        return (dia.gastoDoMes as NSDecimalNumber).doubleValue
            / (rendimentoDoMes as NSDecimalNumber).doubleValue
    }

    // MARK: - Ritmo do mês

    private struct PontoDoRitmo: Identifiable {
        let dia: Int
        let acumulado: Double
        var id: Int { dia }
    }

    /// O ritmo ideal até hoje: o rendimento gasto a ritmo constante.
    private var ritmoIdealDeHoje: Double {
        (rendimentoDoMes as NSDecimalNumber).doubleValue * Double(diaAtual) / Double(diasNoMes)
    }

    /// Dentro do limite = gasto do mês abaixo do ritmo ideal (a mesma regra do widget).
    private func dentroDoLimite(_ dia: CalculadoraDoDia.Dia) -> Bool {
        (dia.gastoDoMes as NSDecimalNumber).doubleValue <= ritmoIdealDeHoje
    }

    /// O gasto acumulado dia a dia, a partir do zero no "dia 0". O ponto de
    /// hoje é sempre o gasto do mês da calculadora, para bater com o cartão.
    private func pontosDoRitmo(_ dia: CalculadoraDoDia.Dia) -> [PontoDoRitmo] {
        let calendario = Calendar.current
        let despesas = transacoes.filter {
            $0.tipo == .despesa && calendario.isDate($0.data, equalTo: .now, toGranularity: .month)
        }
        var acumulado = 0.0
        var pontos = [PontoDoRitmo(dia: 0, acumulado: 0)]
        for numero in 1...max(diaAtual, 1) {
            let doDia = despesas
                .filter { calendario.component(.day, from: $0.data) == numero }
                .reduce(Decimal.zero) { $0 + $1.valor }
            acumulado += (doDia as NSDecimalNumber).doubleValue
            pontos.append(PontoDoRitmo(dia: numero, acumulado: acumulado))
        }
        pontos[pontos.count - 1] = PontoDoRitmo(dia: diaAtual, acumulado: (dia.gastoDoMes as NSDecimalNumber).doubleValue)
        return pontos
    }

    private func ritmoDoMes(_ dia: CalculadoraDoDia.Dia) -> some View {
        let pontos = pontosDoRitmo(dia)
        let orcamento = (rendimentoDoMes as NSDecimalNumber).doubleValue
        let gasto = pontos.last?.acumulado ?? 0
        let topo = max(orcamento, gasto, 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Ritmo do mês · dia \(diaAtual) de \(diasNoMes)")
                    .font(Tema.fonte(11))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
                Spacer(minLength: 0)
                legendaDoGrafico("Gasto", tracejado: false)
                legendaDoGrafico("Ideal", tracejado: true)
            }
            Chart {
                // A referência: gastar o rendimento a ritmo constante.
                ForEach([0, diasNoMes], id: \.self) { numero in
                    LineMark(
                        x: .value("Dia", numero),
                        y: .value("Ideal", orcamento * Double(numero) / Double(diasNoMes)),
                        series: .value("Série", "ideal")
                    )
                    .foregroundStyle(Tema.tintaSuave.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                // Linha mais fina e ponto mais pequeno — estava pesado.
                ForEach(pontos) { ponto in
                    LineMark(
                        x: .value("Dia", ponto.dia),
                        y: .value("Gasto", ponto.acumulado),
                        series: .value("Série", "gasto")
                    )
                    .foregroundStyle(Tema.douradoDaBarra)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
                // Onde estás hoje: no gasto acumulado real.
                PointMark(x: .value("Dia", diaAtual), y: .value("Gasto", gasto))
                    .foregroundStyle(Tema.douradoDaBarra)
                    .symbolSize(22)
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...diasNoMes)
            .chartYScale(domain: 0...(topo * 1.08))
            .frame(height: 72)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ritmo do mês, dia \(diaAtual) de \(diasNoMes)")
        .accessibilityValue("Gastaste \(FormatadorDeMoeda.falado(dia.gastoDoMes)); o ritmo ideal até hoje seria \(FormatadorDeMoeda.falado(Decimal(ritmoIdealDeHoje).arredondadoACentimos())). \(dentroDoLimite(dia) ? "No ritmo" : "Acima do ritmo").")
    }

    private func legendaDoGrafico(_ titulo: String, tracejado: Bool) -> some View {
        HStack(spacing: 4) {
            Path { caminho in
                caminho.move(to: CGPoint(x: 0, y: 1))
                caminho.addLine(to: CGPoint(x: 12, y: 1))
            }
            .stroke(
                tracejado ? AnyShapeStyle(Tema.tintaSuave.opacity(0.6)) : Tema.douradoDaBarra,
                style: StrokeStyle(lineWidth: tracejado ? 1.2 : 2.2, lineCap: .round, dash: tracejado ? [3, 3] : [])
            )
            .frame(width: 12, height: 2)
            Text(titulo)
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    // MARK: - Ações rápidas

    private var acoesRapidas: some View {
        // Três blocos de 48 pt (no mínimo — crescem com o Dynamic Type).
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
                        .textoDourado()
                } else {
                    IconeDeTexto(tamanho: 14)
                        .textoDourado()
                }
                Text(titulo)
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.tinta)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48)
            .cartao(raio: 16)
        }
    }

    // MARK: - Primeiros passos

    private var temRendimento: Bool {
        if case .calculado = resultado { return true }
        return false
    }

    private var temLimites: Bool {
        categorias.contains { ($0.orcamentoMensal ?? .zero) > .zero }
    }

    private var temRegisto: Bool { !transacoes.isEmpty }

    private var primeirosPassosFeitos: Bool { temRendimento && temLimites && temRegisto }

    /// Um mini-onboarding enquanto falta algum dos três passos: cada um
    /// mostra o estado real e leva ao sítio certo.
    @ViewBuilder
    private var primeirosPassos: some View {
        if !primeirosPassosFeitos {
            let feitos = [temRendimento, temLimites, temRegisto].filter { $0 }.count
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Primeiros passos")
                        .font(Tema.fonte(17, .semibold))
                        .foregroundStyle(Tema.tinta)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(feitos) de 3")
                        .font(Tema.fonte(12, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tintaSuave)
                }
                VStack(spacing: 0) {
                    passo(1, "Definir rendimento", "Quanto esperas receber este mês.", feito: temRendimento, acao: aoDefinirRendimento)
                    Rectangle().fill(Tema.separador).frame(height: 1).padding(.leading, 52)
                    passo(2, "Criar limites", "Um teto por categoria, como o supermercado.", feito: temLimites, acao: aoPlanear)
                    Rectangle().fill(Tema.separador).frame(height: 1).padding(.leading, 52)
                    passo(3, "Primeiro registo", "Escreve, fala ou fotografa um talão.", feito: temRegisto) { aoRegistar(.texto) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .cartao(raio: 20)
            }
        }
    }

    private func passo(_ numero: Int, _ titulo: String, _ texto: String, feito: Bool, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack(spacing: 14) {
                ZStack {
                    if feito {
                        Circle().fill(Tema.areia)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tema.ouro)
                    } else {
                        Circle().strokeBorder(Tema.separador, lineWidth: 1.5)
                        Text("\(numero)")
                            .font(Tema.fonte(13, .semibold))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(feito ? Tema.tintaSuave : Tema.tinta)
                    Text(texto)
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tema.tintaSuave)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(EscalaAoTocar())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passo \(numero) de 3: \(titulo)")
        .accessibilityValue(feito ? "Feito" : "Por fazer")
        .accessibilityHint(texto)
        .accessibilityAddTraits(.isButton)
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

                // Cada limite num cartão: ícone da categoria, nome, valores,
                // percentagem e barra — âmbar a partir de 75%, vermelha a 100%.
                VStack(spacing: 10) {
                    ForEach(linhas) { linha in
                        HStack(spacing: 12) {
                            IconeDeCategoria(categoria: linha.categoria, lado: 38)
                            VStack(alignment: .leading, spacing: 6) {
                                // Numa linha quando cabe; com letra grande, os
                                // valores descem para baixo do nome.
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        nomeDoLimite(linha)
                                        Spacer(minLength: 4)
                                        valoresDoLimite(linha)
                                        CapsulaDePercentagem(fracao: linha.fracao)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline) {
                                            nomeDoLimite(linha)
                                            Spacer(minLength: 4)
                                            CapsulaDePercentagem(fracao: linha.fracao)
                                        }
                                        valoresDoLimite(linha)
                                    }
                                }
                                BarraDeProgresso(fracao: linha.fracao, comEstado: true)
                            }
                        }
                        .padding(14)
                        .cartao(raio: 20)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(fraseDoLimite(linha))
                    }
                }
            }
        }
    }

    private func nomeDoLimite(_ linha: LinhaDeLimite) -> some View {
        Text(linha.categoria.nome)
            .font(Tema.fonte(14, .semibold))
            .foregroundStyle(Tema.tinta)
            .lineLimit(1)
    }

    /// "148,58 € de 160 €" — o mesmo formato do Planear.
    private func valoresDoLimite(_ linha: LinhaDeLimite) -> some View {
        Text("\(FormatadorDeMoeda.texto(linha.gasto)) de \(FormatadorDeMoeda.textoInteiroAgrupado(linha.orcamento)) €")
            .font(Tema.fonte(12))
            .monospacedDigit()
            .foregroundStyle(Tema.tintaSuave)
            .lineLimit(1)
            .fixedSize()
    }

    private func fraseDoLimite(_ linha: LinhaDeLimite) -> String {
        let percentagem = Int((linha.fracao * 100).rounded())
        let estado = linha.fracao >= 1 ? "Limite ultrapassado."
            : linha.fracao >= 0.75 ? "Perto do limite."
            : ""
        return "\(linha.categoria.nome): \(FormatadorDeMoeda.falado(linha.gasto)) de \(FormatadorDeMoeda.falado(linha.orcamento)), \(percentagem) por cento. \(estado)"
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

    @ViewBuilder
    private var ultimosMovimentos: some View {
        let visiveis = Array(transacoes.prefix(2))
        // Sem movimentos, o passo 3 dos primeiros passos já convida a
        // registar — não se repete o convite aqui.
        if !visiveis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TituloDeSeccao(titulo: "Últimos movimentos", acao: "Ver todos") { aoVerTudo() }
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
