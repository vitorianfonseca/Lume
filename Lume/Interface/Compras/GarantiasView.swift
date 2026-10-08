import SwiftData
import SwiftUI

/// As garantias guardadas: as que estão a acabar primeiro, depois as
/// expiradas — para nunca se perder o prazo de acionar uma.
struct GarantiasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Garantia.dataDaCompra, order: .reverse) private var todas: [Garantia]
    @State private var pesquisa = ""
    @State private var novaGarantia = false
    @State private var garantiaEmDetalhe: Garantia?
    @AppStorage("valorMinimoDeGarantia") private var valorMinimoTexto = ""

    private var valorMinimo: Decimal {
        get { Decimal(string: valorMinimoTexto, locale: Locale(identifier: "en_US_POSIX")) ?? RegrasDeGarantia.atuais.valorMinimoPorDefeito }
        nonmutating set { valorMinimoTexto = NSDecimalNumber(decimal: newValue).stringValue }
    }

    private var filtradas: [Garantia] {
        let termo = pesquisa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !termo.isEmpty else { return todas }
        return todas.filter {
            $0.produto.localizedCaseInsensitiveContains(termo)
                || ($0.loja?.localizedCaseInsensitiveContains(termo) ?? false)
        }
    }

    /// As que ainda valem, da mais próxima do fim para a mais longe.
    private var ativas: [Garantia] {
        filtradas.filter { !$0.expirada }.sorted { $0.dataFim < $1.dataFim }
    }

    /// As que já acabaram, da mais recente para a mais antiga.
    private var expiradas: [Garantia] {
        filtradas.filter(\.expirada).sorted { $0.dataFim > $1.dataFim }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(legenda: "O teu dinheiro", titulo: "Garantias")

                if !todas.isEmpty {
                    campoDePesquisa
                }

                if todas.isEmpty {
                    EstadoVazio(
                        ilustracao: .carteira,
                        titulo: "Sem garantias guardadas",
                        texto: "Compras grandes vão aparecer aqui para nunca se perder o prazo de acionar uma garantia."
                    )
                    .padding(.top, 12)
                } else if ativas.isEmpty && expiradas.isEmpty {
                    EstadoVazio(ilustracao: .lupa, titulo: "Nada encontrado", texto: "Tenta outra palavra: produto ou loja.")
                        .padding(.top, 12)
                } else {
                    if !ativas.isEmpty {
                        secao(titulo: "Ativas", garantias: ativas)
                    }
                    if !expiradas.isEmpty {
                        secao(titulo: "Expiradas", garantias: expiradas)
                    }
                }

                BotaoLume(titulo: "Adicionar garantia", simbolo: "plus", estilo: .secundario) { novaGarantia = true }

                preferenciaDeSugestao
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .toolbarBackground(Tema.fundo, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Tema.douradoEscuro)
        .animation(.snappy(duration: 0.2), value: todas.count)
        .sheet(isPresented: $novaGarantia) {
            NovaGarantiaView()
        }
        .sheet(item: $garantiaEmDetalhe) { garantia in
            DetalheDaGarantiaView(garantia: garantia)
        }
    }

    /// A partir de que valor a Lume sugere guardar a garantia, logo
    /// depois de uma compra. Editável aqui, para se ajustar à medida.
    private var preferenciaDeSugestao: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sugerir a partir de")
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                Text("Compras nas categorias certas, a partir deste valor.")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            CampoDeEuros(valor: Binding(
                get: { valorMinimo },
                set: { valorMinimo = $0 }
            ))
        }
        .padding(16)
        .cartao()
    }

    private var campoDePesquisa: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tintaSuave)
            TextField(
                text: $pesquisa,
                prompt: Text("Pesquisar produto ou loja").foregroundStyle(Tema.placeholder)
            ) { Text("Pesquisar") }
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tinta)
                .autocorrectionDisabled()
            if !pesquisa.isEmpty {
                Button { pesquisa = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Tema.fonte(14))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .cartao()
    }

    private func secao(titulo: String, garantias: [Garantia]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Legenda(titulo)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(garantias) { garantia in
                    Button { garantiaEmDetalhe = garantia } label: {
                        linha(garantia)
                    }
                    .buttonStyle(EscalaAoTocar())
                    .contextMenu {
                        Button("Eliminar garantia", role: .destructive) {
                            contexto.delete(garantia)
                            try? contexto.save()
                        }
                    }
                    if garantia.persistentModelID != garantias.last?.persistentModelID {
                        Divider().overlay(Tema.separador)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .cartao()
        }
    }

    private func linha(_ garantia: Garantia) -> some View {
        HStack(spacing: 12) {
            AvatarDeIniciais(texto: garantia.produto, lado: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(garantia.produto)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                    .lineLimit(1)
                Text(garantia.loja ?? FormatadorDeMoeda.texto(garantia.valor))
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            SeloDeGarantia(dataFim: garantia.dataFim)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Uma etiqueta curta com o estado: a acabar em breve (âmbar), expirada
/// (vermelho) ou só a data do fim, sem destaque.
struct SeloDeGarantia: View {
    let dataFim: Date

    private var expirada: Bool { Garantias.expirada(dataFim: dataFim) }
    private var aAproximarSeDoFim: Bool { Garantias.aAproximarSeDoFim(dataFim: dataFim) }

    private var dataPorExtenso: String {
        dataFim.formatted(.dateTime.day().month(.wide).year().locale(FormatadorDeMoeda.localidade))
    }

    var body: some View {
        if expirada {
            etiqueta("Expirada", cor: Tema.negativo, fundo: Tema.fundoNegativo)
        } else if aAproximarSeDoFim {
            etiqueta("Até \(dataPorExtenso)", cor: Tema.aviso, fundo: Tema.fundoDoAviso)
        } else {
            Text("Até \(dataPorExtenso)")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    private func etiqueta(_ texto: String, cor: Color, fundo: Color) -> some View {
        Text(texto)
            .font(Tema.fonte(11, .semibold))
            .foregroundStyle(cor)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(fundo, in: Capsule())
    }
}

/// Adicionar uma garantia à mão, sem partir de uma compra registada.
private struct NovaGarantiaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    @State private var produto = ""
    @State private var loja = ""
    @State private var valor: Decimal = .zero
    @State private var dataDaCompra = Date.now
    @State private var duracaoEmMeses = RegrasDeGarantia.atuais.duracaoLegalEmMeses
    @State private var temPrazoDeDevolucao = false
    @State private var prazoDeDevolucao = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(
                    legenda: "Garantias",
                    titulo: "Nova garantia",
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                VStack(alignment: .leading, spacing: 14) {
                    campo("Produto") {
                        TextField("Produto", text: $produto)
                            .font(Tema.fonte(16, .medium))
                            .foregroundStyle(Tema.tinta)
                    }
                    Divider().overlay(Tema.separador)
                    campo("Loja") {
                        TextField("Opcional", text: $loja)
                            .font(Tema.fonte(16))
                            .foregroundStyle(Tema.tinta)
                    }
                    Divider().overlay(Tema.separador)
                    campo("Valor") {
                        TextField(value: $valor, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                            Text("Valor")
                        }
                        .keyboardType(.decimalPad)
                        .font(Tema.fonte(16, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                    }
                    Divider().overlay(Tema.separador)
                    campo("Data da compra") {
                        DatePicker("Data da compra", selection: $dataDaCompra, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                            .font(Tema.fonte(14))
                    }
                    Divider().overlay(Tema.separador)
                    campo("Duração da garantia") {
                        Stepper(value: $duracaoEmMeses, in: 1...60) {
                            Text("\(duracaoEmMeses) meses")
                                .font(Tema.fonte(16))
                                .foregroundStyle(Tema.tinta)
                        }
                    }
                    Divider().overlay(Tema.separador)
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Tem prazo de devolução", isOn: $temPrazoDeDevolucao)
                            .font(Tema.fonte(14, .medium))
                            .foregroundStyle(Tema.tinta)
                            .tint(Tema.dourado)
                        if temPrazoDeDevolucao {
                            DatePicker("Até", selection: $prazoDeDevolucao, displayedComponents: .date)
                                .font(Tema.fonte(14))
                                .foregroundStyle(Tema.tinta)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartao()
                .animation(.snappy(duration: 0.2), value: temPrazoDeDevolucao)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) {
            BotaoLume(titulo: "Guardar garantia", simbolo: "checkmark") { guardar() }
                .disabled(produto.trimmingCharacters(in: .whitespaces).isEmpty || valor <= .zero)
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Tema.fundo)
        }
    }

    private func campo(_ legenda: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Legenda(legenda)
            conteudo()
        }
    }

    private func guardar() {
        let garantia = Garantia(
            produto: produto.trimmingCharacters(in: .whitespacesAndNewlines),
            loja: loja.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : loja,
            dataDaCompra: dataDaCompra,
            valor: valor,
            duracaoEmMeses: duracaoEmMeses,
            prazoDeDevolucao: temPrazoDeDevolucao ? prazoDeDevolucao : nil
        )
        contexto.insert(garantia)
        try? contexto.save()
        Task { await NotificadorDeGarantias.agendar(garantia) }
        SomDoSistema.sucesso.tocar()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GarantiasView()
    }
    .modelContainer(ContentorDeDados.emMemoria())
}
