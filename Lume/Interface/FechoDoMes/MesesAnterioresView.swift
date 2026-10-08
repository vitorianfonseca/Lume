import SwiftData
import SwiftUI

/// A lista de meses já terminados com movimentos, para reabrir o fecho de
/// qualquer um deles a qualquer momento — não só na notificação do dia 1.
struct MesesAnterioresView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]

    @State private var mesEmFecho: MesDoAno?

    private struct MesDoAno: Identifiable, Hashable {
        let mes: Int
        let ano: Int
        var id: String { "\(ano)-\(mes)" }
    }

    private var calendario: Calendar { Calendar.current }

    private var mesesComDados: [MesDoAno] {
        let atual = calendario.dateComponents([.year, .month], from: .now)
        var vistos = Set<MesDoAno>()
        var resultado: [MesDoAno] = []
        for transacao in transacoes {
            let componentes = calendario.dateComponents([.year, .month], from: transacao.data)
            guard let ano = componentes.year, let mes = componentes.month else { continue }
            // Só meses já terminados — o fecho não é do mês a decorrer.
            guard ano != atual.year || mes != atual.month else { continue }
            let item = MesDoAno(mes: mes, ano: ano)
            if vistos.insert(item).inserted {
                resultado.append(item)
            }
        }
        return resultado
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(legenda: "Planear", titulo: "Meses anteriores", aoVoltar: { dismiss() }, simboloDeVoltar: "xmark")

                if mesesComDados.isEmpty {
                    EstadoVazio(
                        ilustracao: .graficos,
                        titulo: "Ainda não há meses fechados",
                        texto: "Volta aqui depois do fim do primeiro mês com movimentos registados."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(mesesComDados) { item in
                            Button { mesEmFecho = item } label: {
                                HStack {
                                    Text(nome(de: item))
                                        .font(Tema.fonte(15, .medium))
                                        .foregroundStyle(Tema.tinta)
                                    Spacer()
                                    Text(FormatadorDeMoeda.texto(totalGasto(item)))
                                        .font(Tema.fonte(14))
                                        .monospacedDigit()
                                        .foregroundStyle(Tema.tintaSuave)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Tema.placeholder)
                                }
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if item.id != mesesComDados.last?.id {
                                Divider().overlay(Tema.separador)
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
        .fullScreenCover(item: $mesEmFecho) { item in
            FechoDoMesView(mes: item.mes, ano: item.ano)
        }
    }

    private func nome(de item: MesDoAno) -> String {
        let data = calendario.date(from: DateComponents(year: item.ano, month: item.mes, day: 1)) ?? .now
        let texto = data.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).capitalized
        let anoAtual = calendario.component(.year, from: .now)
        return item.ano == anoAtual ? texto : "\(texto) \(item.ano)"
    }

    private func totalGasto(_ item: MesDoAno) -> Decimal {
        transacoes
            .filter { transacao in
                transacao.tipo == .despesa
                    && calendario.component(.year, from: transacao.data) == item.ano
                    && calendario.component(.month, from: transacao.data) == item.mes
            }
            .reduce(.zero) { $0 + $1.valor }
    }
}

#Preview {
    MesesAnterioresView()
        .modelContainer(ContentorDeDados.emMemoria())
}
