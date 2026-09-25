import SwiftUI
import SwiftData
import UserNotifications

/// Os primeiros passos do Figma: boas-vindas, entrada opcional e uma
/// configuração curta em três passos. Sem servidor, a "conta" é o espaço
/// local + iCloud — os ecrãs de entrada guardam apenas o nome e o email.
struct BoasVindasView: View {
    private enum Passo {
        case bemVinda, entrar, criarConta, recuperar
        case ritmo, limite, notificacoes, pronto
    }

    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var definicoes: [DefinicoesDoMes]

    let aoComecar: () -> Void

    @State private var passo = Passo.bemVinda
    @AppStorage("nomeDePerfil") private var nomeDePerfil = "O teu nome"
    @AppStorage("emailDeConta") private var emailDeConta = ""

    @State private var nome = ""
    @State private var email = ""
    @State private var palavraPasse = ""
    @State private var nomeDaConta = "Conta principal"
    @State private var orcamento = Decimal.zero
    @State private var recuperacaoPedida = false

    private var moeda: Decimal.FormatStyle.Currency {
        .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecalho

                switch passo {
                case .bemVinda: bemVinda
                case .entrar: entrar
                case .criarConta: criarConta
                case .recuperar: recuperar
                case .ritmo: ritmo
                case .limite: limite
                case .notificacoes: notificacoes
                case .pronto: pronto
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .animation(.snappy, value: passo)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Peças comuns

    private var legendaDoPasso: (String, String) {
        switch passo {
        case .bemVinda: ("O TEU DINHEIRO, COM CLAREZA", "Bem-vinda ao Lume")
        case .entrar: ("ENTRAR NO LUME", "É bom ter-te de volta")
        case .criarConta: ("CRIAR CONTA", "Cria o teu espaço")
        case .recuperar: ("SEM COMPLICAÇÕES", "Recuperar acesso")
        case .ritmo: ("PASSO 1 DE 3", "Ao teu ritmo")
        case .limite: ("PASSO 2 DE 3", "Um limite confortável")
        case .notificacoes: ("PASSO 3 DE 3", "Só o que importa")
        case .pronto: ("O TEU ESPAÇO ESTÁ PRONTO", "Tudo pronto, \(nomeParaSaudacao)")
        }
    }

    private var nomeParaSaudacao: String {
        let limpo = nome.trimmingCharacters(in: .whitespaces)
        if !limpo.isEmpty { return limpo }
        return nomeDePerfil == "O teu nome" ? "estás em casa" : nomeDePerfil
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 10) {
            CabecalhoDeEcra(legenda: legendaDoPasso.0, titulo: legendaDoPasso.1)
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

    private func botao(_ titulo: String, ativo: Bool = true, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo)
                .font(.headline)
                .foregroundStyle(Color(hex: "302B24"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        }
        .disabled(!ativo)
    }

    private func ligacao(_ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(titulo, action: acao)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Tema.douradoEscuro)
            .frame(maxWidth: .infinity)
    }

    private func campo(_ legenda: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(legenda)
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(Tema.tintaSuave)
            conteudo()
                .font(.subheadline)
                .foregroundStyle(Tema.tinta)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.campo)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )
        }
    }

    private func cartaoAreia(simbolo: String, titulo: String, texto: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: simbolo)
                .font(.title3)
                .foregroundStyle(Tema.douradoEscuro)
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tema.tinta)
            Text(texto)
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
    }

    // MARK: - 01 Bem-vinda

    @ViewBuilder
    private var bemVinda: some View {
        Image("SimboloLume")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .shadow(color: Tema.dourado.opacity(0.35), radius: 24, y: 10)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

        Text("Menos contas na cabeça.\nMais espaço para viver.")
            .font(.title2.weight(.bold))
            .foregroundStyle(Tema.tinta)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 14) {
            vantagem("textformat", "Regista como te der jeito", "Escreve, fala ou fotografa um talão.")
            vantagem("creditcard", "Percebe para onde vai", "Movimentos e orçamentos num só lugar.")
            vantagem("lock", "O teu espaço, privado", "Podes começar sem criar uma conta.")
        }
        .padding(.vertical, 8)

        botao("Começar") { passo = .ritmo }
        ligacao("Já tenho conta · Entrar") { passo = .entrar }
    }

    private func vantagem(_ simbolo: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: simbolo)
                .font(.footnote)
                .foregroundStyle(Tema.douradoEscuro)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tema.tinta)
                Text(texto)
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
    }

    // MARK: - 02 Entrar · 03 Criar conta · 04 Recuperar

    @ViewBuilder
    private var entrar: some View {
        Text("Entra na tua conta para continuar.")
            .font(.subheadline)
            .foregroundStyle(Tema.tintaSuave)

        campo("EMAIL") {
            TextField("nome@exemplo.pt", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        campo("PALAVRA-PASSE") {
            SecureField("Introduz a tua palavra-passe", text: $palavraPasse)
        }

        ligacao("Esqueci-me da palavra-passe") { passo = .recuperar }

        botao("Entrar", ativo: !email.isEmpty) {
            emailDeConta = email
            passo = .ritmo
        }

        ligacao("Ainda não tens conta? Criar conta") { passo = .criarConta }
        ligacao("Continuar sem conta") { passo = .ritmo }

        Text("A entrada é opcional. Podes usar o Lume localmente e configurar a conta mais tarde.")
            .font(.caption)
            .foregroundStyle(Tema.tintaSuave)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var criarConta: some View {
        Text("Só precisamos do essencial.")
            .font(.subheadline)
            .foregroundStyle(Tema.tintaSuave)

        campo("NOME") {
            TextField("Como te podemos chamar?", text: $nome)
        }
        campo("EMAIL") {
            TextField("nome@exemplo.pt", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        campo("PALAVRA-PASSE") {
            SecureField("Cria uma palavra-passe", text: $palavraPasse)
        }
        Text("Usa pelo menos 12 caracteres.")
            .font(.caption)
            .foregroundStyle(Tema.tintaSuave)

        botao("Criar conta", ativo: !nome.isEmpty && !email.isEmpty) {
            emailDeConta = email
            passo = .ritmo
        }

        ligacao("Já tenho conta · Entrar") { passo = .entrar }
        ligacao("Prefiro começar sem conta") { passo = .ritmo }

        Text("Ao criar conta, aceitas os Termos de utilização e a Política de privacidade.")
            .font(.caption)
            .foregroundStyle(Tema.tintaSuave)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var recuperar: some View {
        cartaoAreia(
            simbolo: "lock",
            titulo: "Vamos ajudar-te a voltar a entrar.",
            texto: "Indica o email associado à tua conta para pedires uma ligação de recuperação."
        )

        campo("EMAIL") {
            TextField("nome@exemplo.pt", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }

        botao("Pedir ligação de recuperação", ativo: !email.isEmpty) {
            recuperacaoPedida = true
        }

        Text(recuperacaoPedida
            ? "Pedido enviado. Verifica a tua caixa de entrada."
            : "Se existir uma conta com este email, receberás as instruções na tua caixa de entrada.")
            .font(.caption)
            .foregroundStyle(recuperacaoPedida ? Tema.positivo : Tema.tintaSuave)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

        ligacao("Voltar ao login") { passo = .entrar }
    }

    // MARK: - 05 Passo 1 · Ao teu ritmo

    @ViewBuilder
    private var ritmo: some View {
        Text("Vamos pôr tudo ao teu gosto.")
            .font(.subheadline)
            .foregroundStyle(Tema.tintaSuave)

        campo("COMO TE PODEMOS CHAMAR?") {
            TextField("O teu nome", text: $nome)
        }
        campo("MOEDA PRINCIPAL") {
            Text("Euro · EUR")
                .foregroundStyle(Tema.tintaSuave)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        campo("NOME DA PRIMEIRA CONTA") {
            TextField("Conta principal", text: $nomeDaConta)
        }

        cartaoAreia(
            simbolo: "creditcard",
            titulo: "Começa com o que já sabes.",
            texto: "Esta conta organiza os teus registos. Não precisas de ligar o teu banco."
        )

        botao("Continuar") {
            aplicarRitmo()
            passo = .limite
        }
        ligacao("Configurar mais tarde") { concluir() }
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
        Text("Quanto queres gastar por mês?")
            .font(.title3.weight(.bold))
            .foregroundStyle(Tema.tinta)
        Text("Escolhe um valor para as tuas despesas. Podes ajustá-lo a qualquer momento.")
            .font(.footnote)
            .foregroundStyle(Tema.tintaSuave)

        VStack(alignment: .leading, spacing: 8) {
            Text("ORÇAMENTO MENSAL")
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(Tema.douradoEscuro)
            TextField("1 450,00 €", value: $orcamento, format: moeda)
                .keyboardType(.decimalPad)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
            Divider().overlay(Tema.dourado)
            Text("Um ponto de partida, sem pressão.")
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))

        if !categorias.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("COMEÇAMOS COM")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(Tema.tintaSuave)
                FluxoDeChips(nomes: categorias.map(\.nome))
            }
        }

        botao("Guardar e continuar") {
            aplicarLimite()
            passo = .notificacoes
        }
        ligacao("Saltar por agora") { passo = .notificacoes }
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
        cartaoAreia(
            simbolo: "bell",
            titulo: "Um lembrete na altura certa.",
            texto: "Recebe avisos quando estiveres perto de um limite e um resumo no fim da semana."
        )

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Limites de orçamento")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tema.tinta)
                Text("Sabe quando uma categoria precisa de atenção.")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Resumo semanal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tema.tinta)
                Text("Vê os teus gastos e o que ainda tens disponível.")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
            }
        }

        botao("Ativar notificações") {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                passo = .pronto
            }
        }
        ligacao("Agora não") { passo = .pronto }

        Text("Podes alterar esta escolha nas definições.")
            .font(.caption)
            .foregroundStyle(Tema.tintaSuave)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 08 Tudo pronto

    @ViewBuilder
    private var pronto: some View {
        Image("SimboloLume")
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 110)
            .shadow(color: Tema.dourado.opacity(0.35), radius: 24, y: 10)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

        Text("O primeiro passo\njá está dado.")
            .font(.title2.weight(.bold))
            .foregroundStyle(Tema.tinta)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

        VStack(spacing: 10) {
            linhaDeResumo("Moeda", "Euro · EUR")
            linhaDeResumo("Conta", contas.first(where: \.principal)?.nome ?? nomeDaConta)
            linhaDeResumo("Orçamento mensal", orcamento > .zero ? FormatadorDeMoeda.texto(orcamento) : "por definir")
        }
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))

        botao("Entrar no meu Lume") { concluir() }

        VStack(alignment: .leading, spacing: 4) {
            Text("EXPERIMENTA DIZER")
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(Tema.douradoEscuro)
            Text("“Gastei 3,40 € no café.”")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tema.tinta)
            Text("O Lume ajuda-te a organizar o resto.")
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
        }
        .padding(.top, 4)
    }

    private func linhaDeResumo(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(valor)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Tema.tinta)
        }
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
                    .font(.footnote)
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
