import PhotosUI
import SwiftData
import SwiftUI

/// O ecrã de confirmação com os campos interpretados.
/// É a fronteira entre a IA e os dados: nada é gravado sem o utilizador
/// confirmar aqui. Também serve para editar um movimento existente
/// (título e botão próprios, mais a opção de eliminar).
///
/// Estrutura (auditoria UX): barra "Cancelar · Título · Guardar", a frase
/// original pequena, o título e o valor visivelmente editáveis e um só
/// padrão de linha (rótulo à esquerda, valor + chevron à direita) para
/// Categoria, Tipo, Data e Conta.
struct CartaoDeConfirmacaoView: View {
    private enum Campo: Hashable {
        case descricao
        case loja
        case valor
    }

    let categorias: [Categoria]
    let titulo: String
    let textoDeConfirmacao: String
    let aoConfirmar: (PropostaDeTransacao) -> Void
    let aoCancelar: () -> Void
    let aoEliminar: (() -> Void)?
    /// A frase que a pessoa escreveu ou disse, para confirmar que a Lume
    /// percebeu bem ("“Gastei 12,50 no almoço”").
    let fraseOriginal: String?
    /// Chamado com a conta escolhida imediatamente antes de `aoConfirmar`.
    /// Sem ele (e sem `conta`), a linha Conta não aparece.
    let aoEscolherConta: ((Conta?) -> Void)?

    @Query(sort: \Conta.nome) private var contas: [Conta]

    // Sem valor inicial na declaração: com o @State como macro (SDK 27),
    // o valor é atribuído uma única vez no init.
    @State private var proposta: PropostaDeTransacao
    @State private var contaEscolhida: Conta?
    /// A categoria que a Lume propôs; enquanto for a escolhida, leva a
    /// etiqueta "sugerido".
    @State private var categoriaSugerida: String?
    /// O valor em texto enquanto se escreve, para o modelo acompanhar cada
    /// tecla (o `TextField(value:)` só grava ao sair do campo).
    @State private var textoDoValor: String
    @State private var mostrarCalendario: Bool
    @State private var confirmarEliminacao: Bool
    @State private var talaoEscolhido: PhotosPickerItem?
    @FocusState private var focado: Campo?

    init(
        proposta: PropostaDeTransacao,
        categorias: [Categoria],
        titulo: String = "PERCEBIDO",
        textoDeConfirmacao: String = "Confirmar",
        aoConfirmar: @escaping (PropostaDeTransacao) -> Void,
        aoCancelar: @escaping () -> Void,
        aoEliminar: (() -> Void)? = nil,
        fraseOriginal: String? = nil,
        conta: Conta? = nil,
        aoEscolherConta: ((Conta?) -> Void)? = nil
    ) {
        self.categorias = categorias
        self.titulo = titulo
        self.textoDeConfirmacao = textoDeConfirmacao
        self.aoConfirmar = aoConfirmar
        self.aoCancelar = aoCancelar
        self.aoEliminar = aoEliminar
        self.fraseOriginal = fraseOriginal
        self.aoEscolherConta = aoEscolherConta

        // Categoria nunca vazia se houver uma boa pista: num registo novo,
        // a que veio da interpretação já é uma sugestão; sem nenhuma, a Lume
        // procura pelo histórico e pelas palavras-chave.
        var inicial = proposta
        var sugerida: String? = aoEliminar == nil ? proposta.nomeDaCategoria : nil
        if inicial.nomeDaCategoria == nil {
            sugerida = HojeViewModel.categoriaSugerida(
                para: inicial,
                textoOriginal: fraseOriginal ?? "",
                categoriaDoInterpretador: nil,
                categorias: categorias
            )
            inicial.nomeDaCategoria = sugerida
        }
        self.proposta = inicial
        self.categoriaSugerida = sugerida
        self.contaEscolhida = conta
        self.textoDoValor = Self.textoEditavel(proposta.valor)
        self.mostrarCalendario = false
        self.confirmarEliminacao = false
    }

