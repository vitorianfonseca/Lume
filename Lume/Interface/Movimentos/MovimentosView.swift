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
                CabecalhoDeEcra(legenda: "CADA DETALHE NO SEU LUGAR", titulo: "Movimentos")
                    .padding(.top, 4)
                campoDePesquisa
                filtros
                if !doMes.isEmpty {
                    resumoDoMes
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: Tema.margemDoEcra, bottom: 4, trailing: Tema.margemDoEcra))

            if filtradas.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pesquisa.isEmpty ? "Sem movimentos" : "Nada encontrado")
                            .font(.headline)
                            .foregroundStyle(Tema.tinta)
                        Text(pesquisa.isEmpty
                            ? "Regista o primeiro no separador Registar."
                            : "Tenta outra palavra: descrição, loja ou categoria.")
                            .font(.footnote)
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.top, 12)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Tema.margemDoEcra, bottom: 0, trailing: Tema.margemDoEcra))
            }

            ForEach(porDia, id: \.dia) { grupo in
                Section {
                    ForEach(grupo.transacoes) { transacao in
                        LinhaDeTransacao(transacao: transacao, estilo: .extrato)
                            .contentShape(Rectangle())
                            .onTapGesture { transacaoAberta = transacao }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Tema.separador)
                            .listRowInsets(EdgeInsets(top: 0, leading: Tema.margemDoEcra, bottom: 0, trailing: Tema.margemDoEcra))
                    }
                    .onDelete { apagar($0, de: grupo.transacoes) }
                } header: {
                    // Dia à esquerda, saldo do dia à direita — como no frame.
                    HStack {
                        Text(titulo(para: grupo.dia))
                            .font(.footnote)
                            .foregroundStyle(Tema.tintaSuave)
                            .textCase(nil)
                        Spacer()
                        Text(saldoDoDia(grupo.transacoes))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: Tema.margemDoEcra, bottom: 4, trailing: Tema.margemDoEcra))
                }
            }

            if !transacoes.isEmpty {
                Section {
                    ShareLink(
                        item: csvDosMovimentos,
                        preview: SharePreview("Movimentos da Lume")
                    ) {
                        Text("Exportar movimentos em CSV")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Tema.douradoEscuro)
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
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// A fila de filtros do frame: chips Todos/Despesas/Receitas e o ícone
    /// de exportação à direita.
    private var filtros: some View {
        HStack(spacing: 8) {
            ForEach(Filtro.allCases, id: \.self) { opcao in
                Button {
                    withAnimation(.snappy) { filtro = opcao }
                } label: {
                    Text(opcao.rawValue)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(filtro == opcao ? Tema.tinta : Tema.tintaSuave)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            filtro == opcao ? AnyShapeStyle(Tema.areia) : AnyShapeStyle(.clear),
                            in: Capsule()
                        )
                }
                .accessibilityAddTraits(filtro == opcao ? [.isSelected] : [])
            }
            Spacer()
            // O ícone de filtro: escolhe uma categoria para afinar a lista.
            Menu {
                Picker("Categoria", selection: $categoriaFiltrada) {
                    Text("Todas as categorias").tag(String?.none)
                    ForEach(categorias) { categoria in
                        Text(categoria.nome).tag(String?.some(categoria.nome))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.subheadline)
                    .foregroundStyle(categoriaFiltrada == nil ? Tema.tintaFosca : Tema.douradoEscuro)
            }
            .accessibilityLabel("Filtrar por categoria")
        }
        // Dentro de uma linha de List, só com .borderless é que cada
        // botão recebe o toque individualmente.
        .buttonStyle(.borderless)
    }

    /// O cartão areia com o resumo do mês: movimentos, despesas e receitas.
    private var resumoDoMes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(nomeDoMes)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Text("\(doMes.count) movimentos")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
            }
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Despesas")
                        .font(.caption)
                        .foregroundStyle(Tema.tintaSuave)
                    Text(FormatadorDeMoeda.texto(despesasDoMes))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receitas")
                        .font(.caption)
                        .foregroundStyle(Tema.tintaSuave)
                    Text(FormatadorDeMoeda.texto(receitasDoMes))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .accessibilityElement(children: .combine)
    }

    /// Saldo do dia à direita do cabeçalho ("−32,04 €").
    private func saldoDoDia(_ transacoes: [Transacao]) -> String {
        let saldo = transacoes.reduce(Decimal.zero) { total, transacao in
            transacao.tipo == .receita ? total + transacao.valor : total - transacao.valor
        }
        let texto = FormatadorDeMoeda.texto(saldo < .zero ? -saldo : saldo)
        return saldo < .zero ? "−\(texto)" : "+\(texto)"
    }

    /// Campo de pesquisa no estilo dos cartões do frame: cápsula branca
    /// com contorno fino.
    private var campoDePesquisa: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)
            TextField("Pesquisar comerciante ou categoria", text: $pesquisa)
                .font(.subheadline)
                .foregroundStyle(Tema.tinta)
                .autocorrectionDisabled()
            if !pesquisa.isEmpty {
                Button {
                    pesquisa = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Tema.tintaSuave)
                }
                .accessibilityLabel("Limpar pesquisa")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.campo)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
        .buttonStyle(.borderless)
    }

    private func titulo(para dia: Date) -> String {
        let calendario = Calendar.current
        if calendario.isDateInToday(dia) { return "Hoje" }
        if calendario.isDateInYesterday(dia) { return "Ontem" }
        return dia.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(FormatadorDeMoeda.localidade))
    }

    private func apagar(_ indices: IndexSet, de grupo: [Transacao]) {
        indices.map { grupo[$0] }.forEach(contexto.delete)
        try? contexto.save()
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
