import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Lista completa de movimentos, agrupada por dia, com pesquisa e apagar por swipe.
struct MovimentosView: View {
    /// Os filtros do ecrã 02: Todos · Despesas · Receitas.
    private enum Filtro: String, CaseIterable {
        case todos = "Todos"
        case despesas = "Despesas"
        case receitas = "Receitas"
    }

    @Environment(\.modelContext) private var contexto
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @State private var pesquisa = ""
    @State private var filtro = Filtro.todos
    /// Filtro por categoria, aberto pelo ícone à direita dos chips.
    @State private var categoriaFiltrada: String?
    @State private var transacaoAberta: Transacao?
    @State private var transacaoEmEdicao: Transacao?
    /// O movimento à espera de confirmação para ser eliminado.
    @State private var transacaoAEliminar: Transacao?

    /// Sem filtro nem pesquisa: só então o resumo do mês faz sentido.
    private var semFiltro: Bool {
        filtro == .todos && categoriaFiltrada == nil && pesquisa.isEmpty
    }

    private var filtradas: [Transacao] {
        transacoes.filter { transacao in
            let passaFiltro = switch filtro {
            case .todos: true
            case .despesas: transacao.tipo == .despesa
            case .receitas: transacao.tipo == .receita
            }
            guard passaFiltro else { return false }
            if let categoriaFiltrada, transacao.categoria?.nome != categoriaFiltrada {
                return false
            }
            guard !pesquisa.isEmpty else { return true }
            return transacao.descricao.localizedStandardContains(pesquisa)
                || (transacao.loja?.localizedStandardContains(pesquisa) ?? false)
                || (transacao.categoria?.nome.localizedStandardContains(pesquisa) ?? false)
        }
    }

    // MARK: - Resumo do mês (o cartão areia do frame)

    private var doMes: [Transacao] {
        let calendario = Calendar.current
        return transacoes.filter { calendario.isDate($0.data, equalTo: .now, toGranularity: .month) }
    }

    private var despesasDoMes: Decimal {
        doMes.filter { $0.tipo == .despesa }.reduce(.zero) { $0 + $1.valor }
    }

    private var receitasDoMes: Decimal {
        doMes.filter { $0.tipo == .receita }.reduce(.zero) { $0 + $1.valor }
    }

