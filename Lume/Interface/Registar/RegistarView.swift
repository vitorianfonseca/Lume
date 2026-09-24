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
}

/// O ecrã Registar do novo design: uma frase é suficiente. Escolhe-se o
/// modo (texto, voz, talão), a interpretação aparece inline ("Percebido")
/// com os detalhes editáveis, e o "Guardar despesa" fecha o ciclo.
struct RegistarView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Conta.nome) private var contas: [Conta]

    @Binding var modo: ModoDeRegisto

    @State private var viewModel = HojeViewModel()
    @State private var gravador = GravadorDeVoz()
    @State private var fotoDeTalao: PhotosPickerItem?
    @State private var proposta: PropostaDeTransacao?
    @State private var contaEscolhida: Conta?
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
                        .font(.footnote)
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
                    .font(.footnote.weight(.medium))
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
            if gravador.aGravar { gravador.parar() }
        }
        .onChange(of: gravador.transcricao) {
            guard gravador.aGravar else { return }
            viewModel.textoDeRegisto = gravador.transcricao
        }
    }

    // MARK: - Cabeçalho e seletor

    private var cabecalho: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("UMA FRASE É SUFICIENTE")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(Tema.tintaSuave)
                Text("Registar despesa")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Tema.tinta)
            }
            Spacer()
            Circle()
                .fill(Tema.douradoPolido)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "sun.max.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
        }
    }

    private var seletorDeModo: some View {
        HStack(spacing: 8) {
            ForEach(ModoDeRegisto.allCases) { opcao in
                Button {
                    withAnimation(.snappy) { modo = opcao }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: opcao.simbolo)
                            .font(.caption)
                        Text(opcao.rawValue)
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(modo == opcao ? Tema.tinta : Tema.tintaSuave)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(modo == opcao ? AnyShapeStyle(Tema.bege) : AnyShapeStyle(.clear), in: Capsule())
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
        case .voz: entradaDeVoz
        case .talao: entradaDeTalao
        }
    }

    private var entradaDeTexto: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("O que gastaste?")
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
            TextField("Gastei 12,50 no almoço…", text: $viewModel.textoDeRegisto, axis: .vertical)
                .font(.title3)
                .foregroundStyle(Tema.tinta)
                .lineLimit(2...4)
                .focused($campoFocado)
                .submitLabel(.done)
                .onSubmit { interpretar() }
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
        VStack(spacing: 14) {
            Button {
                Task {
                    await gravador.alternar()
                    if !gravador.aGravar { interpretar(origem: .voz) }
                }
            } label: {
                Image(systemName: gravador.aGravar ? "waveform" : "mic")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: "38342E"))
                    .frame(width: 72, height: 72)
                    .background(Tema.douradoPolido, in: Circle())
                    .symbolEffect(.variableColor.iterative, isActive: gravador.aGravar)
            }
            .accessibilityLabel(gravador.aGravar ? "Parar e registar" : "Começar a ditar")

            Text(gravador.aGravar
                ? (viewModel.textoDeRegisto.isEmpty ? "A ouvir…" : viewModel.textoDeRegisto)
                : "Toca e diz o que gastaste")
                .font(.subheadline)
                .foregroundStyle(Tema.tintaSuave)
                .multilineTextAlignment(.center)

            if case .indisponivel(let motivo) = gravador.estado {
                Text(motivo)
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(gravador.aGravar ? Tema.dourado : Tema.separador, lineWidth: 1)
        )
    }

    private var entradaDeTalao: some View {
        PhotosPicker(selection: $fotoDeTalao, matching: .images) {
            VStack(spacing: 10) {
                Image(systemName: "doc.viewfinder")
                    .font(.title)
                    .foregroundStyle(Tema.douradoEscuro)
                Text("Escolhe uma foto do talão")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Tema.tinta)
                Text("A Lume lê a loja e o total; confirmas antes de guardar.")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                    .strokeBorder(Tema.separador, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .accessibilityLabel("Escolher foto do talão")
    }

    // MARK: - Percebido

    @ViewBuilder
    private var percebido: some View {
        if let atual = proposta {
            let ligacaoProposta = Binding(
                get: { proposta ?? atual },
                set: { proposta = $0 }
            )
            VStack(alignment: .leading, spacing: 14) {
                Label("Percebido. Confirma os detalhes.", systemImage: "checkmark")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Tema.positivo)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Descrição", text: ligacaoProposta.descricao)
                        .font(.headline)
                        .foregroundStyle(Tema.tinta)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if atual.tipo == .despesa {
                            Text("−")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Tema.tinta)
                        }
                        TextField(
                            "Valor",
                            value: ligacaoProposta.valor,
                            format: .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
                        )
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                    }

                    Divider().overlay(Tema.separador)

                    LabeledContent("Categoria") {
                        Picker("Categoria", selection: ligacaoProposta.nomeDaCategoria) {
                            Text("Sem categoria").tag(String?.none)
                            ForEach(categorias) { categoria in
                                Text(categoria.nome).tag(String?.some(categoria.nome))
                            }
                        }
                        .labelsHidden()
                        .tint(Tema.tinta)
                    }
                    .font(.subheadline)

                    LabeledContent("Data") {
                        DatePicker("", selection: ligacaoProposta.data, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .font(.subheadline)

                    LabeledContent("Conta") {
                        Picker("Conta", selection: $contaEscolhida) {
                            ForEach(contas) { conta in
                                Text(conta.nome).tag(Conta?.some(conta))
                            }
                        }
                        .labelsHidden()
                        .tint(Tema.tinta)
                    }
                    .font(.subheadline)
                }
                .padding(18)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )

                Button(action: guardar) {
                    Text("Guardar despesa")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "38342E"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Tema.douradoPolido, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                }

                Text("Podes rever e corrigir tudo antes de guardar.")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity)
            }
            .onAppear {
                if contaEscolhida == nil {
                    contaEscolhida = contas.first(where: \.principal) ?? contas.first
                }
            }
        }
    }

    // MARK: - Ações

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

#Preview {
    RegistarView(modo: .constant(.texto))
        .modelContainer(ContentorDeDados.emMemoria())
}
