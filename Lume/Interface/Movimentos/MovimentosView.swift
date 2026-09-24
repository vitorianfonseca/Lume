import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Lista completa de movimentos, agrupada por dia, com pesquisa e apagar por swipe.
struct MovimentosView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @State private var pesquisa = ""
    @State private var transacaoEmEdicao: Transacao?

    private var filtradas: [Transacao] {
        guard !pesquisa.isEmpty else { return transacoes }
        return transacoes.filter { transacao in
            transacao.descricao.localizedStandardContains(pesquisa)
                || (transacao.loja?.localizedStandardContains(pesquisa) ?? false)
                || (transacao.categoria?.nome.localizedStandardContains(pesquisa) ?? false)
        }
    }

    /// Já vêm ordenadas por data; o agrupamento preserva a ordem dentro de cada dia.
    private var porDia: [(dia: Date, transacoes: [Transacao])] {
        let calendario = Calendar.current
        return Dictionary(grouping: filtradas) { calendario.startOfDay(for: $0.data) }
            .sorted { $0.key > $1.key }
            .map { (dia: $0.key, transacoes: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtradas.isEmpty {
                    ContentUnavailableView(
                        pesquisa.isEmpty ? "Sem movimentos" : "Nada encontrado",
                        systemImage: "tray",
                        description: Text(pesquisa.isEmpty
                            ? "Regista o primeiro no separador Hoje."
                            : "Tenta outra palavra: descrição, loja ou categoria.")
                    )
                } else {
                    // Lista plana como no Hoje: linhas sobre o fundo com
                    // hairlines, cabeçalhos de dia discretos, swipe para apagar.
                    List {
                        ForEach(porDia, id: \.dia) { grupo in
                            Section {
                                ForEach(grupo.transacoes) { transacao in
                                    LinhaDeTransacao(transacao: transacao)
                                        .contentShape(Rectangle())
                                        .onTapGesture { transacaoEmEdicao = transacao }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparatorTint(Tema.separador)
                                        .listRowInsets(EdgeInsets(top: 0, leading: Tema.margemDoEcra, bottom: 0, trailing: Tema.margemDoEcra))
                                }
                                .onDelete { apagar($0, de: grupo.transacoes) }
                            } header: {
                                Text(titulo(para: grupo.dia))
                                    .font(.footnote)
                                    .foregroundStyle(Tema.tintaSuave)
                                    .textCase(nil)
                                    .listRowInsets(EdgeInsets(top: 12, leading: Tema.margemDoEcra, bottom: 4, trailing: Tema.margemDoEcra))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Tema.fundo)
            .navigationTitle("Movimentos")
            .searchable(text: $pesquisa, prompt: "Descrição, loja ou categoria")
            .toolbar {
                if !transacoes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: csvDosMovimentos,
                            preview: SharePreview("Movimentos da Lume")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Exportar movimentos em CSV")
                    }
                }
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