    var body: some View {
        VStack(spacing: 0) {
            BarraDeEdicao(
                titulo: tituloDaBarra,
                textoDeConfirmar: textoDoBotao,
                podeConfirmar: podeConfirmar,
                aoCancelar: aoCancelar,
                aoConfirmar: confirmar
            )
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let frase = fraseOriginal?.trimmingCharacters(in: .whitespacesAndNewlines), !frase.isEmpty {
                        fraseView(frase)
                    }
                    cartaoPrincipal
                    cartaoDeCampos

                    // A ação também na zona do polegar, logo a seguir aos
                    // campos — sem um vazio a separá-la do cartão.
                    BotaoLume(titulo: textoDoBotao, simbolo: "checkmark") { confirmar() }
                        .disabled(!podeConfirmar)
                        .padding(.top, 6)
                    if aoEliminar != nil {
                        BotaoLume(titulo: "Eliminar movimento", simbolo: "trash", estilo: .destrutivo) {
                            confirmarEliminacao = true
                        }
                    }
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tema.fundo)
        .tint(Tema.tinta)
        .environment(\.locale, FormatadorDeMoeda.localidade)
        .onAppear {
            if contaEscolhida == nil, mostrarConta {
                contaEscolhida = contas.first(where: \.principal) ?? contas.first
            }
        }
        .onChange(of: textoDoValor) { _, texto in
            if let valor = try? FormatoDeEuros.Estrategia().parse(texto) {
                proposta.valor = valor
            }
        }
        .onChange(of: focado) { _, campo in
            // Ao entrar no valor, o texto fica limpo ("12,50"), sem "€".
            if campo == .valor { textoDoValor = Self.textoEditavel(proposta.valor) }
        }
        .confirmationDialog("Eliminar este movimento?", isPresented: $confirmarEliminacao, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { aoEliminar?() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Não é possível desfazer.")
        }
    }

    // MARK: - Títulos e ação

    /// "Confirmar despesa" num registo novo; nos outros casos, o título
    /// recebido em maiúsculas passa a frase normal ("Editar movimento").
    private var tituloDaBarra: String {
        if titulo == "PERCEBIDO" {
            return proposta.tipo == .receita ? "Confirmar receita" : "Confirmar despesa"
        }
        let minusculas = titulo.lowercased(with: FormatadorDeMoeda.localidade)
        return minusculas.prefix(1).uppercased() + minusculas.dropFirst()
    }

    /// "Guardar" em vez do genérico "Confirmar"; "Aplicar" e afins ficam.
    private var textoDoBotao: String {
        textoDeConfirmacao == "Confirmar" ? "Guardar" : textoDeConfirmacao
    }

    private var podeConfirmar: Bool {
        proposta.valor > .zero
            && !proposta.descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func confirmar() {
        guard podeConfirmar else { return }
        focado = nil
        if mostrarConta { aoEscolherConta?(contaEscolhida) }
        aoConfirmar(proposta)
    }

    // MARK: - Frase original

    private func fraseView(_ frase: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tema.tintaSuave)
            Text("“\(frase)”")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
                .lineLimit(2)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Frase original: \(frase)")
    }

    // MARK: - Título, loja e valor

    private var cartaoPrincipal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField(text: $proposta.descricao, prompt: Text("Descrição").foregroundStyle(Tema.placeholder)) {
                    Text("Descrição")
                }
                .font(Tema.fonte(19, .semibold))
                .foregroundStyle(Tema.tinta)
                .focused($focado, equals: .descricao)
                .submitLabel(.next)
                .onSubmit { focado = .loja }
                lapis(.descricao)
            }

            TextField(text: lojaBinding, prompt: Text("Loja (opcional)").foregroundStyle(Tema.placeholder)) {
                Text("Loja")
            }
            .font(Tema.fonte(14))
            .foregroundStyle(Tema.tintaSuave)
            .focused($focado, equals: .loja)
            .submitLabel(.next)
            .onSubmit { focado = .valor }

            campoDoValor
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    /// O valor com a hierarquia da app (euros grandes, cêntimos pequenos)
    /// num campo cinza-pedra com lápis — vê-se logo que é editável.
    /// Ao tocar, passa a campo de texto com teclado decimal.
    private var campoDoValor: some View {
        let editar = focado == .valor
        return HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                TextField(text: $textoDoValor, prompt: Text("0,00").foregroundStyle(Tema.placeholder)) {
                    Text("Valor")
                }
                .keyboardType(.decimalPad)
                .font(Tema.fonte(34, .medium))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
                .focused($focado, equals: .valor)
                .opacity(editar ? 1 : 0)

                if !editar {
                    ValorEmEuros(
                        valor: proposta.valor,
                        tamanho: 34,
                        peso: .medium,
                        cor: proposta.tipo == .receita ? Tema.positivo : Tema.tinta
                    )
                    .allowsHitTesting(false)
                }
            }
            Spacer(minLength: 4)
            if editar {
                Text("€")
                    .font(Tema.fonte(17, .medium))
                    .foregroundStyle(Tema.tintaSuave)
            } else {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tema.placeholder)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(Tema.bege, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        .contentShape(RoundedRectangle(cornerRadius: Tema.Raio.campo))
        .onTapGesture { focado = .valor }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Valor: \(FormatadorDeMoeda.falado(proposta.valor))")
        .accessibilityHint("Toca para editar")
    }