    private var nomeDoMes: String {
        Date.now.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).capitalized
    }

    /// A legenda do cabeçalho é contexto, não slogan: "OUTUBRO · 23 MOVIMENTOS".
    private var legendaDoMes: String {
        let total = doMes.count
        return "\(nomeDoMes) · \(total) \(total == 1 ? "movimento" : "movimentos")"
    }

    /// Já vêm ordenadas por data; o agrupamento preserva a ordem dentro de cada dia.
    private var porDia: [(dia: Date, transacoes: [Transacao])] {
        let calendario = Calendar.current
        return Dictionary(grouping: filtradas) { calendario.startOfDay(for: $0.data) }
            .sorted { $0.key > $1.key }
            .map { (dia: $0.key, transacoes: $0.value) }
    }

    var body: some View {
        // Lista plana como no frame: linhas sobre o fundo branco com
        // hairlines, cabeçalhos de dia discretos, swipe para apagar.
        List {
            Section {
                CabecalhoDeEcra(legenda: legendaDoMes, titulo: "Movimentos")
                    .padding(.top, 4)
                campoDePesquisa
                filtros
                if let categoriaFiltrada {
                    etiquetaDaCategoria(categoriaFiltrada)
                }
                // O resumo só quando se vê a lista toda; com filtro ou
                // pesquisa os números do mês não correspondem às linhas.
                if !doMes.isEmpty, semFiltro {
                    resumoDoMes
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: Tema.margemDoEcra, bottom: 4, trailing: Tema.margemDoEcra))

            if filtradas.isEmpty {
                Section {
                    EstadoVazio(
                        ilustracao: pesquisa.isEmpty ? .carteira : .lupa,
                        titulo: pesquisa.isEmpty ? "Sem movimentos" : "Nada encontrado",
                        texto: pesquisa.isEmpty
                            ? "Regista o primeiro no separador Registar."
                            : "Tenta outra palavra: descrição, loja ou categoria."
                    )
                    .padding(.top, 12)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Tema.margemDoEcra, bottom: 0, trailing: Tema.margemDoEcra))
            }

            ForEach(Array(porDia.enumerated()), id: \.element.dia) { indice, grupo in
                Section {
                    ForEach(grupo.transacoes) { transacao in
                        LinhaDeTransacao(transacao: transacao, estilo: .extrato)
                            .contentShape(Rectangle())
                            .onTapGesture { transacaoAberta = transacao }
                            // Deslizar para editar ou eliminar; o toque
                            // longo dá as mesmas ações.
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    transacaoAEliminar = transacao
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                .tint(Tema.negativo)
                                Button {
                                    transacaoEmEdicao = transacao
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(Tema.douradoEscuro)
                            }
                            .contextMenu {
                                Button("Editar", systemImage: "pencil") { transacaoEmEdicao = transacao }
                                Button("Eliminar", systemImage: "trash", role: .destructive) {
                                    transacaoAEliminar = transacao
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: Tema.margemDoEcra, bottom: 0, trailing: Tema.margemDoEcra))
                    }
                } header: {
                    // Divisor entre dias + "Hoje, 1 outubro" com o saldo
                    // real do dia em cinzento neutro.
                    VStack(alignment: .leading, spacing: 12) {
                        if indice > 0 {
                            Divider().overlay(Tema.separador)
                        }
                        HStack {
                            Text(titulo(para: grupo.dia))
                                .font(Tema.fonte(17, .semibold))
                                .foregroundStyle(Tema.tinta)
                                .textCase(nil)
                            Spacer()
                            Text(saldoDoDia(grupo.transacoes))
                                .font(Tema.fonte(13, .medium))
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                                .accessibilityLabel("Saldo do dia: \(saldoDoDia(grupo.transacoes))")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: Tema.margemDoEcra, bottom: 0, trailing: Tema.margemDoEcra))
                }
            }

            if !transacoes.isEmpty {
                Section {
                    ShareLink(
                        item: csvDosMovimentos,
                        preview: SharePreview("Movimentos da Lume")
                    ) {
                        Text("Exportar movimentos em CSV")
                            .font(Tema.fonte(13, .medium))
                            .textoDourado()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: Tema.margemDoEcra, bottom: 8, trailing: Tema.margemDoEcra))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        // As linhas reorganizam-se ao filtrar; a pesquisa atualiza sem animar,
        // para escrever não engasgar a lista.
        .animation(.snappy, value: filtro)
        .animation(.snappy, value: categoriaFiltrada)
        .sheet(item: $transacaoAberta) { transacao in
            MovimentoView(
                transacao: transacao,
                aoEditar: {
                    transacaoAberta = nil
                    transacaoEmEdicao = transacao
                },
                aoFechar: { transacaoAberta = nil }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
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
        .confirmationDialog(
            "Eliminar este movimento?",
            isPresented: Binding(
                get: { transacaoAEliminar != nil },
                set: { if !$0 { transacaoAEliminar = nil } }
            ),
            titleVisibility: .visible,
            presenting: transacaoAEliminar
        ) { transacao in
            Button("Eliminar", role: .destructive) { eliminar(transacao) }
            Button("Cancelar", role: .cancel) { transacaoAEliminar = nil }
        } message: { transacao in
            Text("\(transacao.loja ?? transacao.descricao) · \(FormatadorDeMoeda.texto(transacao.valor)). Não é possível desfazer.")
        }
    }

    /// A etiqueta da categoria filtrada, com um toque para a tirar —
    /// assim o filtro nunca fica escondido atrás do ícone.
    private func etiquetaDaCategoria(_ nome: String) -> some View {
        Button {
            withAnimation(.snappy) { categoriaFiltrada = nil }
        } label: {
            HStack(spacing: 6) {
                Text(nome)
                    .font(Tema.fonte(12, .semibold))
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Tema.ouro)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Tema.areia, in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Filtro: \(nome). Toca para remover.")
    }

    /// A fila de filtros: o seletor segmentado da app e, ao lado, o filtro
    /// por categoria num botão redondo (nunca um ícone solto).
    private var filtros: some View {
        HStack(spacing: 10) {
            SeletorSegmentado(
                opcoes: Filtro.allCases,
                escolhida: $filtro,
                titulo: \.rawValue
            )
            Menu {
                Picker("Categoria", selection: $categoriaFiltrada) {
                    Text("Todas as categorias").tag(String?.none)
                    ForEach(categorias) { categoria in
                        Text(categoria.nome).tag(String?.some(categoria.nome))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(categoriaFiltrada == nil ? AnyShapeStyle(Tema.tinta) : Tema.ouro)
                    .frame(width: 38, height: 38)
                    .background(categoriaFiltrada == nil ? Tema.bege : Tema.areia, in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Filtrar por categoria")
            .accessibilityValue(categoriaFiltrada ?? "Todas as categorias")
        }
        // Dentro de uma linha de List, só com .borderless é que cada
        // botão recebe o toque individualmente.
        .buttonStyle(.borderless)
    }

    /// Saldo do mês: receitas menos despesas.
    private var saldoDoMes: Decimal { receitasDoMes - despesasDoMes }

    /// O resumo do mês numa linha: "↓ 986,48 € · ↑ 1 450,00 €" e o saldo
    /// à direita. Os números completos vivem no Resumo; aqui é só contexto.
    private var resumoDoMes: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                parcela(despesasDoMes, simbolo: "arrow.down")
                Text("·").foregroundStyle(Tema.tintaSuave)
                parcela(receitasDoMes, simbolo: "arrow.up")
            }
            .font(Tema.fonte(13, .medium))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(comSinal(saldoDoMes))
                .font(Tema.fonte(13, .semibold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Tema.superficie.opacity(0.7), in: Capsule())
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .cartaoCafe(raio: Tema.Raio.campo)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(nomeDoMes): despesas \(FormatadorDeMoeda.texto(despesasDoMes)), receitas \(FormatadorDeMoeda.texto(receitasDoMes)), saldo \(comSinal(saldoDoMes))"
        )
    }

    private func parcela(_ valor: Decimal, simbolo: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: simbolo)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tema.tintaSuave)
            Text(FormatadorDeMoeda.texto(valor))
                .foregroundStyle(Tema.tinta)
        }
    }

    /// "+12,00 €", "−32,04 €" ou "0,00 €", sempre com o menos tipográfico.
    private func comSinal(_ valor: Decimal) -> String {
        let texto = FormatadorDeMoeda.textoAbsoluto(valor)
        if valor > .zero { return "+\(texto)" }
        if valor < .zero { return "\u{2212}\(texto)" }
        return texto
    }

    /// Saldo real do dia à direita do cabeçalho: receitas menos despesas
    /// só das linhas visíveis desse dia ("−13,30 €").
    private func saldoDoDia(_ transacoes: [Transacao]) -> String {
        let saldo = transacoes.reduce(Decimal.zero) { total, transacao in
            transacao.tipo == .receita ? total + transacao.valor : total - transacao.valor
        }
        return comSinal(saldo)
    }

    /// Campo de pesquisa no estilo dos cartões do frame: cápsula branca
    /// com contorno fino.
    private var campoDePesquisa: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tintaSuave)
            TextField(
                text: $pesquisa,
                prompt: Text("Pesquisar comerciante ou categoria").foregroundStyle(Tema.placeholder)
            ) {
                Text("Pesquisar")
            }
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tinta)
                .autocorrectionDisabled()
            if !pesquisa.isEmpty {
                Button {
                    pesquisa = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }
                .accessibilityLabel("Limpar pesquisa")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 48)
        .cartao(raio: 16)
        .buttonStyle(.borderless)
    }

    private func titulo(para dia: Date) -> String {
        let calendario = Calendar.current
        let diaEMes = "\(dia.formatted(.dateTime.day().locale(FormatadorDeMoeda.localidade))) \(dia.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)))"
        if calendario.isDateInToday(dia) { return "Hoje, \(diaEMes)" }
        if calendario.isDateInYesterday(dia) { return "Ontem, \(diaEMes)" }
        let semana = dia.formatted(.dateTime.weekday(.wide).locale(FormatadorDeMoeda.localidade))
        return "\(semana.prefix(1).uppercased() + semana.dropFirst()), \(diaEMes)"
    }

    private func eliminar(_ transacao: Transacao) {
        transacaoAEliminar = nil
        withAnimation(.snappy) {
            contexto.delete(transacao)
            try? contexto.save()
        }
    }

    // MARK: - Exportação

    /// CSV à portuguesa: separador ';' e vírgula decimal, como o Excel cá espera.
    private var csvDosMovimentos: MovimentosCSV {
        var linhas = ["data;tipo;descricao;loja;categoria;conta;origem;valor"]
        for transacao in transacoes {
            let campos = [
                transacao.data.formatted(.iso8601.year().month().day()),
                transacao.tipo.rawValue,
                transacao.descricao,
                transacao.loja ?? "",
                transacao.categoria?.nome ?? "",
                transacao.conta?.nome ?? "",
                transacao.origem.rawValue,
                "\(transacao.valor)".replacingOccurrences(of: ".", with: ","),
            ].map(escapar)
            linhas.append(campos.joined(separator: ";"))
        }
        return MovimentosCSV(texto: linhas.joined(separator: "\n"))
    }

    private func escapar(_ campo: String) -> String {
        guard campo.contains(";") || campo.contains("\"") || campo.contains("\n") else {
            return campo
        }
        return "\"\(campo.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

/// Ficheiro CSV partilhável via ShareLink.
private struct MovimentosCSV: Transferable {
    let texto: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            Data(csv.texto.utf8)
        }
        .suggestedFileName("lume-movimentos.csv")
    }
}

#Preview {
    MovimentosView()
        .modelContainer(ContentorDeDados.emMemoria())
}
