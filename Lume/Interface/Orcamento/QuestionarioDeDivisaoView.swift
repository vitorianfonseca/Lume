import SwiftData
import SwiftUI

/// "Dividir à minha medida": oito perguntas curtas, uma por ecrã, sobre a
/// vida, os objetivos e as prioridades da pessoa. No fim, a IA (Claude, o
/// modelo do iPhone ou, sem nenhum, as regras) propõe a divisão, que volta
/// ao ecrã de divisão para ser revista antes de guardar.
struct QuestionarioDeDivisaoView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var transacoes: [Transacao]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query private var metas: [Meta]

    let total: Decimal
    let aoTerminar: (PropostaDeDivisao) -> Void

    @State private var respostas = RespostasDaDivisao.guardadas() ?? RespostasDaDivisao()
    @State private var passo = Passo.casa
    @State private var aPensar = false
    @State private var erro: String?

    enum Passo: Int, CaseIterable {
        case casa, rendimento, fixos, objetivo, poupanca, prioridades, estilo, nota

        var pergunta: String {
            switch self {
            case .casa: "Com quem vives?"
            case .rendimento: "O teu rendimento é…"
            case .fixos: "O que já está comprometido todos os meses?"
            case .objetivo: "O que é mais importante para ti agora?"
            case .poupanca: "Quanto queres guardar do que recebes?"
            case .prioridades: "Onde não abdicas e onde podes cortar?"
            case .estilo: "Como gostas de gerir o mês?"
            case .nota: "Há mais alguma coisa que a Lume deva saber?"
            }
        }

        /// Uma linha a explicar porquê — perguntar sem dizer para quê tira confiança.
        var porque: String {
            switch self {
            case .casa: "Usamos isto para sugerir a tua divisão: uma casa maior pede mais folga."
            case .rendimento: "Com um rendimento variável, a Lume deixa mais margem."
            case .fixos: "Os compromissos ficam cobertos antes de tudo o resto."
            case .objetivo: "O teu objetivo decide o peso da poupança."
            case .poupanca: "A poupança sai primeiro, para não ficar para o fim do mês."
            case .prioridades: "Protegemos o essencial e apertamos onde disseres."
            case .estilo: "Muda a margem que fica em cada categoria."
            case .nota: "Férias, uma revisão do carro, um aniversário — tudo ajuda."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cabecalho
                    conteudo
                        .id(passo)
                        .transition(.opacity)
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            rodape
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(aPensar)
    }

    // MARK: - Cabeçalho e rodapé

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // "←" para a pergunta anterior; na primeira, só fechar.
                if passo != .casa {
                    BotaoRedondo(simbolo: "chevron.left", rotulo: "Pergunta anterior") { mudar(-1) }
                        .disabled(aPensar)
                }
                Spacer()
                BotaoRedondo(simbolo: "xmark", rotulo: "Fechar") { dismiss() }
                    .disabled(aPensar)
            }
            .frame(height: 36)

            Legenda("Pergunta \(passo.rawValue + 1) de \(Passo.allCases.count)")
                .padding(.top, 4)
            BarraDeProgresso(fracao: Double(passo.rawValue + 1) / Double(Passo.allCases.count))
            Text(passo.pergunta)
                .font(Tema.fonte(24, .semibold))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            Text(passo.porque)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rodape: some View {
        VStack(spacing: 8) {
            if let erro {
                Text(erro)
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.negativo)
            }
            if passo == .nota {
                if aPensar {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("A pensar na tua divisão…")
                            .font(Tema.fonte(14, .medium))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                } else {
                    BotaoLume(titulo: "Dividir à minha medida", simbolo: "sparkles") { pedirDivisao() }
                }
            } else {
                // A seta depois do texto: "→" quer dizer avançar.
                Button { mudar(1) } label: {
                    HStack(spacing: 8) {
                        Text("Continuar")
                            .font(Tema.fonte(15, .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(EstiloDeBotaoLume(estilo: .principal))
            }
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Tema.fundo)
    }

    private func mudar(_ delta: Int) {
        guard let novo = Passo(rawValue: passo.rawValue + delta) else { return }
        withAnimation(.snappy(duration: 0.2)) { passo = novo }
    }

    /// Escolha simples: marca a opção e passa à pergunta seguinte logo a
    /// seguir, para se ver o ✓ antes de avançar.
    private func escolherEAvancar(_ acao: @escaping () -> Void) {
        acao()
        let atual = passo
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard passo == atual else { return }
            mudar(1)
        }
    }

    // MARK: - Perguntas

    @ViewBuilder
    private var conteudo: some View {
        switch passo {
        case .casa:
            VStack(spacing: 8) {
                ForEach(RespostasDaDivisao.Agregado.allCases, id: \.self) { opcao in
                    escolha(opcao.titulo, selecionada: respostas.agregado == opcao) {
                        escolherEAvancar { respostas.agregado = opcao }
                    }
                }
            }

        case .rendimento:
            VStack(spacing: 8) {
                ForEach(RespostasDaDivisao.Rendimento.allCases, id: \.self) { opcao in
                    escolha(opcao.titulo, selecionada: respostas.rendimento == opcao) {
                        escolherEAvancar { respostas.rendimento = opcao }
                    }
                }
            }

        case .fixos:
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    campoDeValor("Renda ou prestação da casa", valor: $respostas.habitacao)
                    Divider().overlay(Tema.separador)
                    campoDeValor("Créditos e outras dívidas", valor: $respostas.dividas)
                }
                .padding(.horizontal, 16)
                .cartao()

                let ativas = recorrentes.filter(\.ativa)
                if !ativas.isEmpty {
                    Text("A Lume já conhece estas contas fixas:")
                        .font(Tema.fonte(13, .medium))
                        .foregroundStyle(Tema.tintaSuave)
                    VStack(spacing: 0) {
                        ForEach(ativas) { recorrente in
                            HStack {
                                Text(recorrente.nome)
                                    .font(Tema.fonte(14))
                                    .foregroundStyle(Tema.tinta)
                                Spacer()
                                Text(FormatadorDeMoeda.texto(recorrente.valor))
                                    .font(Tema.fonte(14, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Tema.tinta)
                            }
                            .padding(.vertical, 11)
                            if recorrente.persistentModelID != ativas.last?.persistentModelID {
                                Divider().overlay(Tema.separador)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .cartao()
                }
            }

        case .objetivo:
            VStack(spacing: 8) {
                ForEach(RespostasDaDivisao.Objetivo.allCases, id: \.self) { opcao in
                    escolha(opcao.titulo, selecionada: respostas.objetivo == opcao) {
                        // "Juntar para um objetivo" pede ainda qual: aí não avança sozinho.
                        if opcao == .meta, !metas.isEmpty {
                            respostas.objetivo = opcao
                        } else {
                            escolherEAvancar { respostas.objetivo = opcao }
                        }
                    }
                }
                if respostas.objetivo == .meta, !metas.isEmpty {
                    Text("Qual objetivo?")
                        .font(Tema.fonte(13, .medium))
                        .foregroundStyle(Tema.tintaSuave)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                    ForEach(metas) { meta in
                        escolha(meta.nome, selecionada: respostas.metaEscolhida == meta.nome) {
                            escolherEAvancar { respostas.metaEscolhida = meta.nome }
                        }
                    }
                }
            }

        case .poupanca:
            VStack(spacing: 8) {
                ForEach([5, 10, 15, 20, 30], id: \.self) { pct in
                    escolha("\(pct)%",
                            detalhe: FormatadorDeMoeda.texto(AjusteDaDivisao.inteiro(total * Decimal(pct) / 100)),
                            selecionada: respostas.percentagemDePoupanca == pct) {
                        escolherEAvancar { respostas.percentagemDePoupanca = pct }
                    }
                }
                escolha("O que sobrar", detalhe: "No fim do mês", selecionada: respostas.percentagemDePoupanca == nil) {
                    escolherEAvancar { respostas.percentagemDePoupanca = nil }
                }
                Text("Sobre \(FormatadorDeMoeda.texto(total)) recebidos.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .prioridades:
            VStack(spacing: 0) {
                ForEach(categorias) { categoria in
                    linhaDePrioridade(categoria)
                    if categoria.id != categorias.last?.id {
                        Divider().overlay(Tema.separador)
                    }
                }
            }
            .padding(.horizontal, 16)
            .cartao()

        case .estilo:
            VStack(spacing: 8) {
                ForEach(RespostasDaDivisao.Estilo.allCases, id: \.self) { opcao in
                    escolha(opcao.titulo, detalhe: opcao.detalhe, selecionada: respostas.estilo == opcao) {
                        escolherEAvancar { respostas.estilo = opcao }
                    }
                }
            }

        case .nota:
            VStack(alignment: .leading, spacing: 10) {
                TextField(
                    text: $respostas.nota,
                    prompt: Text("Ex.: vou de férias em agosto, o carro precisa de revisão…").foregroundStyle(Tema.placeholder),
                    axis: .vertical
                ) {
                    Text("Nota")
                }
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
                .lineLimit(4...8)
                .padding(16)
                .cartao()
                Text("Opcional. As respostas ficam guardadas neste iPhone para a próxima divisão.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
    }

    // MARK: - Peças

    /// Uma opção a toda a largura, empilhada com as outras.
    private func escolha(_ titulo: String, detalhe: String? = nil, selecionada: Bool, acao: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.15)) { acao() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(Tema.fonte(15, selecionada ? .semibold : .regular))
                        .foregroundStyle(selecionada ? Tema.ouro : AnyShapeStyle(Tema.tinta))
                    if let detalhe {
                        Text(detalhe)
                            .font(Tema.fonte(12))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tintaSuave)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selecionada ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selecionada ? Tema.ouro : AnyShapeStyle(Tema.placeholder))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: detalhe == nil ? 52 : 64, alignment: .leading)
            .contentShape(Rectangle())
            .cartao(selecionada ? Tema.areia : Tema.superficie, raio: Tema.Raio.campo)
        }
        .buttonStyle(EscalaAoTocar())
        .sensoryFeedback(.selection, trigger: selecionada)
        .accessibilityAddTraits(selecionada ? [.isSelected] : [])
    }

    private func campoDeValor(_ titulo: String, valor: Binding<Decimal>) -> some View {
        HStack {
            Text(titulo)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tinta)
            Spacer(minLength: 8)
            CampoDeEuros(valor: valor)
        }
        .padding(.vertical, 10)
    }

    private func linhaDePrioridade(_ categoria: Categoria) -> some View {
        let atual = respostas.prioridades[categoria.nome] ?? .normal
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconeDeCategoria(categoria: categoria, lado: 30)
                Text(categoria.nome)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
            }
            HStack(spacing: 6) {
                ForEach(RespostasDaDivisao.Prioridade.allCases, id: \.self) { opcao in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) { respostas.prioridades[categoria.nome] = opcao }
                    } label: {
                        Text(opcao.titulo)
                            .font(Tema.fonte(12, atual == opcao ? .semibold : .regular))
                            .foregroundStyle(atual == opcao ? Tema.ouro : AnyShapeStyle(Tema.tintaSuave))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(atual == opcao ? Tema.areia : Tema.bege,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(categoria.nome): \(opcao.titulo)")
                    .accessibilityAddTraits(atual == opcao ? [.isSelected] : [])
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Pedir a divisão

    private func pedirDivisao() {
        erro = nil
        aPensar = true
        respostas.guardar()
        let contexto = contextoDaDivisao()
        let respostas = respostas
        Task {
            do {
                let proposta = try await DivisaoComRecurso.padrao().propor(respostas, contexto: contexto)
                aoTerminar(proposta)
                dismiss()
            } catch {
                erro = "Não consegui fazer a divisão. Tenta outra vez."
                aPensar = false
            }
        }
    }

    /// Os factos da app: média dos últimos 3 meses completos, contas fixas
    /// ativas por categoria e o que falta a cada objetivo.
    private func contextoDaDivisao() -> ContextoDaDivisao {
        let calendario = Calendar.current
        let inicioDoMes = calendario.dateInterval(of: .month, for: .now)?.start ?? .now
        let inicio = calendario.date(byAdding: .month, value: -3, to: inicioDoMes) ?? inicioDoMes
        let recentes = transacoes.filter { $0.tipo == .despesa && $0.data >= inicio && $0.data < inicioDoMes }

        let categoriasNoContexto = categorias.map { categoria in
            let gasto = recentes
                .filter { $0.categoria?.persistentModelID == categoria.persistentModelID }
                .reduce(Decimal.zero) { $0 + $1.valor }
            let fixos = recorrentes
                .filter { $0.ativa && $0.categoria?.persistentModelID == categoria.persistentModelID }
                .reduce(Decimal.zero) { $0 + $1.valor }
            return ContextoDaDivisao.CategoriaNoContexto(
                nome: categoria.nome,
                limiteAtual: categoria.orcamentoMensal,
                mediaGasta: (gasto / 3).arredondadoACentimos(),
                fixos: fixos
            )
        }
        let metasNoContexto = metas.compactMap { meta -> ContextoDaDivisao.MetaNoContexto? in
            let falta = meta.valorAlvo - meta.valorPoupado
            guard falta > .zero else { return nil }
            let meses = meta.dataLimite.flatMap {
                calendario.dateComponents([.month], from: .now, to: $0).month
            }.map { max($0, 1) }
            return .init(nome: meta.nome, falta: falta, mesesAtePrazo: meses)
        }
        return ContextoDaDivisao(total: total, categorias: categoriasNoContexto, metas: metasNoContexto)
    }
}

#Preview {
    QuestionarioDeDivisaoView(total: 1450) { _ in }
        .modelContainer(ContentorDeDados.emMemoria())
}
