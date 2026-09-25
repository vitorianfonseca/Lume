import PhotosUI
import SwiftData
import SwiftUI

/// Modo de entrada do registo — texto, voz ou talão.
enum ModoDeRegisto: String, CaseIterable, Identifiable {
    case texto = "Texto"
    case voz = "Voz"
    case talao = "Talão"

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .texto: "textformat"
        case .voz: "mic"
        case .talao: "camera"
        }
    }

    var legenda: String {
        switch self {
        case .texto: "UMA FRASE É SUFICIENTE"
        case .voz: "FALA NATURALMENTE"
        case .talao: "FOTOGRAFA. CONFIRMA. FEITO."
        }
    }

    var titulo: String {
        switch self {
        case .texto: "Registar despesa"
        case .voz: "Registar por voz"
        case .talao: "Digitalizar talão"
        }
    }
}

/// O ecrã Registar do novo design, fiel aos três frames do Figma:
/// texto ("uma frase é suficiente"), voz ("estou a ouvir…" com onda e
/// transcrição em tempo real) e talão (digitalizar e confirmar).
struct RegistarView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query private var transacoes: [Transacao]

    @Binding var modo: ModoDeRegisto

    @State private var viewModel = HojeViewModel()
    @State private var gravador = GravadorDeVoz()
    @State private var fotoDeTalao: PhotosPickerItem?
    @State private var proposta: PropostaDeTransacao?
    /// Leitura ao vivo da transcrição (valor + categoria), como no frame.
    @State private var propostaEmDireto: PropostaDeTransacao?
    @State private var contaEscolhida: Conta?
    @State private var inicioDaGravacao: Date?
    @State private var mostrarFototeca = false
    @State private var mostrarGuardado = false
    @FocusState private var campoFocado: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cabecalho
                seletorDeModo
                entrada
                if viewModel.aInterpretar {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if proposta != nil {
                    percebido
                }
                if let mensagem = viewModel.mensagemDeErro {
                    Text(mensagem)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: viewModel.gravacoes)
        .overlay(alignment: .bottom) {
            if mostrarGuardado {
                Label(viewModel.resumoDaGravacao, systemImage: "checkmark")
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.positivo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Tema.superficie, in: Capsule())
                    .overlay(Capsule().strokeBorder(Tema.separador, lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: viewModel.proposta) {
            proposta = viewModel.proposta
        }
        .onChange(of: viewModel.gravacoes) {
            AccessibilityNotification.Announcement(viewModel.resumoDaGravacao).post()
            withAnimation(.snappy) { mostrarGuardado = true }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut) { mostrarGuardado = false }
            }
        }
        .onChange(of: fotoDeTalao) {
            guard let item = fotoDeTalao else { return }
            fotoDeTalao = nil
            Task {
                guard let dados = try? await item.loadTransferable(type: Data.self) else { return }
                await viewModel.interpretarTalao(dados, categorias: categorias)
            }
        }
        .onChange(of: modo) {
            // Trocar de modo recomeça o registo — o "Percebido" de um modo
            // não pode ficar pendurado debaixo dos painéis dos outros.
            if gravador.aGravar { pararVoz() }
            proposta = nil
            viewModel.proposta = nil
            viewModel.mensagemDeErro = nil
        }
        .onChange(of: gravador.transcricao) {
            guard gravador.aGravar else { return }
            viewModel.textoDeRegisto = gravador.transcricao
            let texto = gravador.transcricao
            let nomes = categorias.map(\.nome)
            Task {
                propostaEmDireto = texto.isEmpty
                    ? nil
                    : try? await InterpretadorPorRegras().interpretar(texto, categorias: nomes, hoje: .now)
            }
        }
    }

    // MARK: - Cabeçalho e seletor

    /// Depois de uma gravação de voz, o ecrã passa a "Rever despesa" (ecrã 09).
    private var aReverVoz: Bool {
        proposta != nil && viewModel.origemDoRegisto == .voz && modo == .voz
    }

    private var cabecalho: some View {
        CabecalhoDeEcra(
            legenda: aReverVoz ? "REGISTADO POR VOZ" : modo.legenda,
            titulo: aReverVoz ? "Rever despesa" : modo.titulo
        )
        .animation(.snappy, value: modo)
    }

    private func moedaDaMarca(_ tamanho: CGFloat) -> some View {
        // A logo nova da Lume — o símbolo dourado do Figma.
        Image("SimboloLume")
            .resizable()
            .scaledToFit()
            .frame(width: tamanho, height: tamanho)
            .accessibilityHidden(true)
    }

    private var seletorDeModo: some View {
        HStack(spacing: 8) {
            ForEach(ModoDeRegisto.allCases) { opcao in
                Button {
                    withAnimation(.snappy) { modo = opcao }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: opcao.simbolo)
                            .font(Tema.fonte(12))
                        Text(opcao.rawValue)
                            .font(Tema.fonte(13, modo == opcao ? .semibold : .regular))
                    }
                    .foregroundStyle(modo == opcao ? Tema.douradoEscuro : Tema.tintaSuave)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(
                        modo == opcao ? AnyShapeStyle(Tema.areia) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: Tema.Raio.chip)
                    )
                }
                .accessibilityAddTraits(modo == opcao ? [.isSelected] : [])
            }
            Spacer()
        }
    }

    // MARK: - Entrada por modo

    @ViewBuilder
    private var entrada: some View {
        switch modo {
        case .texto: entradaDeTexto
        case .voz:
            // No ecrã "Rever despesa", o painel dá lugar ao cartão "DISSESTE".
            if aReverVoz {
                disseste
            } else {
                entradaDeVoz
            }
        case .talao: entradaDeTalao
        }
    }

    /// O cartão areia do ecrã 09 com a frase gravada.
    private var disseste: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISSESTE")
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.douradoEscuro)
            Text("“\(viewModel.textoDeRegisto)”")
                .font(Tema.fonte(18, .semibold))
                .foregroundStyle(Tema.tinta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
    }

    private var entradaDeTexto: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("O que gastaste?")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
            TextField("Gastei 12,50 no almoço…", text: $viewModel.textoDeRegisto, axis: .vertical)
                .font(Tema.fonte(21, .medium))
                .foregroundStyle(Tema.tinta)
                .lineLimit(2...4)
                .focused($campoFocado)
                .submitLabel(.done)
                .onSubmit { interpretar() }

            // Como no frame: hora à esquerda, o "T" dourado à direita.
            HStack {
                Text("Hoje, \(Date.now.formatted(.dateTime.hour().minute().locale(FormatadorDeMoeda.localidade)))")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                Image(systemName: "textformat")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.douradoEscuro)
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
    }

    private var entradaDeVoz: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                moedaDaMarca(44)
                Text(gravador.aGravar ? "Estou a ouvir…" : "Toca em começar e fala")
                    .font(Tema.fonte(17, .semibold))
                    .foregroundStyle(Tema.tinta)

                if gravador.aGravar {
                    BarrasDeVoz()
                        .frame(height: 34)
                    if let inicio = inicioDaGravacao {
                        TimelineView(.periodic(from: inicio, by: 1)) { contextoDeTempo in
                            let segundos = max(0, Int(contextoDeTempo.date.timeIntervalSince(inicio)))
                            Text(String(format: "%02d:%02d", segundos / 60, segundos % 60))
                                .font(Tema.fonte(12, .medium))
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                    }
                }

                if case .indisponivel(let motivo) = gravador.estado {
                    Text(motivo)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))

            if gravador.aGravar, !viewModel.textoDeRegisto.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRANSCRIÇÃO EM TEMPO REAL")
                        .font(Tema.fonte(11))
                        .foregroundStyle(Tema.tintaSuave)
                    Text("“\(viewModel.textoDeRegisto)”")
                        .font(Tema.fonte(18, .semibold))
                        .foregroundStyle(Tema.tinta)

                    // O valor e a categoria percebidos ao vivo, como no frame.
                    if let direto = propostaEmDireto, direto.valor > 0 {
                        HStack(spacing: 10) {
                            Text(FormatadorDeMoeda.texto(direto.valor))
                                .font(Tema.fonte(12, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Tema.douradoEscuro)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Tema.areia, in: Capsule())
                            if let categoria = direto.nomeDaCategoria {
                                Text(categoria)
                                    .font(Tema.fonte(12))
                                    .foregroundStyle(Tema.tintaSuave)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            botaoDeAcao(gravador.aGravar ? "Terminar e rever" : "Começar a falar") {
                Task {
                    if gravador.aGravar {
                        pararVoz()
                        interpretar(origem: .voz)
                    } else {
                        await gravador.alternar()
                        if gravador.aGravar { inicioDaGravacao = .now }
                    }
                }
            }

            Text("A despesa só é guardada depois de confirmares.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
                .frame(maxWidth: .infinity)
        }
        .animation(.snappy, value: gravador.aGravar)
    }

    private var entradaDeTalao: some View {
        VStack(spacing: 16) {
            // O painel do frame: um talão de exemplo dentro do painel areia.
            talaoDeExemplo
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))

            if proposta == nil {
                botaoDeAcao("Fotografar ou escolher talão") { mostrarFototeca = true }
                    .photosPicker(isPresented: $mostrarFototeca, selection: $fotoDeTalao, matching: .images)

                Text("A fotografia fica associada ao movimento.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// O talão ilustrativo do frame, tal e qual.
    private var talaoDeExemplo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PINGO DOCE")
                .font(Tema.fonte(12, .semibold))
                .foregroundStyle(Tema.tinta)
            Text("Lisboa · 24/09/2026 · 11:42")
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
            Divider().overlay(Tema.separador)
            linhaDeTalao("Pão alentejano", "1,89 €")
            linhaDeTalao("Iogurte natural × 4", "2,38 €")
            linhaDeTalao("Tomate cherry", "2,49 €")
            linhaDeTalao("Salmão fresco", "12,90 €")
            linhaDeTalao("Azeite virgem extra", "9,00 €")
            Divider().overlay(Tema.separador)
            HStack {
                Text("TOTAL")
                    .font(Tema.fonte(12, .semibold))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Text("28,64 €")
                    .font(Tema.fonte(17, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
            }
        }
        .padding(16)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private func linhaDeTalao(_ nome: String, _ valor: String) -> some View {
        HStack {
            Text(nome)
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(valor)
                .font(Tema.fonte(12))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
        }
    }

    // MARK: - Percebido / reconhecido

    private var tituloDoReconhecimento: String {
        viewModel.origemDoRegisto == .talao
            ? "Talão reconhecido"
            : "Percebido. Confirma os detalhes."
    }

    private var textoDoBotaoGuardar: String {
        switch viewModel.origemDoRegisto {
        case .talao: "Confirmar e guardar"
        case .voz: "Confirmar despesa"
        default: "Guardar despesa"
        }
    }

    /// O cartão areia "Depois desta despesa" do ecrã 09: o limite da
    /// categoria depois de contar o valor proposto.
    @ViewBuilder
    private func depoisDaDespesa(_ atual: PropostaDeTransacao) -> some View {
        if atual.tipo == .despesa,
           let categoria = categorias.first(where: { $0.nome == atual.nomeDaCategoria }),
           let orcamento = categoria.orcamentoMensal, orcamento > .zero {
            let calendario = Calendar.current
            let gastoAtual = transacoes
                .filter {
                    $0.tipo == .despesa
                        && $0.categoria?.persistentModelID == categoria.persistentModelID
                        && calendario.isDate($0.data, equalTo: .now, toGranularity: .month)
                }
                .reduce(Decimal.zero) { $0 + $1.valor }
            let depois = gastoAtual + atual.valor
            let restante = orcamento - depois

            VStack(alignment: .leading, spacing: 4) {
                Text("Depois desta despesa")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("\(categoria.nome): \(FormatadorDeMoeda.texto(depois)) de \(FormatadorDeMoeda.textoEmEurosInteiros(orcamento)) €")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                Text(restante >= .zero
                    ? "Ficam \(FormatadorDeMoeda.texto(restante)) disponíveis."
                    : "Passas o limite em \(FormatadorDeMoeda.texto(-restante)).")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        }
    }

    @ViewBuilder
    private var percebido: some View {
        if let atual = proposta {
            let ligacaoProposta = Binding(
                get: { proposta ?? atual },
                set: { proposta = $0 }
            )
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(tituloDoReconhecimento, systemImage: "checkmark")
                        .font(Tema.fonte(13, .medium))
                        .foregroundStyle(Tema.positivo)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Descrição", text: ligacaoProposta.descricao)
                            .font(Tema.fonte(17, .semibold))
                            .foregroundStyle(Tema.tinta)
                        Image(systemName: "creditcard")
                            .font(Tema.fonte(13))
                            .foregroundStyle(Tema.douradoEscuro)
                    }

                    TextField(
                        "Valor",
                        value: ligacaoProposta.valor,
                        format: .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
                    )
                    .keyboardType(.decimalPad)
                    .font(Tema.fonte(34, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)

                    Divider().overlay(Tema.separador)

                    linhaDeDetalhe("Categoria", simbolo: "square.grid.2x2") {
                        Picker("Categoria", selection: ligacaoProposta.nomeDaCategoria) {
                            Text("Sem categoria").tag(String?.none)
                            ForEach(categorias) { categoria in
                                Text(categoria.nome).tag(String?.some(categoria.nome))
                            }
                        }
                        .labelsHidden()
                        .tint(Tema.tinta)
                        .fixedSize()
                    }

                    linhaDeDetalhe("Data", simbolo: "calendar") {
                        DatePicker("", selection: ligacaoProposta.data, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, FormatadorDeMoeda.localidade)
                    }

                    linhaDeDetalhe("Conta", simbolo: "creditcard") {
                        Picker("Conta", selection: $contaEscolhida) {
                            ForEach(contas) { conta in
                                Text(conta.nome).tag(Conta?.some(conta))
                            }
                        }
                        .labelsHidden()
                        .tint(Tema.tinta)
                        .fixedSize()
                    }
                }
                .padding(18)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )

                if aReverVoz {
                    depoisDaDespesa(atual)
                }

                botaoDeAcao(textoDoBotaoGuardar, acao: guardar)

                if aReverVoz {
                    // Deitar fora a proposta e voltar ao painel de gravação.
                    Button("Voltar à gravação") {
                        proposta = nil
                        viewModel.proposta = nil
                    }
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.douradoEscuro)
                    .frame(maxWidth: .infinity)
                } else {
                    Text(
                        viewModel.origemDoRegisto == .talao
                            ? "A fotografia fica associada ao movimento."
                            : "Podes rever e corrigir tudo antes de guardar."
                    )
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity)
                }
            }
            .onAppear {
                if contaEscolhida == nil {
                    contaEscolhida = contas.first(where: \.principal) ?? contas.first
                }
            }
        }
    }

    // MARK: - Peças e ações

    /// Linha do cartão de detalhes, como no frame: ícone + etiqueta à
    /// esquerda, o controlo de edição à direita.
    private func linhaDeDetalhe(
        _ titulo: String,
        simbolo: String,
        @ViewBuilder controlo: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: simbolo)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            Text(titulo)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            controlo()
        }
    }

    private func botaoDeAcao(_ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo)
                .font(Tema.fonte(15, .semibold))
                .foregroundStyle(Color(hex: "302B24"))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        }
    }

    private func pararVoz() {
        gravador.parar()
        inicioDaGravacao = nil
        propostaEmDireto = nil
    }

    private func interpretar(origem: OrigemTransacao = .texto) {
        campoFocado = false
        Task { await viewModel.interpretar(categorias: categorias, origem: origem) }
    }

    private func guardar() {
        guard let proposta else { return }
        viewModel.confirmar(
            proposta,
            categorias: categorias,
            contas: contas,
            contexto: contexto,
            conta: contaEscolhida
        )
        self.proposta = nil
    }
}

/// A onda de voz do frame: barras douradas a "respirar" enquanto grava.
private struct BarrasDeVoz: View {
    var body: some View {
        TimelineView(.animation) { contextoDeTempo in
            let tempo = contextoDeTempo.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<26, id: \.self) { indice in
                    let fase = tempo * 5 + Double(indice) * 0.9
                    let altura = 8 + 22 * abs(sin(fase)) * (0.4 + 0.6 * abs(sin(Double(indice) * 1.7)))
                    Capsule()
                        .fill(Tema.douradoEscuro)
                        .frame(width: 3, height: altura)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Texto") {
    RegistarView(modo: .constant(.texto))
        .modelContainer(ContentorDeDados.emMemoria())
}

#Preview("Voz") {
    RegistarView(modo: .constant(.voz))
        .modelContainer(ContentorDeDados.emMemoria())
}

#Preview("Talão") {
    RegistarView(modo: .constant(.talao))
        .modelContainer(ContentorDeDados.emMemoria())
}
