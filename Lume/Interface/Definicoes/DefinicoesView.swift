import SwiftUI
import SwiftData

/// Rendimento e poupança do mês, contas, categorias e recorrentes.
struct DefinicoesView: View {
    @Environment(\.modelContext) private var contexto
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]

    @State private var mostrarNovaConta = false
    @State private var mostrarNovaCategoria = false
    @State private var mostrarNovaRecorrente = false
    /// 0 = mês atual; recuar 1 para corrigir, avançar até 6 para planear.
    @State private var deslocacaoDeMes = 0
    @State private var confirmarApagarMovimentos = false
    @State private var confirmarReposicao = false

    var body: some View {
        NavigationStack {
            Form {
                seccaoDoMesSelecionado
                seccaoContas
                seccaoCategorias
                seccaoRecorrentes
                seccaoDados
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fundo)
            .navigationTitle("Definições")
            .onAppear { garantirDefinicoes(para: dataSelecionada) }
            .onChange(of: deslocacaoDeMes) { garantirDefinicoes(para: dataSelecionada) }
            .sheet(isPresented: $mostrarNovaConta) { FormularioDeConta() }
            .sheet(isPresented: $mostrarNovaCategoria) { FormularioDeCategoria(proximaOrdem: categorias.count) }
            .sheet(isPresented: $mostrarNovaRecorrente) { FormularioDeRecorrente(categorias: categorias) }
            .confirmationDialog("Apagar todos os movimentos?", isPresented: $confirmarApagarMovimentos, titleVisibility: .visible) {
                Button("Apagar movimentos", role: .destructive, action: apagarMovimentos)
            } message: {
                Text("As contas, categorias e recorrentes ficam.")
            }
            .confirmationDialog("Repor a app?", isPresented: $confirmarReposicao, titleVisibility: .visible) {
                Button("Apagar tudo", role: .destructive, action: reporApp)
            } message: {
                Text("Apaga todos os dados. Não há volta a dar.")
            }
        }
    }

    // MARK: - Definições do mês

    private var dataSelecionada: Date {
        Calendar.current.date(byAdding: .month, value: deslocacaoDeMes, to: .now) ?? .now
    }

    private var definicoesSelecionadas: DefinicoesDoMes? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: dataSelecionada)
        let mes = calendario.component(.month, from: dataSelecionada)
        return definicoes.first { $0.ano == ano && $0.mes == mes }
    }

    /// Sem `@Attribute(.unique)` (CloudKit), a unicidade é garantida aqui:
    /// procurar antes de inserir.
    private func garantirDefinicoes(para data: Date) {
        guard definicoesSelecionadas == nil else { return }
        let calendario = Calendar.current
        contexto.insert(DefinicoesDoMes(
            ano: calendario.component(.year, from: data),
            mes: calendario.component(.month, from: data)
        ))
        try? contexto.save()
    }

    private var tituloDoMes: String {
        deslocacaoDeMes == 0
            ? "Este mês"
            : dataSelecionada.formatted(.dateTime.month(.wide).year().locale(FormatadorDeMoeda.localidade))
    }

    private var seccaoDoMesSelecionado: some View {
        Section {
            HStack {
                Button { deslocacaoDeMes -= 1 } label: { Image(systemName: "chevron.left") }
                    .disabled(deslocacaoDeMes <= -1)
                Spacer()
                Text(tituloDoMes)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Button { deslocacaoDeMes += 1 } label: { Image(systemName: "chevron.right") }
                    .disabled(deslocacaoDeMes >= 6)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Tema.douradoEscuro)

            if let selecionadas = definicoesSelecionadas {
                CamposDoMes(definicoes: selecionadas)
            }
        } header: {
            Text("Rendimento e poupança")
        } footer: {
            Text("O número diário nasce daqui: rendimento − poupança − contas fixas − o que já gastaste. Começaste a meio do mês? Indica só o que ainda esperas receber até ao fim do mês — a Lume divide sempre pelos dias que faltam. Usa as setas para planear o próximo mês.")
        }
        .listRowBackground(Tema.superficie)
    }

    // MARK: - Dados

    private var seccaoDados: some View {
        Section {
            Button("Apagar todos os movimentos", role: .destructive) { confirmarApagarMovimentos = true }
            Button("Repor a app", role: .destructive) { confirmarReposicao = true }
        } header: {
            Text("Dados")
        } footer: {
            Text("Repor a app apaga movimentos, recorrentes, categorias, contas, metas e definições dos meses.")
        }
        .listRowBackground(Tema.superficie)
    }

    private func apagarMovimentos() {
        try? contexto.delete(model: Transacao.self)
        try? contexto.save()
    }

    private func reporApp() {
        try? contexto.delete(model: Transacao.self)
        try? contexto.delete(model: Recorrente.self)
        try? contexto.delete(model: Meta.self)
        try? contexto.delete(model: Categoria.self)
        try? contexto.delete(model: Conta.self)
        try? contexto.delete(model: DefinicoesDoMes.self)
        try? contexto.save()
        // Volta a haver um registo vazio para o mês visível.
        garantirDefinicoes(para: dataSelecionada)
    }

    // MARK: - Secções

    private var seccaoContas: some View {
        Section("Contas") {
            ForEach(contas) { conta in
                LabeledContent {
                    Text(FormatadorDeMoeda.texto(conta.saldoAtual))
                        .monospacedDigit()
                } label: {
                    Text(conta.nome)
                    Text(conta.tipo.nome)
                }
            }
            .onDelete { indices in
                indices.map { contas[$0] }.forEach(contexto.delete)
                try? contexto.save()
            }

            Button("Adicionar conta") { mostrarNovaConta = true }
                .foregroundStyle(Tema.douradoEscuro)
        }
        .listRowBackground(Tema.superficie)
    }

    private var seccaoCategorias: some View {
        Section("Categorias") {
            ForEach(categorias) { categoria in
                LabeledContent {
                    Text(categoria.orcamentoMensal.map(FormatadorDeMoeda.texto) ?? "—")
                        .monospacedDigit()
                } label: {
                    Label {
                        Text(categoria.nome)
                    } icon: {
                        Image(systemName: categoria.simbolo)
                            .foregroundStyle(categoria.cor)
                    }
                }
            }
            .onDelete { indices in
                indices.map { categorias[$0] }.forEach(contexto.delete)
                try? contexto.save()
            }

            Button("Adicionar categoria") { mostrarNovaCategoria = true }
                .foregroundStyle(Tema.douradoEscuro)
        }
        .listRowBackground(Tema.superficie)
    }

    private var seccaoRecorrentes: some View {
        Section {
            ForEach(recorrentes) { recorrente in
                LinhaDeRecorrenteEditavel(recorrente: recorrente)
            }
            .onDelete { indices in
                indices.map { recorrentes[$0] }.forEach(contexto.delete)
                try? contexto.save()
            }

            Button("Adicionar recorrente") { mostrarNovaRecorrente = true }
                .foregroundStyle(Tema.douradoEscuro)
        } header: {
            Text("Contas fixas e subscrições")
        } footer: {
            Text("As recorrentes ativas são descontadas ao mês inteiro no cálculo do número diário.")
        }
        .listRowBackground(Tema.superficie)
    }
}

