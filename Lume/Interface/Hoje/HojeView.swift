import SwiftUI
import SwiftData

/// Ecrã Hoje com a composição do frame "App / 01 Resumo" do Figma,
/// mas com o número diário como protagonista: etiqueta pequena, número
/// grande com barra dourada, orçamentos por categoria, lista plana de
/// movimentos e o campo "Gastei…" em baixo, como um dock.
struct HojeView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var contas: [Conta]

    /// Muda para o separador Movimentos; injetado pela RaizView ("Ver tudo").
    var aoVerTudo: () -> Void = {}
    /// Muda para o separador Definições quando falta o rendimento.
    var aoDefinirRendimento: () -> Void = {}

    @State private var viewModel = HojeViewModel()
    @State private var transacaoEmEdicao: Transacao?
    @State private var mostrarGuardado = false

    private var resultado: CalculadoraDoDia.Resultado {
        viewModel.resultadoDoDia(
            transacoes: transacoes,
            recorrentes: recorrentes,
            definicoes: definicoes
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroDoDia
                orcamentosPorCategoria
                ultimosMovimentos
                proximasContasFixas
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .animation(.snappy, value: resultado)
        .sensoryFeedback(.success, trigger: viewModel.gravacoes)
        // O momento verde do sistema visual: confirma a gravação sem interromper.
        .overlay(alignment: .bottom) {
            if mostrarGuardado {
                Label(viewModel.resumoDaGravacao, systemImage: "checkmark")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Tema.positivo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Tema.superficie, in: Capsule())
                    .overlay(Capsule().strokeBorder(Tema.separador, lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // O VoiceOver recebe o anúncio; a cápsula é só visual.
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: viewModel.gravacoes) {
            AccessibilityNotification.Announcement(viewModel.resumoDaGravacao).post()
            withAnimation(.snappy) { mostrarGuardado = true }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut) { mostrarGuardado = false }
            }
        }
        // O composer vive em baixo, como no Figma.
        .safeAreaInset(edge: .bottom) {
            RegistoRapidoView(viewModel: viewModel, categorias: categorias)
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.vertical, 8)
                .background(Tema.fundo)
        }
        .sheet(isPresented: cartaoVisivel) {
            if let proposta = viewModel.proposta {
                CartaoDeConfirmacaoView(
                    proposta: proposta,
                    categorias: categorias,
                    aoConfirmar: { confirmada in
                        viewModel.confirmar(confirmada, categorias: categorias, contas: contas, contexto: contexto)
                    },
                    aoCancelar: { viewModel.proposta = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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

    private var cartaoVisivel: Binding<Bool> {
        Binding(
            get: { viewModel.proposta != nil },
            set: { if !$0 { viewModel.proposta = nil } }
        )
    }

    // MARK: - Hero do dia

    private var saudacao: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 6..<13: "Bom dia"
        case 13..<20: "Boa tarde"
        default: "Boa noite"
        }
    }

    /// O número do dia num cartão de boas-vindas, com o sol da Lume
    /// a rodar devagarinho no canto.
    private var heroDoDia: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saudacao)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Tema.tinta)
                // Formatar para String primeiro: o Text(_, format:) ignora
                // o locale do FormatStyle e usa o do ambiente.
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(FormatadorDeMoeda.localidade)))
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }

            NumeroDiarioView(resultado: resultado, aoDefinirRendimento: aoDefinirRendimento)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(claro: 0xFCFBF8, escuro: 0x1B1B1F),
                                Color(claro: 0xF3F0E9, escuro: 0x141417),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                SolDeLume()
                    .offset(x: 26, y: -26)
                    .opacity(0.55)
            }
            .clipShape(RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        }
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }

    // MARK: - Orçamentos por categoria

    private struct LinhaDeOrcamento: Identifiable {
        let categoria: Categoria
        let gasto: Decimal
        let orcamento: Decimal
        let fracao: Double
        var id: PersistentIdentifier { categoria.persistentModelID }
    }

    /// As três categorias com orçamento mais preenchido este mês.
    private var linhasDeOrcamento: [LinhaDeOrcamento] {
        let linhas = categorias.compactMap { categoria -> LinhaDeOrcamento? in
            guard let orcamento = categoria.orcamentoMensal, orcamento > .zero else { return nil }
            let gasto = gastoDoMes(em: categoria)
            let fracao = (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
            return LinhaDeOrcamento(categoria: categoria, gasto: gasto, orcamento: orcamento, fracao: fracao)
        }
        return Array(linhas.sorted { $0.fracao > $1.fracao }.prefix(3))
    }

    @ViewBuilder
    private var orcamentosPorCategoria: some View {
        let linhas = linhasDeOrcamento
        if !linhas.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(linhas) { linha in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(linha.categoria.nome)
                                .font(.subheadline)
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Text("\(FormatadorDeMoeda.textoEmEurosInteiros(linha.gasto)) / \(FormatadorDeMoeda.textoEmEurosInteiros(linha.orcamento)) €")
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        // Dourado só quando o orçamento passa os 90%, como no Figma.
                        BarraDeProgresso(fracao: linha.fracao, dourada: linha.fracao >= 0.9, altura: 4)
                    }
                    .accessibilityElement(children: .combine)
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

    // MARK: - Últimos movimentos

    private var ultimosMovimentos: some View {
        let visiveis = Array(transacoes.prefix(5))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Últimos movimentos")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                if !visiveis.isEmpty {
                    Button("Ver tudo") { aoVerTudo() }
                        .font(.footnote)
                        .foregroundStyle(Tema.tintaSuave)
                }
            }

            if visiveis.isEmpty {
                Text("Ainda sem movimentos. Escreve o primeiro ali em baixo.")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.top, 8)
            } else {
                // Lista plana como no Figma: linhas sobre o fundo,
                // com uma linha fina depois de cada uma.
                VStack(spacing: 0) {
                    ForEach(visiveis) { transacao in
                        LinhaDeTransacao(transacao: transacao)
                            .contentShape(Rectangle())
                            .onTapGesture { transacaoEmEdicao = transacao }
                        Divider().overlay(Tema.separador)
                    }
                }
            }
        }
    }

    // MARK: - Próximas contas fixas

    /// Recorrentes ativas que vencem nos próximos 7 dias, ordenadas pela data.
    private var proximasNosProximos7Dias: [(recorrente: Recorrente, data: Date)] {
        let calendario = Calendar.current
        let limite = calendario.date(byAdding: .day, value: 7, to: calendario.startOfDay(for: .now)) ?? .now
        return recorrentes
            .filter(\.ativa)
            .map { ($0, AgendaDeRecorrentes.proximaOcorrencia(diaDoMes: $0.diaDoMes, aPartirDe: .now)) }
            .filter { $0.1 < limite }
            .sorted { $0.1 < $1.1 }
    }

    @ViewBuilder
    private var proximasContasFixas: some View {
        let proximas = proximasNosProximos7Dias
        if !proximas.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Próximas contas fixas")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)

                VStack(spacing: 0) {
                    ForEach(proximas, id: \.recorrente.persistentModelID) { proxima in
                        LinhaDeRecorrente(recorrente: proxima.recorrente, data: proxima.data)
                        Divider().overlay(Tema.separador)
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
