import SwiftUI
import SwiftData

/// Categorias com orçamento mensal e barra de progresso — o único sítio
/// onde entra o dourado metálico da identidade.
struct OrcamentoView: View {
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var transacoes: [Transacao]

    private var comOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal != nil } }
    private var semOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if categorias.isEmpty {
                        ContentUnavailableView(
                            "Sem categorias",
                            systemImage: "square.grid.2x2",
                            description: Text("Cria categorias nas Definições para acompanhares o orçamento.")
                        )
                    }

                    ForEach(comOrcamento) { categoria in
                        CartaoDeOrcamento(categoria: categoria, gasto: gastoDoMes(em: categoria))
                    }

                    if !semOrcamento.isEmpty {
                        seccaoSemOrcamento
                    }
                }
                .padding(20)
            }
            .background(Tema.fundo)
            .navigationTitle("Orçamento")
        }
    }

    private var seccaoSemOrcamento: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sem orçamento definido")
                .font(.headline)
                .foregroundStyle(Tema.tinta)

            VStack(spacing: 0) {
                ForEach(semOrcamento) { categoria in
                    HStack {
                        Label {
                            Text(categoria.nome).foregroundStyle(Tema.tinta)
                        } icon: {
                            Image(systemName: categoria.simbolo).foregroundStyle(categoria.cor)
                        }
                        Spacer()
                        Text(FormatadorDeMoeda.texto(gastoDoMes(em: categoria)))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 12)
                    if categoria.persistentModelID != semOrcamento.last?.persistentModelID {
                        Divider().overlay(Tema.separador)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
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

private struct CartaoDeOrcamento: View {
    let categoria: Categoria
    let gasto: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text(categoria.nome).font(.body.weight(.medium)).foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: categoria.simbolo).foregroundStyle(categoria.cor)
                }
                Spacer()
                Text("\(FormatadorDeMoeda.texto(gasto)) / \(FormatadorDeMoeda.texto(orcamento))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
            }

            barra

            if fracao > 1 {
                // Sem alarmes vermelhos: informação, não culpa.
                Text("Acima do orçamento este mês")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .padding(16)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(categoria.nome): \(FormatadorDeMoeda.texto(gasto)) de \(FormatadorDeMoeda.texto(orcamento))")
    }

    private var orcamento: Decimal { categoria.orcamentoMensal ?? .zero }

    private var fracao: Double {
        guard orcamento > .zero else { return 0 }
        return (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
    }

    private var barra: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.separador)
                Capsule()
                    .fill(Tema.douradoMetalico)
                    .frame(width: geometria.size.width * min(fracao, 1))
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    OrcamentoView()
        .modelContainer(ContentorDeDados.emMemoria())
}
