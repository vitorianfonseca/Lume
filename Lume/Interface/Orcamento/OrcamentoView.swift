import SwiftUI
import SwiftData

/// Categorias com orçamento mensal e barras finas, no estilo plano do Hoje:
/// dourado metálico só quando o orçamento passa os 90%.
struct OrcamentoView: View {
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var transacoes: [Transacao]

    private var comOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal != nil } }
    private var semOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if categorias.isEmpty {
                        ContentUnavailableView(
                            "Sem categorias",
                            systemImage: "square.grid.2x2",
                            description: Text("Cria categorias nas Definições para acompanhares o orçamento.")
                        )
                    }

                    if !comOrcamento.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(comOrcamento) { categoria in
                                LinhaDeOrcamento(categoria: categoria, gasto: gastoDoMes(em: categoria))
                            }
                        }
                    }

                    if !semOrcamento.isEmpty {
                        seccaoSemOrcamento
                    }
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Tema.fundo)
            .navigationTitle("Orçamento")
        }
    }

    private var seccaoSemOrcamento: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sem orçamento definido")
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)

            VStack(spacing: 0) {
                ForEach(semOrcamento) { categoria in
                    HStack {
                        Label {
                            Text(categoria.nome)
                                .font(.subheadline)
                                .foregroundStyle(Tema.tinta)
                        } icon: {
                            Image(systemName: categoria.simbolo)
                                .font(.footnote)
                                .foregroundStyle(categoria.cor)
                        }
                        Spacer()
                        Text(FormatadorDeMoeda.texto(gastoDoMes(em: categoria)))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    Divider().overlay(Tema.separador)
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
}

private struct LinhaDeOrcamento: View {
    let categoria: Categoria
    let gasto: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(categoria.nome)
                        .font(.subheadline)
                        .foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: categoria.simbolo)
                        .font(.footnote)
                        .foregroundStyle(categoria.cor)
                }
                Spacer()
                Text("\(FormatadorDeMoeda.textoEmEurosInteiros(gasto)) / \(FormatadorDeMoeda.textoEmEurosInteiros(orcamento)) €")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
            }

            BarraDeProgresso(fracao: fracao, dourada: fracao >= 0.9, altura: 4)

            if fracao > 1 {
                // Sem alarmes vermelhos: informação, não culpa.
                Text("Acima do orçamento este mês")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(categoria.nome): \(FormatadorDeMoeda.texto(gasto)) de \(FormatadorDeMoeda.texto(orcamento))")
    }

    private var orcamento: Decimal { categoria.orcamentoMensal ?? .zero }

    private var fracao: Double {
        guard orcamento > .zero else { return 0 }
        return (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
    }
}

#Preview {
    OrcamentoView()
        .modelContainer(ContentorDeDados.emMemoria())
}