    private func lapis(_ campo: Campo) -> some View {
        Image(systemName: "pencil")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tema.placeholder)
            .onTapGesture { focado = campo }
            .accessibilityHidden(true)
    }

    // MARK: - Linhas

    private var cartaoDeCampos: some View {
        VStack(spacing: 0) {
            linhaDaCategoria
            divisor
            linhaDoTipo
            divisor
            linhaDaData
            if mostrarCalendario {
                DatePicker("Data", selection: $proposta.data, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
            if mostrarConta {
                divisor
                linhaDaConta
            }
            divisor
            linhaDaNota
            divisor
            linhaDoTalao
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .cartao()
        .onChange(of: proposta.data) {
            withAnimation(.snappy(duration: 0.22)) { mostrarCalendario = false }
        }
    }

    private var divisor: some View {
        Divider().overlay(Tema.separador)
    }

    private var categoriaEscolhida: Categoria? {
        categorias.first { $0.nome == proposta.nomeDaCategoria }
    }

    private var linhaDaCategoria: some View {
        Menu {
            Picker("Categoria", selection: $proposta.nomeDaCategoria) {
                Text("Sem categoria").tag(String?.none)
                ForEach(categorias) { categoria in
                    Label(categoria.nome, systemImage: categoria.simbolo)
                        .tag(String?.some(categoria.nome))
                }
            }
        } label: {
            LinhaDeFormulario(rotulo: "Categoria", simbolo: "square.grid.2x2") {
                HStack(spacing: 8) {
                    if let categoria = categoriaEscolhida {
                        IconeDeCategoria(categoria: categoria, lado: 26)
                        // O nome com "sugerido" por baixo, para caber
                        // inteiro mesmo em categorias de nome comprido.
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(categoria.nome)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            if categoria.nome == categoriaSugerida {
                                etiquetaSugerido
                            }
                        }
                    } else {
                        // Vazio é um convite, nunca um erro.
                        Text("Escolher")
                            .foregroundStyle(Tema.placeholder)
                    }
                }
            }
        }
        .accessibilityLabel("Categoria")
        .accessibilityValue(
            (proposta.nomeDaCategoria ?? "Sem categoria")
                + (proposta.nomeDaCategoria != nil && proposta.nomeDaCategoria == categoriaSugerida ? ", sugerida" : "")
        )
    }

    private var etiquetaSugerido: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
            Text("sugerido")
                .font(Tema.fonte(10, .semibold))
        }
        .foregroundStyle(Tema.ouro)
    }

    private var linhaDoTipo: some View {
        Menu {
            Picker("Tipo", selection: $proposta.tipo) {
                Label("Despesa", systemImage: "arrow.down").tag(TipoTransacao.despesa)
                Label("Receita", systemImage: "arrow.up").tag(TipoTransacao.receita)
            }
        } label: {
            LinhaDeFormulario(rotulo: "Tipo", simbolo: "arrow.up.arrow.down") {
                Text(proposta.tipo == .receita ? "Receita" : "Despesa")
            }
        }
        .accessibilityLabel("Tipo")
        .accessibilityValue(proposta.tipo == .receita ? "Receita" : "Despesa")
    }

    private var linhaDaData: some View {
        Button {
            focado = nil
            withAnimation(.snappy(duration: 0.22)) { mostrarCalendario.toggle() }
        } label: {
            LinhaDeFormulario(rotulo: "Data", simbolo: "calendar") {
                Text(textoDaData)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(textoDaData)
    }

    /// "Hoje", "Ontem" ou "28 set." (com o ano, se não for o corrente).
    private var textoDaData: String {
        let calendario = Calendar.current
        let data = proposta.data
        if calendario.isDateInToday(data) { return "Hoje" }
        if calendario.isDateInYesterday(data) { return "Ontem" }
        let localidade = FormatadorDeMoeda.localidade
        if calendario.isDate(data, equalTo: .now, toGranularity: .year) {
            return data.formatted(.dateTime.day().month(.abbreviated).locale(localidade))
        }
        return data.formatted(.dateTime.day().month(.abbreviated).year().locale(localidade))
    }

    /// A linha Conta só aparece quando a escolha vai mesmo ser guardada.
    private var mostrarConta: Bool {
        !contas.isEmpty && aoEscolherConta != nil
    }

    private var linhaDaConta: some View {
        Menu {
            Picker("Conta", selection: $contaEscolhida) {
                ForEach(contas) { conta in
                    Text(conta.nome).tag(Conta?.some(conta))
                }
            }
        } label: {
            LinhaDeFormulario(rotulo: "Conta", simbolo: "creditcard") {
                HStack(spacing: 8) {
                    if let conta = contaEscolhida {
                        // O mini-cartão na cor da conta, como no separador Contas.
                        RoundedRectangle(cornerRadius: 3)
                            .fill(conta.corDoCartao)
                            .frame(width: 20, height: 13)
                            .accessibilityHidden(true)
                        Text(conta.nome)
                            .lineLimit(1)
                    } else {
                        Text("Escolher")
                            .foregroundStyle(Tema.placeholder)
                    }
                }
            }
        }
        .accessibilityLabel("Conta")
        .accessibilityValue(contaEscolhida?.nome ?? "Nenhuma")
    }

    private var linhaDaNota: some View {
        LinhaDeFormulario(rotulo: "Nota", simbolo: "text.alignleft", mostrarChevron: false) {
            TextField(text: notaBinding, prompt: Text("Opcional").foregroundStyle(Tema.placeholder)) {
                Text("Nota")
            }
            .multilineTextAlignment(.trailing)
            .submitLabel(.done)
        }
    }

    /// Anexar ou substituir a foto do talão a partir da galeria; já com uma
    /// forma de a remover, sem precisar de voltar a digitalizar.
    private var linhaDoTalao: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $talaoEscolhido, matching: .images) {
                LinhaDeFormulario(
                    rotulo: "Talão",
                    simbolo: "camera",
                    mostrarChevron: false
                ) {
                    Text(proposta.fotoDoTalao == nil ? "Anexar" : "Substituir")
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
            .buttonStyle(.plain)
            if proposta.fotoDoTalao != nil {
                Button("Remover", role: .destructive) { proposta.fotoDoTalao = nil }
                    .font(Tema.fonte(13, .medium))
            }
        }
        .onChange(of: talaoEscolhido) {
            Task {
                proposta.fotoDoTalao = try? await talaoEscolhido?.loadTransferable(type: Data.self)
            }
        }
    }

    // MARK: - Auxiliares

    /// "12,50" para editar (sem símbolo nem espaços); vazio quando é zero.
    private static func textoEditavel(_ valor: Decimal) -> String {
        valor == .zero ? "" : FormatadorDeMoeda.textoSimples(valor)
    }

    /// `loja` é opcional no modelo; o campo de texto trabalha com "" ↔ nil.
    private var lojaBinding: Binding<String> {
        Binding(
            get: { proposta.loja ?? "" },
            set: { proposta.loja = $0.isEmpty ? nil : $0 }
        )
    }

    /// `nota` é opcional no modelo; o campo de texto trabalha com "" ↔ nil.
    private var notaBinding: Binding<String> {
        Binding(
            get: { proposta.nota ?? "" },
            set: { proposta.nota = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview("Registo novo") {
    CartaoDeConfirmacaoView(
        proposta: PropostaDeTransacao(
            valor: Decimal(string: "12.50") ?? .zero,
            tipo: .despesa,
            descricao: "Almoço",
            loja: "Time Out Market",
            nomeDaCategoria: "Restauração",
            data: .now
        ),
        categorias: [
            Categoria(nome: "Restauração", simbolo: "fork.knife", corHex: "B0713C", ordem: 1),
        ],
        aoConfirmar: { _ in },
        aoCancelar: {},
        fraseOriginal: "Gastei 12,50 no almoço no Time Out Market",
        aoEscolherConta: { _ in }
    )
    .modelContainer(ContentorDeDados.emMemoria())
}
