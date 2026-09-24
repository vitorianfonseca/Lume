import SwiftUI
import SwiftData

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
}

#Preview {
    MovimentosView()
        .modelContainer(ContentorDeDados.emMemoria())
}
