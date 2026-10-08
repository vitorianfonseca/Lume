import SwiftUI
import SwiftData
import UserNotifications

/// Os primeiros passos do Figma: boas-vindas, entrada opcional e uma
/// configuração curta em três passos. Sem servidor, a "conta" é o espaço
/// local + iCloud — os ecrãs de entrada guardam apenas o nome e o email.
///
/// Regras de todos os passos: conteúdo em cima (ou centrado, nos ecrãs de
/// marca), a ação principal ancorada em baixo com as secundárias em texto
/// por baixo, e voltar a partir do segundo ecrã.
struct BoasVindasView: View {
    private enum Passo {
        case boasVindas, entrar, criarConta, recuperar
        case ritmo, limite, notificacoes, pronto
    }

    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var definicoes: [DefinicoesDoMes]

    let aoComecar: () -> Void

    @State private var passo = Passo.boasVindas
    /// Os passos por onde se passou, para o voltar regressar ao certo.
    @State private var historico: [Passo] = []
    /// Para onde desliza o passo seguinte (avançar entra pela direita).
    @State private var aAvancar = true

    @AppStorage("nomeDePerfil") private var nomeDePerfil = "O teu nome"
    @AppStorage("emailDeConta") private var emailDeConta = ""

    @State private var nome = ""
    @State private var email = ""
    @State private var palavraPasse = ""
    @State private var nomeDaConta = "Conta principal"
    @State private var orcamento = Decimal.zero
    @State private var recuperacaoPedida = false

