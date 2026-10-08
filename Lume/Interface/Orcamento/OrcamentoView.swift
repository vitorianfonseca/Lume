import SwiftUI
import SwiftData

/// O Planear do Figma (ecrãs 08 e 09): dois segmentos — Orçamentos,
/// com o orçamento do mês e os limites por categoria; e Objetivos, com o
/// total reservado e os planos de poupança. O título é sempre "Planear":
/// é o seletor que diz onde se está.
struct OrcamentoView: View {
    private enum Segmento: String, CaseIterable {
        case orcamentos = "Orçamentos"
        case objetivos = "Objetivos"
    }

    @Environment(\.modelContext) private var contexto
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var transacoes: [Transacao]
    @Query(sort: \Meta.nome) private var metas: [Meta]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]

    @State private var segmento: Segmento
    /// A mesma conta do Resumo: gasto, reservado e disponível batem certo.
    @State private var calculoDoDia = HojeViewModel()
    @State private var mostrarSegundaOpiniao = false

    /// O arranque nos Objetivos serve as pré-visualizações.
    init(mostrarObjetivos: Bool = false) {
        self.segmento = mostrarObjetivos ? .objetivos : .orcamentos
    }
    @State private var mostrarEditarLimites = false
    @State private var mostrarDivisao = false
    @State private var mostrarNovoObjetivo = false
    @State private var metaEmDetalhe: Meta?
    @State private var metaAReforcar: Meta?
    @State private var mostrarMesesAnteriores = false
    @State private var categoriaEmDetalhe: Categoria?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CabecalhoDeEcra(
                    legenda: Date.now.formatted(.dateTime.month(.wide).year().locale(FormatadorDeMoeda.localidade)),
                    titulo: "Planear"
                )

                SeletorSegmentado(
                    opcoes: Segmento.allCases,
                    escolhida: $segmento,
                    titulo: \.rawValue
                )

                // O conteúdo desliza ao trocar de segmento (transição curta).
                Group {
                    switch segmento {
                    case .orcamentos: orcamentos
                    case .objetivos: objetivos
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: segmento == .objetivos ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .sheet(isPresented: $mostrarDivisao) {
            DividirRendimentoView(valor: rendimentoDoMes)
        }
        .sheet(isPresented: $mostrarEditarLimites) {
            EditarLimitesView(categorias: categorias)
        }
        .sheet(isPresented: $mostrarNovoObjetivo) {
            FormularioDeObjetivo(meta: nil)
        }
        .sheet(item: $metaEmDetalhe) { meta in
            DetalheDoObjetivo(meta: meta, poupancaPorObjetivo: poupancaPorObjetivo)
        }
        .sheet(item: $metaAReforcar) { meta in
            ReforcoDeObjetivo(meta: meta)
        }
        .sheet(isPresented: $mostrarMesesAnteriores) {
            MesesAnterioresView()
        }
        .sheet(item: $categoriaEmDetalhe) { categoria in
            DetalheDoLimiteView(categoria: categoria, transacoes: transacoes)
        }
        .sheet(isPresented: $mostrarSegundaOpiniao) {
            if let dia {
                // O mesmo "disponível" do Resumo e do Planear.
                SegundaOpiniaoView(
                    disponivelDoMes: dia.disponivelAgora,
                    diasRestantes: dia.diasRestantes
                )
            } else {
                SegundaOpiniaoView(disponivelDoMes: .zero, diasRestantes: 1)
            }
        }
    }

    // MARK: - A conta do mês (partilhada com o Resumo)

    /// O dia calculado pela mesma ponte do Resumo; `nil` sem rendimento.
    private var dia: CalculadoraDoDia.Dia? {
        let resultado = calculoDoDia.resultadoDoDia(
            transacoes: transacoes,
            recorrentes: recorrentes,
            definicoes: definicoes
        )
        if case .calculado(let dia) = resultado { return dia }
        return nil
    }

    private var definicoesDoMes: DefinicoesDoMes? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }
    }

    private var rendimentoDoMes: Decimal {
        definicoesDoMes?.rendimentoEsperado ?? .zero
    }

    /// Onde o mês vai (0…1), para o traço "hoje" na barra.
    private var fracaoDoMes: Double {
        let calendario = Calendar.current
        let dias = calendario.range(of: .day, in: .month, for: .now)?.count ?? 30
        return Double(calendario.component(.day, from: .now)) / Double(dias)
    }

    private var nomeDoMes: String {
        Date.now.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).lowercased()
    }

    private var gastoDoMesTotal: Decimal {
        let calendario = Calendar.current
        return transacoes
            .filter { $0.tipo == .despesa && calendario.isDate($0.data, equalTo: .now, toGranularity: .month) }
            .reduce(.zero) { $0 + $1.valor }
    }

    private var comOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal != nil } }

    // MARK: - Orçamentos (ecrã 08)

    @ViewBuilder
    private var orcamentos: some View {
        cartaoDoMes

        // As duas ações de apoio: um só estilo, lado a lado.
        HStack(spacing: 10) {
            BotaoLume(titulo: "Dividir rendimento", simbolo: "chart.pie.fill", estilo: .secundario) {
                mostrarDivisao = true
            }
            BotaoLume(titulo: "Vale a pena?", simbolo: "sparkle.magnifyingglass", estilo: .secundario) {
                mostrarSegundaOpiniao = true
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)

        if comOrcamento.isEmpty {
            EstadoVazio(
                ilustracao: .graficos,
                titulo: "Sem limites definidos",
                texto: "Toca em \"Editar limites\" para distribuir o orçamento pelas categorias."
            )
        } else {
            TituloDeSeccao(titulo: "Limites por categoria")
                .padding(.top, 6)

            // Uma só lista agrupada, como no Perfil: linhas separadas por filetes.
            VStack(spacing: 0) {
                ForEach(comOrcamento) { categoria in
                    Button { categoriaEmDetalhe = categoria } label: {
                        LinhaDeOrcamento(categoria: categoria, gasto: gastoDoMes(em: categoria))
                    }
                    .buttonStyle(.plain)
                    if categoria.persistentModelID != comOrcamento.last?.persistentModelID {
                        Divider().overlay(Tema.separador)
                            .padding(.leading, 50)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .cartao()
        }

        insights

        Button { mostrarMesesAnteriores = true } label: {
            HStack {
                Text("Meses anteriores")
                    .font(Tema.fonte(15, .medium))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tema.placeholder)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .cartao()
        }
        .buttonStyle(.plain)
    }

    /// O cartão do mês: rótulo, orçamento, barra com o traço de hoje e a
    /// conta à vista — gasto + reservado + disponível = orçamento.
    private var cartaoDoMes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Legenda("Orçamento de \(nomeDoMes)")
                Spacer()
                Button("Editar limites") { mostrarEditarLimites = true }
                    .font(Tema.fonte(12, .medium))
                    .textoDourado()
            }

            HStack(alignment: .center) {
                ValorEmEuros(valor: rendimentoDoMes, tamanho: 36)
                Spacer(minLength: 8)
                Ilustracao(tipo: .graficos, escala: 0.42)
            }

            if let dia {
                BarraDeProgresso(fracao: fracao(dia.gastoDoMes, de: rendimentoDoMes), comEstado: true, marcador: fracaoDoMes)
                    .padding(.vertical, 3)

                Text(resumoDeUtilizacao(dia))
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)

                Divider().overlay(Tema.separador)
                    .padding(.vertical, 2)

                HStack(alignment: .top, spacing: 8) {
                    parcela("Gasto", dia.gastoDoMes)
                    parcela("Reservado", dia.reservado)
                    parcela(
                        "Disponível",
                        dia.disponivelAgora,
                        cor: dia.disponivelAgora < .zero ? Tema.negativo : Tema.tinta
                    )
                }
            } else {
                BarraDeProgresso(fracao: 0)
                Text("Define o orçamento do mês em \"Editar limites\".")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    private func parcela(_ titulo: String, _ valor: Decimal, cor: Color = Tema.tinta) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
            Text(FormatadorDeMoeda.texto(valor))
                .font(Tema.fonte(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(cor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo): \(FormatadorDeMoeda.falado(valor))")
    }

    private func resumoDeUtilizacao(_ dia: CalculadoraDoDia.Dia) -> String {
        let calendario = Calendar.current
        let dias = calendario.range(of: .day, in: .month, for: .now)?.count ?? 30
        let hoje = calendario.component(.day, from: .now)
        let percentagem = Int((fracao(dia.gastoDoMes, de: rendimentoDoMes) * 100).rounded())
        return "\(percentagem)% gasto · hoje é dia \(hoje) de \(dias)"
    }

    private func fracao(_ parte: Decimal, de todo: Decimal) -> Double {
        guard todo > .zero else { return 0 }
        return (parte as NSDecimalNumber).doubleValue / (todo as NSDecimalNumber).doubleValue
    }

    // MARK: - Insights (contas feitas pela app, sem IA)

    /// Gasto do mês passado até ao mesmo dia — comparação justa.
    private var gastoDoMesPassadoAteHoje: Decimal {
        let calendario = Calendar.current
        guard let mesPassado = calendario.date(byAdding: .month, value: -1, to: .now) else { return .zero }
        let diaDeHoje = calendario.component(.day, from: .now)
        return transacoes
            .filter {
                $0.tipo == .despesa
                    && calendario.isDate($0.data, equalTo: mesPassado, toGranularity: .month)
                    && calendario.component(.day, from: $0.data) <= diaDeHoje
            }
            .reduce(.zero) { $0 + $1.valor }
    }

    /// A categoria que mais cresceu face ao mês passado (mesmo dia a dia).
    private var categoriaQueMaisCresce: (nome: String, diferenca: Decimal)? {
        let calendario = Calendar.current
        guard let mesPassado = calendario.date(byAdding: .month, value: -1, to: .now) else { return nil }
        let diaDeHoje = calendario.component(.day, from: .now)

        let crescimentos = categorias.compactMap { categoria -> (String, Decimal)? in
            let agora = gastoDoMes(em: categoria)
            let antes = transacoes
                .filter {
                    $0.tipo == .despesa
                        && $0.categoria?.persistentModelID == categoria.persistentModelID
                        && calendario.isDate($0.data, equalTo: mesPassado, toGranularity: .month)
                        && calendario.component(.day, from: $0.data) <= diaDeHoje
                }
                .reduce(Decimal.zero) { $0 + $1.valor }
            let diferenca = agora - antes
            return diferenca > .zero ? (categoria.nome, diferenca) : nil
        }
        guard let maior = crescimentos.max(by: { $0.1 < $1.1 }) else { return nil }
        return (maior.0, maior.1)
    }

    /// Média diária dos últimos 7 dias.
    private var mediaDosUltimosSeteDias: Decimal {
        let calendario = Calendar.current
        guard let inicio = calendario.date(byAdding: .day, value: -6, to: calendario.startOfDay(for: .now)) else { return .zero }
        let total = transacoes
            .filter { $0.tipo == .despesa && $0.data >= inicio }
            .reduce(Decimal.zero) { $0 + $1.valor }
        return (total / 7).arredondadoACentimos()
    }

    /// O cartão de tendências: comparações deterministas, no tom da Lume.
    @ViewBuilder
    private var insights: some View {
        let atual = gastoDoMesTotal
        let passado = gastoDoMesPassadoAteHoje

        if passado > .zero || atual > .zero {
            VStack(alignment: .leading, spacing: 8) {
                Legenda("Tendências")

                if passado > .zero {
                    let diferenca = atual - passado
                    Text(diferenca <= .zero
                        ? "Levas menos \(FormatadorDeMoeda.texto(-diferenca)) do que no mês passado por esta altura."
                        : "Levas mais \(FormatadorDeMoeda.texto(diferenca)) do que no mês passado por esta altura.")
                        .font(Tema.fonte(13))
                        .foregroundStyle(diferenca <= .zero ? Tema.positivo : Tema.tinta)
                }

                if let crescimento = categoriaQueMaisCresce {
                    Text("\(crescimento.nome) é onde mais cresces: +\(FormatadorDeMoeda.texto(crescimento.diferenca)).")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }

                Text("Nos últimos 7 dias gastaste em média \(FormatadorDeMoeda.texto(mediaDosUltimosSeteDias)) por dia.")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cartao(Tema.bege)
            .accessibilityElement(children: .combine)
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
            .reduce(.zero) { $0 + $1.valor }
    }

    // MARK: - Objetivos (ecrã 09)

    private var totalReservado: Decimal {
        metas.reduce(.zero) { $0 + $1.valorPoupado }
    }

    /// A parte da poupança planeada do mês que cabe a cada objetivo ainda
    /// por cumprir (dividida em partes iguais) — a base do "no ritmo".
    private var poupancaPorObjetivo: Decimal {
        let porCumprir = metas.filter { $0.valorPoupado < $0.valorAlvo }.count
        guard porCumprir > 0 else { return .zero }
        return (definicoesDoMes?.poupancaPlaneada ?? .zero) / Decimal(porCumprir)
    }

    @ViewBuilder
    private var objetivos: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Legenda("Já reservaste")
                ValorEmEuros(valor: totalReservado, tamanho: 35, peso: .medium)
                Text(metas.count == 1 ? "para o teu objetivo" : "para os teus \(metas.count) objetivos")
                    .font(Tema.fonte(12, .medium))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Com objetivos, o frasco acompanha o total; sem eles, aparece
            // em grande no estado vazio mais abaixo.
            if !metas.isEmpty {
                Ilustracao(tipo: .frasco, escala: 0.5)
            }
        }
        .padding(20)
        .cartaoCafe()

        if metas.isEmpty {
            EstadoVazio(
                ilustracao: .frasco,
                titulo: "Ainda sem objetivos",
                texto: "Uma viagem, um fundo de emergência, um portátil novo. Começa por um pequeno."
            )
        }

        ForEach(metas) { meta in
            CartaoDeObjetivo(
                meta: meta,
                ritmo: RitmoDoObjetivo(meta: meta, poupancaPorObjetivo: poupancaPorObjetivo),
                aoAbrir: { metaEmDetalhe = meta },
                aoReforcar: { metaAReforcar = meta }
            )
            // Um objetivo novo cresce para o lugar; um eliminado encolhe.
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .animation(.snappy, value: metas.count)

        BotaoLume(titulo: "Criar novo objetivo", simbolo: "plus") {
            mostrarNovoObjetivo = true
        }
        .padding(.top, 4)
    }
}

// MARK: - Ritmo de um objetivo

/// Prazo e ritmo de um objetivo: quanto falta, quanto é preciso por mês
/// até ao prazo e se se está no ritmo.
///
/// Regra do estado: o `Meta` não guarda a data de início nem o histórico
/// de reforços, por isso não dá para comparar com uma linha reta desde o
/// início. Em vez disso, compara-se o que é preciso por mês até ao prazo
/// com a parte da poupança planeada do mês que cabe a este objetivo
/// (a poupança dividida pelos objetivos por cumprir). Se chega, está
/// "no ritmo"; se não chega (ou o prazo já passou), está "atrasado".
private struct RitmoDoObjetivo {
    enum Estado {
        case concluido, noRitmo, atrasado, semPrazo

        var titulo: String {
            switch self {
            case .concluido: "Concluído"
            case .noRitmo: "No ritmo"
            case .atrasado: "Atrasado"
            case .semPrazo: "Sem prazo"
            }
        }
    }

    let falta: Decimal
    /// Meses até ao prazo, contando o atual (pelo menos 1).
    let meses: Int?
    let porMes: Decimal?
    let prazo: Date?
    let estado: Estado

    init(meta: Meta, poupancaPorObjetivo: Decimal, hoje: Date = .now, calendario: Calendar = .current) {
        let falta = max(meta.valorAlvo - meta.valorPoupado, .zero)
        self.falta = falta
        prazo = meta.dataLimite
        var meses: Int?
        if let prazo = meta.dataLimite {
            let inicio = calendario.dateInterval(of: .month, for: hoje)?.start ?? hoje
            let diferenca = calendario.dateComponents([.month], from: inicio, to: prazo).month ?? 0
            meses = max(diferenca + 1, 1)
        }
        self.meses = meses
        let porMes = meses.map { AjusteDaDivisao.arredondarParaCima(falta / Decimal($0)) }
        self.porMes = porMes

        if falta <= .zero {
            estado = .concluido
        } else if let prazo, let porMes {
            estado = prazo < hoje || porMes > poupancaPorObjetivo ? .atrasado : .noRitmo
        } else {
            estado = .semPrazo
        }
    }

    /// "Faltam 2 150 € · 179 €/mês até dez. 2027".
    var frase: String {
        guard falta > .zero else { return "Objetivo cumprido" }
        let faltam = "Faltam \(FormatadorDeMoeda.textoInteiroAgrupado(AjusteDaDivisao.arredondarParaCima(falta))) €"
        guard let porMes, let prazo else { return faltam + " · sem prazo" }
        return "\(faltam) · \(FormatadorDeMoeda.textoInteiroAgrupado(porMes)) €/mês até \(Self.mesCurto(prazo))"
    }

    /// "dez. 2027".
    static func mesCurto(_ data: Date) -> String {
        let mes = data.formatted(.dateTime.month(.abbreviated).locale(FormatadorDeMoeda.localidade))
        let ano = Calendar.current.component(.year, from: data)
        return "\(mes) \(ano)"
    }
}

/// O selo do estado: neutro quando corre bem, âmbar quando está atrasado.
private struct SeloDeRitmo: View {
    let estado: RitmoDoObjetivo.Estado

    var body: some View {
        let (texto, fundo): (Color, Color) = estado == .atrasado
            ? (Tema.aviso, Tema.fundoDoAviso)
            : (Tema.tintaSuave, Tema.bege)
        Text(estado.titulo)
            .font(Tema.fonte(11, .semibold))
            .foregroundStyle(texto)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(fundo, in: Capsule())
    }
}

/// O cartão de objetivo: ícone 3D, nome e estado; o valor com cêntimos
/// pequenos, a barra, o prazo e o ritmo; e "+ Reforçar".
private struct CartaoDeObjetivo: View {
    let meta: Meta
    let ritmo: RitmoDoObjetivo
    let aoAbrir: () -> Void
    let aoReforcar: () -> Void

    private var fracao: Double {
        guard meta.valorAlvo > .zero else { return 0 }
        return (meta.valorPoupado as NSDecimalNumber).doubleValue / (meta.valorAlvo as NSDecimalNumber).doubleValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tocar no cartão abre o detalhe.
            Button(action: aoAbrir) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        IconeDourado(simbolo: meta.simbolo, lado: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meta.nome)
                                .font(Tema.fonte(16, .semibold))
                                .foregroundStyle(Tema.tinta)
                            if let descricao = meta.descricao, !descricao.isEmpty {
                                Text(descricao)
                                    .font(Tema.fonte(12))
                                    .foregroundStyle(Tema.tintaSuave)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        // "Sem prazo" já se lê na frase do ritmo.
                        if ritmo.estado != .semPrazo {
                            SeloDeRitmo(estado: ritmo.estado)
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        ValorEmEuros(valor: meta.valorPoupado, tamanho: 24, peso: .medium)
                        Spacer()
                        Text("de \(FormatadorDeMoeda.texto(meta.valorAlvo))")
                            .font(Tema.fonte(12))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tintaSuave)
                    }

                    BarraDeProgresso(fracao: fracao)

                    Text(ritmo.frase)
                        .font(Tema.fonte(12))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Abre o detalhe do objetivo")

            HStack {
                Text("\(Int((fracao * 100).rounded()))% concluído")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                // Botão pequeno, com o "+" à esquerda.
                Button(action: aoReforcar) {
                    Label("Reforçar", systemImage: "plus")
                        .font(Tema.fonte(13, .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                }
                .buttonStyle(EstiloDeBotaoLume(estilo: .secundario))
                .accessibilityLabel("Reforçar \(meta.nome)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }
}

/// O detalhe de um objetivo: o progresso, o prazo, o ritmo e as ações.
private struct DetalheDoObjetivo: View {
    @Environment(\.dismiss) private var dismiss

    let meta: Meta
    let poupancaPorObjetivo: Decimal

    @Query(sort: \ReforcoDaMeta.data, order: .reverse) private var todosOsReforcos: [ReforcoDaMeta]

    @State private var aReforcar = false
    @State private var aEditar = false

    /// Só os reforços deste objetivo — filtrado aqui porque o predicado do
    /// `@Query` não consegue capturar a instância de `meta`.
    private var reforcos: [ReforcoDaMeta] {
        todosOsReforcos.filter { $0.meta?.persistentModelID == meta.persistentModelID }
    }

    private var ritmo: RitmoDoObjetivo {
        RitmoDoObjetivo(meta: meta, poupancaPorObjetivo: poupancaPorObjetivo)
    }

    private var fracao: Double {
        guard meta.valorAlvo > .zero else { return 0 }
        return (meta.valorPoupado as NSDecimalNumber).doubleValue / (meta.valorAlvo as NSDecimalNumber).doubleValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(legenda: "Objetivo", titulo: meta.nome, aoVoltar: { dismiss() }, simboloDeVoltar: "xmark")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Legenda("Já guardaste")
                            ValorEmEuros(valor: meta.valorPoupado, tamanho: 34, peso: .medium)
                            Text("de \(FormatadorDeMoeda.texto(meta.valorAlvo))")
                                .font(Tema.fonte(13))
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        Spacer()
                        IconeDourado(simbolo: meta.simbolo, lado: 56)
                    }
                    BarraDeProgresso(fracao: fracao)
                    HStack {
                        Text("\(Int((fracao * 100).rounded()))% concluído")
                            .font(Tema.fonte(12))
                            .foregroundStyle(Tema.tintaSuave)
                        Spacer()
                        SeloDeRitmo(estado: ritmo.estado)
                    }
                }
                .padding(20)
                .cartao()

                VStack(spacing: 0) {
                    linha("Falta", FormatadorDeMoeda.texto(ritmo.falta))
                    Divider().overlay(Tema.separador)
                    linha("Prazo", meta.dataLimite.map {
                        $0.formatted(.dateTime.day().month(.wide).year().locale(FormatadorDeMoeda.localidade))
                    } ?? "Sem prazo")
                    if let porMes = ritmo.porMes, let meses = ritmo.meses {
                        Divider().overlay(Tema.separador)
                        linha("Por mês", "\(FormatadorDeMoeda.texto(porMes)) · \(meses) \(meses == 1 ? "mês" : "meses")")
                        Divider().overlay(Tema.separador)
                        linha("Poupança do mês para este objetivo", FormatadorDeMoeda.texto(poupancaPorObjetivo.arredondadoACentimos()))
                    }
                }
                .padding(.horizontal, 16)
                .cartao()

                if !reforcos.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Legenda("Histórico de reforços")
                            .padding(.top, 14)
                        ForEach(reforcos) { reforco in
                            HStack(alignment: .firstTextBaseline) {
                                Text(reforco.data.formatted(
                                    .dateTime.day().month(.wide).locale(FormatadorDeMoeda.localidade)
                                ))
                                .font(Tema.fonte(14))
                                .foregroundStyle(Tema.tintaSuave)
                                Spacer(minLength: 12)
                                Text("+\(FormatadorDeMoeda.texto(reforco.valor))")
                                    .font(Tema.fonte(14, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Tema.positivo)
                            }
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                            if reforco.persistentModelID != reforcos.last?.persistentModelID {
                                Divider().overlay(Tema.separador)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .cartao()
                }

                if let descricao = meta.descricao, !descricao.isEmpty {
                    Text(descricao)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }

                Text(explicacao)
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    BotaoLume(titulo: "Reforçar objetivo", simbolo: "plus") { aReforcar = true }
                    BotaoLume(titulo: "Editar objetivo", simbolo: "pencil", estilo: .secundario) { aEditar = true }
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $aReforcar) {
            ReforcoDeObjetivo(meta: meta)
        }
        .sheet(isPresented: $aEditar) {
            // Se o objetivo for eliminado, o detalhe fecha também.
            FormularioDeObjetivo(meta: meta, aoEliminar: { dismiss() })
        }
    }

    private var explicacao: String {
        switch ritmo.estado {
        case .concluido: "Chegaste ao valor. Podes manter o objetivo ou criar um novo."
        case .noRitmo: "A poupança planeada para este mês chega para o ritmo que o prazo pede."
        case .atrasado: "A poupança planeada não chega para o prazo. Reforça, aumenta a poupança do mês ou adia a data."
        case .semPrazo: "Define uma data para a Lume calcular quanto precisas de guardar por mês."
        }
    }

    private func linha(_ rotulo: String, _ valor: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(rotulo)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tintaSuave)
            Spacer(minLength: 12)
            Text(valor)
                .font(Tema.fonte(14, .medium))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// Linha de limite na lista agrupada: ícone, nome e percentagem, barra com
/// cor de estado, "148,58 € de 160 €" e o que sobra — ou "Passaste X €".
private struct LinhaDeOrcamento: View {
    let categoria: Categoria
    let gasto: Decimal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconeDeCategoria(categoria: categoria, lado: 38)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center) {
                    Text(categoria.nome)
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Spacer()
                    CapsulaDePercentagem(fracao: fracao)
                }
                BarraDeProgresso(fracao: fracao, comEstado: true)
                HStack {
                    // O formato partilhado com o Resumo.
                    Text(FormatadorDeMoeda.texto(gasto) + " de " + FormatadorDeMoeda.textoInteiroAgrupado(orcamento) + " €")
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                    Spacer()
                    Text(legendaDisponivel)
                        .monospacedDigit()
                        .fontWeight(ultrapassado ? .semibold : .regular)
                        .foregroundStyle(ultrapassado ? Tema.negativo : Tema.tintaSuave)
                }
                .font(Tema.fonte(11))
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(categoria.nome): \(FormatadorDeMoeda.texto(gasto)) de \(FormatadorDeMoeda.texto(orcamento)). \(legendaDisponivel)")
    }

    private var orcamento: Decimal { categoria.orcamentoMensal ?? .zero }

    private var ultrapassado: Bool { orcamento > .zero && gasto > orcamento }

    private var fracao: Double {
        guard orcamento > .zero else { return 0 }
        return (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
    }

    private var legendaDisponivel: String {
        let restante = orcamento - gasto
        guard restante >= .zero else {
            return "Passaste \(FormatadorDeMoeda.texto(-restante))"
        }
        return "\(FormatadorDeMoeda.texto(restante)) disponíveis"
    }
}

/// O detalhe de um limite: o mesmo resumo da linha, maior, e os movimentos
/// do mês nesta categoria — para perceber de onde vem o número, não só vê-lo.
private struct DetalheDoLimiteView: View {
    @Environment(\.dismiss) private var dismiss
    let categoria: Categoria
    let transacoes: [Transacao]

    private var movimentosDoMes: [Transacao] {
        let calendario = Calendar.current
        return transacoes
            .filter {
                $0.tipo == .despesa
                    && $0.categoria?.persistentModelID == categoria.persistentModelID
                    && calendario.isDate($0.data, equalTo: .now, toGranularity: .month)
            }
            .sorted { $0.data > $1.data }
    }

    private var gasto: Decimal { movimentosDoMes.reduce(.zero) { $0 + $1.valor } }
    private var orcamento: Decimal { categoria.orcamentoMensal ?? .zero }

    private var fracao: Double {
        guard orcamento > .zero else { return 0 }
        return (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
    }

    private var legendaDisponivel: String {
        let restante = orcamento - gasto
        guard restante >= .zero else { return "Passaste \(FormatadorDeMoeda.texto(-restante))" }
        return "\(FormatadorDeMoeda.texto(restante)) disponíveis"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(legenda: "Limite por categoria", titulo: categoria.nome, aoVoltar: { dismiss() }, simboloDeVoltar: "xmark")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        IconeDeCategoria(categoria: categoria, lado: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            ValorEmEuros(valor: gasto, tamanho: 26)
                            Text("de \(FormatadorDeMoeda.texto(orcamento)) este mês")
                                .font(Tema.fonte(12))
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        Spacer()
                        CapsulaDePercentagem(fracao: fracao)
                    }
                    BarraDeProgresso(fracao: fracao, comEstado: true)
                    Text(legendaDisponivel)
                        .font(Tema.fonte(13, .medium))
                        .foregroundStyle(orcamento > .zero && gasto > orcamento ? Tema.negativo : Tema.tintaSuave)
                }
                .padding(20)
                .cartao()

                if movimentosDoMes.isEmpty {
                    EstadoVazio(
                        ilustracao: .lupa,
                        titulo: "Sem movimentos",
                        texto: "Ainda não há despesas em \(categoria.nome) este mês."
                    )
                } else {
                    TituloDeSeccao(titulo: "Movimentos do mês")
                    VStack(spacing: 0) {
                        ForEach(movimentosDoMes) { transacao in
                            LinhaDeTransacao(transacao: transacao, estilo: .extrato)
                            if transacao.persistentModelID != movimentosDoMes.last?.persistentModelID {
                                Divider().overlay(Tema.separador)
                                    .padding(.leading, 50)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .cartao()
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
    }
}

/// O ecrã 12: orçamento mensal em destaque e um campo por categoria.
private struct EditarLimitesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Query private var definicoes: [DefinicoesDoMes]

    let categorias: [Categoria]

    /// 0 = mês atual; recuar 1 para corrigir, avançar até 6 para planear.
    @State private var deslocacaoDeMes = 0

    private var dataSelecionada: Date {
        Calendar.current.date(byAdding: .month, value: deslocacaoDeMes, to: .now) ?? .now
    }

    private var definicoesDoMes: DefinicoesDoMes? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: dataSelecionada)
        let mes = calendario.component(.month, from: dataSelecionada)
        return definicoes.first { $0.ano == ano && $0.mes == mes }
    }

    /// Sem `@Attribute(.unique)` (CloudKit), a unicidade é garantida aqui:
    /// procurar antes de inserir.
    private func garantirDefinicoes() {
        guard definicoesDoMes == nil else { return }
        let calendario = Calendar.current
        contexto.insert(DefinicoesDoMes(
            ano: calendario.component(.year, from: dataSelecionada),
            mes: calendario.component(.month, from: dataSelecionada)
        ))
        try? contexto.save()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: dataSelecionada.formatted(.dateTime.month(.wide).year().locale(FormatadorDeMoeda.localidade)),
                    titulo: "Editar limites",
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                // Setas para corrigir o mês anterior ou planear os próximos.
                HStack {
                    Button { deslocacaoDeMes -= 1 } label: { Image(systemName: "chevron.left") }
                        .disabled(deslocacaoDeMes <= -1)
                        .accessibilityLabel("Mês anterior")
                    Spacer()
                    Text(deslocacaoDeMes == 0 ? "Este mês" : dataSelecionada.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).capitalized)
                        .font(Tema.fonte(15, .medium))
                        .foregroundStyle(Tema.tinta)
                    Spacer()
                    Button { deslocacaoDeMes += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(deslocacaoDeMes >= 6)
                        .accessibilityLabel("Mês seguinte")
                }
                .buttonStyle(.borderless)
                .textoDourado()

                if let selecionadas = definicoesDoMes {
                    cartaoDoOrcamento(selecionadas)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(categorias) { categoria in
                        linhaDeCategoria(categoria)
                        if categoria.persistentModelID != categorias.last?.persistentModelID {
                            Divider().overlay(Tema.separador)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .cartao()

                BotaoLume(titulo: "Guardar limites", simbolo: "checkmark") {
                    try? contexto.save()
                    dismiss()
                }

                Text("Os movimentos existentes mantêm-se no teu histórico.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .presentationDragIndicator(.visible)
        .onAppear { garantirDefinicoes() }
        .onChange(of: deslocacaoDeMes) { garantirDefinicoes() }
    }

    private func cartaoDoOrcamento(_ selecionadas: DefinicoesDoMes) -> some View {
        @Bindable var selecionadas = selecionadas
        return VStack(alignment: .leading, spacing: 8) {
            Legenda("Orçamento mensal")
            TextField(value: $selecionadas.rendimentoEsperado, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                Text("Orçamento mensal")
            }
            .keyboardType(.decimalPad)
            .font(Tema.fonte(31, .medium))
            .monospacedDigit()
            .foregroundStyle(Tema.tinta)
            HStack {
                Text("Poupança planeada")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                CampoDeEuros(valor: $selecionadas.poupancaPlaneada, tamanho: 14)
            }
            Text("Distribui o valor pelas tuas categorias.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cartaoCafe()
    }

    private func linhaDeCategoria(_ categoria: Categoria) -> some View {
        @Bindable var categoria = categoria
        return HStack(spacing: 12) {
            IconeDeCategoria(categoria: categoria, lado: 32)
            Text(categoria.nome)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
            Spacer()
            CampoDeEuros(
                valor: Binding(
                    get: { categoria.orcamentoMensal ?? .zero },
                    set: { categoria.orcamentoMensal = $0 > .zero ? $0 : nil }
                )
            )
        }
        .padding(.vertical, 8)
    }
}

/// O ecrã 10: criar (ou editar) um objetivo de poupança.
private struct FormularioDeObjetivo: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let meta: Meta?
    /// Para quem abriu o formulário (o detalhe) fechar também.
    var aoEliminar: (() -> Void)?

    @State private var nome: String
    @State private var descricao: String
    @State private var valorAlvo: Decimal
    @State private var valorInicial: Decimal
    @State private var temPrazo: Bool
    @State private var prazo: Date
    @State private var simbolo: String

    private static let simbolos = [
        "target", "airplane", "house.fill", "car.fill", "gift.fill",
        "graduationcap.fill", "heart.fill", "banknote.fill",
    ]

    init(meta: Meta?, aoEliminar: (() -> Void)? = nil) {
        self.meta = meta
        self.aoEliminar = aoEliminar
        self.nome = meta?.nome ?? ""
        self.descricao = meta?.descricao ?? ""
        self.valorAlvo = meta?.valorAlvo ?? .zero
        self.valorInicial = meta?.valorPoupado ?? .zero
        self.temPrazo = meta?.dataLimite != nil
        self.prazo = meta?.dataLimite
            ?? Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
        self.simbolo = meta?.simbolo ?? "target"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: "Objetivos",
                    titulo: meta == nil ? "Um novo objetivo" : "Editar objetivo",
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                if meta == nil {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            IconeDourado(simbolo: simbolo, lado: 34)
                            Text("O próximo passo começa aqui.")
                                .font(Tema.fonte(17, .semibold))
                                .foregroundStyle(Tema.tinta)
                        }
                        Text("Define um valor e uma data. A Lume ajuda-te a acompanhar o caminho.")
                            .font(Tema.fonte(13))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .cartaoCafe()
                }

                // Os campos vivem num cartão branco, como no frame.
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Legenda("Ícone")
                        HStack(spacing: 6) {
                            ForEach(Self.simbolos, id: \.self) { nome in
                                Button { simbolo = nome } label: {
                                    IconeDourado(simbolo: nome, lado: 26)
                                        .padding(3)
                                        .background(
                                            Circle().fill(nome == simbolo ? Tema.areia : .clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    campo("Nome do objetivo") {
                        TextField(text: $nome, prompt: Text("Ex.: próxima viagem").foregroundStyle(Tema.placeholder)) {
                            Text("Nome do objetivo")
                        }
                    }
                    campo("Para que serve? (opcional)") {
                        TextField(text: $descricao, prompt: Text("Ex.: um plano para dezembro").foregroundStyle(Tema.placeholder)) {
                            Text("Para que serve")
                        }
                    }
                    campo("Quanto queres juntar?") {
                        TextField(value: $valorAlvo, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                            Text("Valor do objetivo")
                        }
                        .keyboardType(.decimalPad)
                    }
                    campo("Até quando?") {
                        HStack {
                            Toggle("Com prazo", isOn: $temPrazo)
                                .labelsHidden()
                                .tint(Tema.dourado)
                                .scaleEffect(0.8, anchor: .leading)
                            if temPrazo {
                                DatePicker("Prazo", selection: $prazo, displayedComponents: .date)
                                    .labelsHidden()
                                    .environment(\.locale, FormatadorDeMoeda.localidade)
                            } else {
                                Text("Sem data definida")
                                    .font(Tema.fonte(16, .medium))
                                    .foregroundStyle(Tema.tintaSuave)
                            }
                        }
                    }
                    campo("Valor inicial") {
                        TextField(value: $valorInicial, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                            Text("Valor inicial")
                        }
                        .keyboardType(.decimalPad)
                    }
                }
                .padding(20)
                .cartao()

                BotaoLume(
                    titulo: meta == nil ? "Criar objetivo" : "Guardar alterações",
                    simbolo: meta == nil ? "plus" : "checkmark"
                ) {
                    guardar()
                }
                .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty || valorAlvo <= .zero)

                Text("Podes alterar o valor ou a data a qualquer momento.")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let meta {
                    BotaoLume(titulo: "Eliminar objetivo", simbolo: "trash", estilo: .destrutivo) {
                        contexto.delete(meta)
                        try? contexto.save()
                        dismiss()
                        aoEliminar?()
                    }
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .presentationDragIndicator(.visible)
    }

    /// Campo do frame: legenda pequena e caixa de 43 pt (raio 12)
    /// com o texto 16 Medium.
    private func campo(_ legenda: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Legenda(legenda)
            HStack {
                conteudo()
                    .font(Tema.fonte(16, .medium))
                    .foregroundStyle(Tema.tinta)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .frame(height: 43)
            .background(Tema.fundo, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Tema.separador, lineWidth: 1)
            )
        }
    }

    private func guardar() {
        if let meta {
            meta.nome = nome
            meta.descricao = descricao.isEmpty ? nil : descricao
            meta.valorAlvo = valorAlvo
            meta.valorPoupado = valorInicial
            meta.dataLimite = temPrazo ? prazo : nil
            meta.simbolo = simbolo
        } else {
            contexto.insert(Meta(
                nome: nome,
                descricao: descricao.isEmpty ? nil : descricao,
                valorAlvo: valorAlvo,
                valorPoupado: valorInicial,
                dataLimite: temPrazo ? prazo : nil,
                simbolo: simbolo
            ))
        }
        try? contexto.save()
        dismiss()
    }
}

/// Folha pequena para reforçar um objetivo com um valor.
private struct ReforcoDeObjetivo: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let meta: Meta

    @State private var valor: Decimal?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                IconeDourado(simbolo: meta.simbolo, lado: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Legenda("Reforçar objetivo")
                    Text(meta.nome)
                        .font(Tema.fonte(17, .semibold))
                        .foregroundStyle(Tema.tinta)
                }
            }

            TextField(value: $valor, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                Text("Valor a adicionar")
            }
            .keyboardType(.decimalPad)
            .font(Tema.fonte(34, .semibold))
            .monospacedDigit()
            .foregroundStyle(Tema.tinta)

            BotaoLume(titulo: "Adicionar ao objetivo", simbolo: "plus") {
                let valor = valor ?? .zero
                meta.valorPoupado += valor
                contexto.insert(ReforcoDaMeta(valor: valor, meta: meta))
                try? contexto.save()
                dismiss()
            }
            .disabled((valor ?? .zero) <= .zero)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.fundo)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Orçamentos") {
    OrcamentoView()
        .modelContainer(ContentorDeDados.emMemoria())
}

#Preview("Objetivos") {
    OrcamentoView(mostrarObjetivos: true)
        .modelContainer(ContentorDeDados.emMemoria())
}
