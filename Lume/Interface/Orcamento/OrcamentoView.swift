import SwiftUI
import SwiftData

/// Categorias com orçamento mensal e barras finas, no estilo plano do Hoje:
/// dourado metálico só quando o orçamento passa os 90%.
struct OrcamentoView: View {
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var transacoes: [Transacao]
    @Query(sort: \Meta.nome) private var metas: [Meta]

    @State private var metaEmEdicao: Meta?
    @State private var mostrarNovaMeta = false

    private var comOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal != nil } }
    private var semOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("As tuas contas")
                        .font(.headline)
                        .foregroundStyle(Tema.tinta)
                        .padding(.horizontal, Tema.margemDoEcra)
                    CarrosselDeContas()
                }
                .padding(.top, 8)

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

                    seccaoMetas

                    if !semOrcamento.isEmpty {
                        seccaoSemOrcamento
                    }
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Tema.fundo)
            .navigationTitle("Planear")
            .sheet(isPresented: $mostrarNovaMeta) { FormularioDeMeta(meta: nil) }
            .sheet(item: $metaEmEdicao) { meta in FormularioDeMeta(meta: meta) }
        }
    }

    // MARK: - Metas de poupança

    private var seccaoMetas: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Metas de poupança")
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(metas) { meta in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Label {
                                Text(meta.nome)
                                    .font(.subheadline)
                                    .foregroundStyle(Tema.tinta)
                            } icon: {
                                Image(systemName: meta.simbolo)
                                    .font(.footnote)
                                    .foregroundStyle(Tema.dourado)
                            }
                            Spacer()
                            Text("\(FormatadorDeMoeda.textoEmEurosInteiros(meta.valorPoupado)) / \(FormatadorDeMoeda.textoEmEurosInteiros(meta.valorAlvo)) €")
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        // Progresso rumo à meta: o dourado aqui é conquista.
                        BarraDeProgresso(fracao: fracao(de: meta), dourada: true, altura: 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { metaEmEdicao = meta }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }

                Button("Adicionar meta") { mostrarNovaMeta = true }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Tema.douradoEscuro)
            }
            .padding(.top, 10)
        }
    }

    private func fracao(de meta: Meta) -> Double {
        guard meta.valorAlvo > .zero else { return 0 }
        return (meta.valorPoupado as NSDecimalNumber).doubleValue
            / (meta.valorAlvo as NSDecimalNumber).doubleValue
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

/// Criação e edição de uma meta de poupança. Sem meta é criação;
/// com meta, edita e pode eliminar.
private struct FormularioDeMeta: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let meta: Meta?

    @State private var nome: String
    @State private var simbolo: String
    @State private var valorAlvo: Decimal
    @State private var valorPoupado: Decimal

    private static let simbolos = [
        "target", "shield.fill", "airplane", "house.fill", "car.fill",
        "gift.fill", "graduationcap.fill", "banknote.fill", "heart.fill",
    ]

    init(meta: Meta?) {
        self.meta = meta
        self.nome = meta?.nome ?? ""
        self.simbolo = meta?.simbolo ?? "target"
        self.valorAlvo = meta?.valorAlvo ?? .zero
        self.valorPoupado = meta?.valorPoupado ?? .zero
    }

    private var moeda: Decimal.FormatStyle.Currency {
        .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome (ex.: Viagem)", text: $nome)
                Picker("Símbolo", selection: $simbolo) {
                    ForEach(Self.simbolos, id: \.self) { nome in
                        Image(systemName: nome).tag(nome)
                    }
                }
                LabeledContent("Valor alvo") {
                    TextField("0 €", value: $valorAlvo, format: moeda)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Já poupado") {
                    TextField("0 €", value: $valorPoupado, format: moeda)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                if let meta {
                    Button("Eliminar meta", role: .destructive) {
                        contexto.delete(meta)
                        try? contexto.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle(meta == nil ? "Nova meta" : "Editar meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let meta {
                            meta.nome = nome
                            meta.simbolo = simbolo
                            meta.valorAlvo = valorAlvo
                            meta.valorPoupado = valorPoupado
                        } else {
                            contexto.insert(Meta(
                                nome: nome,
                                valorAlvo: valorAlvo,
                                valorPoupado: valorPoupado,
                                simbolo: simbolo
                            ))
                        }
                        try? contexto.save()
                        dismiss()
                    }
                    .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty || valorAlvo <= .zero)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    OrcamentoView()
        .modelContainer(ContentorDeDados.emMemoria())
}