// MARK: - Linhas e secções com binding

private struct CamposDoMes: View {
    @Bindable var definicoes: DefinicoesDoMes

    var body: some View {
        Group {
            LabeledContent("Rendimento esperado") {
                TextField("0 €", value: $definicoes.rendimentoEsperado, format: moeda)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    // Largura fixa para o label não ficar truncado.
                    .frame(width: 110)
            }
            LabeledContent("Poupança planeada") {
                TextField("0 €", value: $definicoes.poupancaPlaneada, format: moeda)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
        }
    }
}

private struct LinhaDeRecorrenteEditavel: View {
    @Bindable var recorrente: Recorrente

    var body: some View {
        Toggle(isOn: $recorrente.ativa) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recorrente.nome)
                Text("dia \(recorrente.diaDoMes) · \(FormatadorDeMoeda.texto(recorrente.valor))")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .tint(Tema.dourado)
    }
}

// MARK: - Formulários

private var moeda: Decimal.FormatStyle.Currency {
    .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
}

private struct FormularioDeConta: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    @State private var nome = ""
    @State private var tipo = TipoConta.aOrdem
    @State private var saldoInicial = Decimal.zero

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome (ex.: Revolut)", text: $nome)
                Picker("Tipo", selection: $tipo) {
                    ForEach(TipoConta.allCases, id: \.self) { Text($0.nome).tag($0) }
                }
                LabeledContent("Saldo inicial") {
                    TextField("0 €", value: $saldoInicial, format: moeda)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle("Nova conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        contexto.insert(Conta(nome: nome, tipo: tipo, saldoInicial: saldoInicial))
                        try? contexto.save()
                        dismiss()
                    }
                    .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct FormularioDeCategoria: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let proximaOrdem: Int

    @State private var nome = ""
    @State private var simbolo = "tag"
    @State private var orcamento = Decimal.zero

    private static let simbolos = [
        "tag", "cart.fill", "fork.knife", "tram.fill", "house.fill",
        "play.rectangle.fill", "cross.case.fill", "ticket.fill",
        "gift.fill", "pawprint.fill", "book.fill", "tshirt.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome (ex.: Animais)", text: $nome)
                Picker("Símbolo", selection: $simbolo) {
                    ForEach(Self.simbolos, id: \.self) { nome in
                        Image(systemName: nome).tag(nome)
                    }
                }
                LabeledContent("Orçamento mensal") {
                    TextField("Opcional", value: $orcamento, format: moeda)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle("Nova categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        contexto.insert(Categoria(
                            nome: nome,
                            simbolo: simbolo,
                            corHex: "716D65",
                            orcamentoMensal: orcamento > .zero ? orcamento : nil,
                            ordem: proximaOrdem
                        ))
                        try? contexto.save()
                        dismiss()
                    }
                    .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct FormularioDeRecorrente: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let categorias: [Categoria]

    @State private var nome = ""
    @State private var valor = Decimal.zero
    @State private var diaDoMes = 1
    @State private var categoria: Categoria?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome (ex.: Ginásio)", text: $nome)
                LabeledContent("Valor") {
                    TextField("0 €", value: $valor, format: moeda)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Stepper("Dia do mês: \(diaDoMes)", value: $diaDoMes, in: 1...31)
                Picker("Categoria", selection: $categoria) {
                    Text("Sem categoria").tag(Categoria?.none)
                    ForEach(categorias) { categoria in
                        Text(categoria.nome).tag(Categoria?.some(categoria))
                    }
                }
            }
            .navigationTitle("Nova recorrente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        contexto.insert(Recorrente(
                            nome: nome,
                            valor: valor,
                            diaDoMes: diaDoMes,
                            categoria: categoria
                        ))
                        try? contexto.save()
                        dismiss()
                    }
                    .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty || valor <= .zero)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    DefinicoesView()
        .modelContainer(ContentorDeDados.emMemoria())
}