    var body: some View {
        VStack(spacing: 0) {
            // No fim, o voltar fica no topo (o conteúdo está centrado).
            if passo == .pronto {
                HStack {
                    BotaoRedondo(simbolo: "chevron.left", rotulo: "Voltar", acao: voltar)
                    Spacer()
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 4)
            }

            GeometryReader { geometria in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if passo != .boasVindas && passo != .pronto {
                            cabecalho
                        }
                        conteudo
                    }
                    .padding(.horizontal, Tema.margemDoEcra)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                    // Os ecrãs de marca ficam centrados na vertical;
                    // os formulários começam em cima, junto ao cabeçalho.
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometria.size.height,
                        alignment: ecraDeMarca ? .center : .top
                    )
                    .id(passo)
                    .transition(.asymmetric(
                        insertion: .move(edge: aAvancar ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }

            rodape
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .background(Tema.fundo)
    }

    private var ecraDeMarca: Bool { passo == .boasVindas || passo == .pronto }

    @ViewBuilder
    private var conteudo: some View {
        switch passo {
        case .boasVindas: boasVindas
        case .entrar: entrar
        case .criarConta: criarConta
        case .recuperar: recuperar
        case .ritmo: ritmo
        case .limite: limite
        case .notificacoes: notificacoes
        case .pronto: pronto
        }
    }

    // MARK: - Navegação

    private func ir(para destino: Passo) {
        aAvancar = true
        withAnimation(.snappy(duration: 0.3)) {
            historico.append(passo)
            passo = destino
        }
    }

    private func voltar() {
        aAvancar = false
        withAnimation(.snappy(duration: 0.3)) {
            passo = historico.popLast() ?? .boasVindas
        }
    }

    // MARK: - Peças comuns

    private var legendaDoPasso: (String, String) {
        switch passo {
        case .boasVindas: ("Boas-vindas à Lume", "Menos contas na cabeça. Mais espaço para viver.")
        case .entrar: ("Entrar", "É bom ter-te de volta")
        case .criarConta: ("Criar conta", "Cria o teu espaço")
        case .recuperar: ("Palavra-passe", "Recuperar acesso")
        case .ritmo: ("Passo 1 de 3", "Ao teu ritmo")
        case .limite: ("Passo 2 de 3", "Um limite confortável")
        case .notificacoes: ("Passo 3 de 3", "Só o que importa")
        case .pronto: ("O teu espaço está pronto", "Tudo pronto, \(nomeParaSaudacao)")
        }
    }

    private var nomeParaSaudacao: String {
        let limpo = nome.trimmingCharacters(in: .whitespaces)
        if !limpo.isEmpty { return limpo }
        return nomeDePerfil == "O teu nome" ? "estás em casa" : nomeDePerfil
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoDeEcra(legenda: legendaDoPasso.0, titulo: legendaDoPasso.1, aoVoltar: voltar)
            if let indice = indiceDoPasso {
                // As três barrinhas de progresso dos passos.
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { posicao in
                        Capsule()
                            .fill(posicao <= indice ? AnyShapeStyle(Tema.douradoBotao) : AnyShapeStyle(Tema.separador))
                            .frame(height: 3)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private var indiceDoPasso: Int? {
        switch passo {
        case .ritmo: 0
        case .limite: 1
        case .notificacoes: 2
        default: nil
        }
    }

    /// O rodapé fixo: a ação principal (um só dourado) e, por baixo, as
    /// alternativas discretas em texto.
    @ViewBuilder
    private var rodape: some View {
        VStack(spacing: 2) {
            switch passo {
            case .boasVindas:
                BotaoLume(titulo: "Começar") { ir(para: .ritmo) }
                alternativa("Já tenho conta") { ir(para: .entrar) }

            case .entrar:
                BotaoLume(titulo: "Entrar") {
                    emailDeConta = email
                    ir(para: .ritmo)
                }
                .disabled(email.isEmpty)
                alternativa("Continuar sem conta") { ir(para: .ritmo) }

            case .criarConta:
                BotaoLume(titulo: "Criar conta") {
                    emailDeConta = email
                    ir(para: .ritmo)
                }
                .disabled(nome.isEmpty || email.isEmpty)
                alternativa("Prefiro começar sem conta") { ir(para: .ritmo) }

            case .recuperar:
                BotaoLume(titulo: "Pedir ligação de recuperação") {
                    recuperacaoPedida = true
                }
                .disabled(email.isEmpty)
                alternativa("Voltar a entrar") { voltar() }

            case .ritmo:
                BotaoLume(titulo: "Continuar") {
                    aplicarRitmo()
                    ir(para: .limite)
                }
                alternativa("Configurar mais tarde") { concluir() }

            case .limite:
                BotaoLume(titulo: "Guardar e continuar") {
                    aplicarLimite()
                    ir(para: .notificacoes)
                }
                alternativa("Saltar por agora") { ir(para: .notificacoes) }

            case .notificacoes:
                BotaoLume(titulo: "Ativar notificações") {
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .badge, .sound])
                        ir(para: .pronto)
                    }
                }
                alternativa("Agora não") { ir(para: .pronto) }

            case .pronto:
                BotaoLume(titulo: "Entrar na minha Lume") { concluir() }
            }
        }
    }

    private func alternativa(_ titulo: String, acao: @escaping () -> Void) -> some View {
        BotaoLume(titulo: titulo, estilo: .texto, acao: acao)
            .frame(maxWidth: .infinity)
    }

    private func campo(_ legenda: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Legenda(legenda)
            conteudo()
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.campo)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )
        }
    }

    /// O texto de exemplo dos campos, em cinzento legível (≥3,5:1).
    private func exemplo(_ texto: String) -> Text {
        Text(texto).foregroundStyle(Tema.placeholder)
    }

    private func campoDeEmail() -> some View {
        campo("Email") {
            TextField("Email", text: $email, prompt: exemplo("nome@exemplo.pt"))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    /// Ícone 3D da Lume (os renders "Ilustracao3D-…"), para coisas.
    private func icone3D(_ tipo: Ilustracao.Tipo, lado: CGFloat) -> some View {
        Image(tipo.imagem)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: lado, height: lado)
            .accessibilityHidden(true)
    }

    /// Cartão de destaque (o único olive da app) com um ícone 3D ou de linha.
    private func cartaoDeDestaque(
        ilustracao: Ilustracao.Tipo? = nil,
        simbolo: String? = nil,
        titulo: String,
        texto: String
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let ilustracao {
                icone3D(ilustracao, lado: 48)
            } else if let simbolo {
                Image(systemName: simbolo)
                    .font(.system(size: 20, weight: .medium))
                    .textoDourado()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text(texto)
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cartaoCafe()
    }

    private func nota(_ texto: String, cor: Color = Tema.tintaSuave) -> some View {
        Text(texto)
            .font(Tema.fonte(12))
            .foregroundStyle(cor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 01 Boas-vindas

    /// Hierarquia: logo grande → legenda "Boas-vindas à Lume" → o tagline
    /// como título. A marca aparece uma vez só.
    @ViewBuilder
    private var boasVindas: some View {
        VStack(spacing: 12) {
            Image("SimboloLume")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .shadow(color: Tema.dourado.opacity(0.3), radius: 22, y: 10)
                .padding(.bottom, 12)
                .accessibilityHidden(true)

            Legenda(legendaDoPasso.0)

            Text("Menos contas na cabeça.\nMais espaço para viver.")
                .font(Tema.fonte(28, .semibold))
                .foregroundStyle(Tema.tinta)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 16) {
            vantagem(.balao, "Escreve como falas", "Ou fala, ou fotografa um talão.")
            vantagem(.cartoes, "Percebe para onde vai", "Movimentos, contas e limites num só lugar.")
            vantagem(.cadeado, "O teu espaço, privado", "Podes começar sem criar conta.")
        }
        .padding(.top, 16)
    }

    private func vantagem(_ ilustracao: Ilustracao.Tipo, _ titulo: String, _ texto: String) -> some View {
        HStack(spacing: 14) {
            icone3D(ilustracao, lado: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text(texto)
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 02 Entrar · 03 Criar conta · 04 Recuperar

    @ViewBuilder
    private var entrar: some View {
        Text("Entra na tua conta para continuar.")
            .font(Tema.fonte(15))
            .foregroundStyle(Tema.tintaSuave)

        campoDeEmail()
        campo("Palavra-passe") {
            SecureField("Palavra-passe", text: $palavraPasse, prompt: exemplo("Introduz a tua palavra-passe"))
                .textContentType(.password)
        }

        HStack {
            BotaoLume(titulo: "Criar conta", estilo: .texto) { ir(para: .criarConta) }
            Spacer()
            BotaoLume(titulo: "Esqueci-me", estilo: .texto) { ir(para: .recuperar) }
                .accessibilityLabel("Esqueci-me da palavra-passe")
        }

        nota("A entrada é opcional. Podes usar a Lume localmente e configurar a conta mais tarde.")
    }

    @ViewBuilder
    private var criarConta: some View {
        Text("Só precisamos do essencial.")
            .font(Tema.fonte(15))
            .foregroundStyle(Tema.tintaSuave)

        campo("Nome") {
            TextField("Nome", text: $nome, prompt: exemplo("Como te podemos chamar?"))
                .textContentType(.givenName)
        }
        campoDeEmail()
        VStack(alignment: .leading, spacing: 6) {
            campo("Palavra-passe") {
                SecureField("Palavra-passe", text: $palavraPasse, prompt: exemplo("Cria uma palavra-passe"))
                    .textContentType(.newPassword)
            }
            Text("Usa pelo menos 12 caracteres.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }

        nota("Ao criar conta, aceitas os Termos de utilização e a Política de privacidade.")
    }

    @ViewBuilder
    private var recuperar: some View {
        cartaoDeDestaque(
            ilustracao: .cadeado,
            titulo: "Vamos ajudar-te a voltar a entrar.",
            texto: "Indica o email associado à tua conta para pedires uma ligação de recuperação."
        )

        campoDeEmail()

        nota(
            recuperacaoPedida
                ? "Pedido enviado. Verifica a tua caixa de entrada."
                : "Se existir uma conta com este email, receberás as instruções na tua caixa de entrada.",
            cor: recuperacaoPedida ? Tema.positivo : Tema.tintaSuave
        )
    }

    // MARK: - 05 Passo 1 · Ao teu ritmo

    @ViewBuilder
    private var ritmo: some View {
        Text("Vamos pôr tudo ao teu gosto.")
            .font(Tema.fonte(15))
            .foregroundStyle(Tema.tintaSuave)

        campo("Como te podemos chamar?") {
            TextField("Nome", text: $nome, prompt: exemplo("O teu nome"))
                .textContentType(.givenName)
        }
        campo("Moeda principal") {
            Text("Euro · EUR")
                .foregroundStyle(Tema.tintaSuave)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        campo("Nome da primeira conta") {
            TextField("Nome da conta", text: $nomeDaConta, prompt: exemplo("Conta principal"))
        }

        cartaoDeDestaque(
            ilustracao: .cartoes,
            titulo: "Começa com o que já sabes.",
            texto: "Esta conta organiza os teus registos. Não precisas de ligar o teu banco."
        )
    }

    private func aplicarRitmo() {
        let limpo = nome.trimmingCharacters(in: .whitespaces)
        if !limpo.isEmpty { nomeDePerfil = limpo }
        let nomeConta = nomeDaConta.trimmingCharacters(in: .whitespaces)
        if contas.isEmpty, !nomeConta.isEmpty {
            let conta = Conta(nome: nomeConta, tipo: .aOrdem, saldoInicial: .zero)
            conta.principal = true
            contexto.insert(conta)
            try? contexto.save()
        }
    }

    // MARK: - 06 Passo 2 · Um limite confortável

    @ViewBuilder
    private var limite: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quanto queres gastar por mês?")
                .font(Tema.fonte(17, .semibold))
                .foregroundStyle(Tema.tinta)
            Text("Escolhe um valor para as tuas despesas. Podes ajustá-lo a qualquer momento.")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
        }

        VStack(alignment: .leading, spacing: 8) {
            Legenda("Orçamento mensal")
            TextField("Orçamento mensal", value: $orcamento, format: .euros, prompt: exemplo("1 450,00 €"))
                .keyboardType(.decimalPad)
                .font(Tema.fonte(34, .semibold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
            Divider().overlay(Tema.dourado)
            Text("Um ponto de partida, sem pressão.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cartaoCafe()

        if !categorias.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Legenda("Começamos com")
                FluxoDeChips(nomes: categorias.map(\.nome))
            }
        }
    }

    private func aplicarLimite() {
        guard orcamento > .zero else { return }
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        if let atual = definicoes.first(where: { $0.ano == ano && $0.mes == mes }) {
            atual.rendimentoEsperado = orcamento
        } else {
            let novas = DefinicoesDoMes(ano: ano, mes: mes)
            novas.rendimentoEsperado = orcamento
            contexto.insert(novas)
        }
        try? contexto.save()
    }

    // MARK: - 07 Passo 3 · Notificações

    @ViewBuilder
    private var notificacoes: some View {
        cartaoDeDestaque(
            simbolo: "bell",
            titulo: "Um lembrete na altura certa.",
            texto: "Recebe avisos quando estiveres perto de um limite e um resumo no fim da semana."
        )

        VStack(alignment: .leading, spacing: 0) {
            linhaDeNotificacao("Limites de orçamento", "Sabe quando uma categoria precisa de atenção.")
            Divider().overlay(Tema.separador)
            linhaDeNotificacao("Resumo semanal", "Vê os teus gastos e o que ainda tens disponível.")
        }
        .padding(.horizontal, 18)
        .cartao()

        nota("Podes alterar esta escolha no Perfil.")
    }

    private func linhaDeNotificacao(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(Tema.fonte(15, .semibold))
                .foregroundStyle(Tema.tinta)
            Text(texto)
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 08 Tudo pronto

    /// Como as boas-vindas: logo → legenda → título, e o resumo por baixo.
    @ViewBuilder
    private var pronto: some View {
        VStack(spacing: 12) {
            Image("SimboloLume")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .shadow(color: Tema.dourado.opacity(0.3), radius: 22, y: 10)
                .padding(.bottom, 8)
                .accessibilityHidden(true)

            Legenda(legendaDoPasso.0)

            Text(legendaDoPasso.1)
                .font(Tema.fonte(28, .semibold))
                .foregroundStyle(Tema.tinta)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("O primeiro passo já está dado.")
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        VStack(spacing: 0) {
            linhaDeResumo("Moeda", "Euro · EUR")
            Divider().overlay(Tema.separador)
            linhaDeResumo("Conta", contas.first(where: \.principal)?.nome ?? nomeDaConta)
            Divider().overlay(Tema.separador)
            linhaDeResumo("Orçamento mensal", orcamento > .zero ? FormatadorDeMoeda.texto(orcamento) : "Por definir")
        }
        .padding(.horizontal, 18)
        .cartao()
        .padding(.top, 8)

        HStack(spacing: 14) {
            icone3D(.balao, lado: 48)
            VStack(alignment: .leading, spacing: 3) {
                Legenda("Experimenta dizer")
                Text("“Gastei 3,40 € no café.”")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("A Lume ajuda-te a organizar o resto.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cartaoCafe()
        .accessibilityElement(children: .combine)
    }

    private func linhaDeResumo(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(valor)
                .font(Tema.fonte(14, .medium))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func concluir() {
        aplicarRitmo()
        aoComecar()
    }
}

/// Chips de texto que quebram linha, para a lista "Começamos com".
private struct FluxoDeChips: View {
    let nomes: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(nomes, id: \.self) { nome in
                Text(nome)
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tinta)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Tema.bege, in: Capsule())
            }
        }
    }
}

/// Layout simples de fluxo: encosta os elementos à esquerda e quebra linha.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largura = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alturaDaLinha: CGFloat = 0
        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x + tamanho.width > largura, x > 0 {
                x = 0
                y += alturaDaLinha + spacing
                alturaDaLinha = 0
            }
            x += tamanho.width + spacing
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
        }
        return CGSize(width: largura, height: y + alturaDaLinha)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alturaDaLinha: CGFloat = 0
        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x + tamanho.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += alturaDaLinha + spacing
                alturaDaLinha = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += tamanho.width + spacing
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
        }
    }
}

#Preview {
    BoasVindasView(aoComecar: {})
        .modelContainer(ContentorDeDados.emMemoria())
}
