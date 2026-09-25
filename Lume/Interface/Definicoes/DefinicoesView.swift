import SwiftUI
import SwiftData

/// O Perfil do Figma (ecrã 08, "O teu espaço"): cartão de perfil, estado
/// do iCloud, navegação para as definições e a nota de privacidade.
struct DefinicoesView: View {
    @Environment(\.modelContext) private var contexto
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]

    @AppStorage("nomeDePerfil") private var nomeDePerfil = "O teu nome"
    @State private var aEditarNome = false
    @State private var nomeEmEdicao = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CabecalhoDeEcra(legenda: "TUDO AO TEU GOSTO", titulo: "O teu espaço")

                    perfil
                    estadoDoICloud

                    VStack(spacing: 0) {
                        linhaDeNavegacao("Contas e carteiras", simbolo: "creditcard", valor: "\(contas.count) \(contas.count == 1 ? "conta" : "contas")") {
                            ContasECarteirasView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Categorias", simbolo: "square.grid.2x2", valor: "\(categorias.count) categorias") {
                            CategoriasView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Contas fixas", simbolo: "arrow.triangle.2.circlepath", valor: recorrentes.isEmpty ? "Nenhuma" : "\(recorrentes.count) ativas") {
                            RecorrentesView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Notificações", simbolo: "bell", valor: recorrentes.contains(where: \.ativa) ? "Ativas" : "Desligadas") {
                            NotificacoesView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Aparência", simbolo: "person", valor: "Branco") {
                            AparenciaView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Moeda", simbolo: "eurosign", valor: "Euro · EUR") {
                            MoedaView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Inteligência", simbolo: "sparkles", valor: CofreDeChaves.ler(CofreDeChaves.contaClaude)?.isEmpty == false ? "Claude" : "Local") {
                            InteligenciaView()
                        }
                        Divider().overlay(Tema.separador)
                        linhaDeNavegacao("Dados", simbolo: "tray", valor: "") {
                            DadosView()
                        }
                    }

                    notaDePrivacidade

                    HStack {
                        Button("Ajuda e apoio") {}
                            .font(Tema.fonte(13, .medium))
                            .foregroundStyle(Tema.douradoEscuro)
                        Spacer()
                        Text("Lume · versão 1.0")
                            .font(Tema.fonte(12))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .background(Tema.fundo)
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Como te podemos chamar?", isPresented: $aEditarNome) {
            TextField("Nome", text: $nomeEmEdicao)
            Button("Guardar") {
                let limpo = nomeEmEdicao.trimmingCharacters(in: .whitespaces)
                if !limpo.isEmpty { nomeDePerfil = limpo }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: - Perfil e iCloud

    private var perfil: some View {
        Button {
            nomeEmEdicao = nomeDePerfil
            aEditarNome = true
        } label: {
            HStack(spacing: 12) {
                AvatarDeIniciais(texto: nomeDePerfil, lado: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(nomeDePerfil)
                        .font(Tema.fonte(17, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text("O teu espaço pessoal")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }
                Spacer()
            }
        }
        .accessibilityLabel("Alterar o nome do perfil")
    }

    private var estadoDoICloud: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            Text("iCloud ativo · os dados sincronizam automaticamente")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    private var notaDePrivacidade: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("Os teus dados são teus.")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
            } icon: {
                Image(systemName: "lock")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.positivo)
            }
            Text("Regista offline e gere a sincronização com o teu iCloud nas definições.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.positivo.opacity(0.08), in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
    }

    private func linhaDeNavegacao(
        _ titulo: String,
        simbolo: String,
        valor: String,
        @ViewBuilder destino: @escaping () -> some View
    ) -> some View {
        NavigationLink {
            destino()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: simbolo)
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaFosca)
                    .frame(width: 20)
                Text(titulo)
                    .font(Tema.fonte(15))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                if !valor.isEmpty {
                    Text(valor)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }
                Image(systemName: "chevron.right")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(.vertical, 13)
        }
    }
}

// MARK: - Estrutura comum das sub-páginas

/// Sub-página do Perfil com o cabeçalho do design e fundo branco.
private struct PaginaDePerfil<Conteudo: View>: View {
    let legenda: String
    let titulo: String
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(legenda: legenda, titulo: titulo)
                conteudo()
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .toolbarBackground(Tema.fundo, for: .navigationBar)
        .tint(Tema.douradoEscuro)
    }
}

// MARK: - Contas e carteiras

private struct ContasECarteirasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @State private var mostrarNovaConta = false

    var body: some View {
        PaginaDePerfil(legenda: "OS TEUS CARTÕES", titulo: "Contas e carteiras") {
            CarrosselDeContas()
                .padding(.horizontal, -Tema.margemDoEcra)

            VStack(spacing: 0) {
                ForEach(contas) { conta in
                    Button {
                        tornarPrincipal(conta)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(conta.nome)
                                        .font(Tema.fonte(15, .medium))
                                        .foregroundStyle(Tema.tinta)
                                    if conta.principal {
                                        Image(systemName: "star.fill")
                                            .font(Tema.fonte(11))
                                            .foregroundStyle(Tema.dourado)
                                            .accessibilityLabel("Conta principal")
                                    }
                                }
                                Text(conta.tipo.nome)
                                    .font(Tema.fonte(13))
                                    .foregroundStyle(Tema.tintaSuave)
                            }
                            Spacer()
                            Text(FormatadorDeMoeda.texto(conta.saldoAtual))
                                .font(Tema.fonte(15))
                                .monospacedDigit()
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        .padding(.vertical, 12)
                    }
                    .contextMenu {
                        Button("Eliminar conta", role: .destructive) {
                            contexto.delete(conta)
                            try? contexto.save()
                        }
                    }
                    Divider().overlay(Tema.separador)
                }
            }

            Button("Adicionar conta") { mostrarNovaConta = true }
                .font(Tema.fonte(13, .medium))
                .foregroundStyle(Tema.douradoEscuro)

            Text("Toca numa conta para a tornares principal: é o cartão dourado e a conta usada nos novos registos. Mantém o dedo numa conta para a eliminar.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .sheet(isPresented: $mostrarNovaConta) { FormularioDeConta() }
    }

    /// Só pode haver uma principal — o toque move a estrela.
    private func tornarPrincipal(_ conta: Conta) {
        for outra in contas {
            outra.principal = outra.persistentModelID == conta.persistentModelID
        }
        try? contexto.save()
    }
}

// MARK: - Categorias

private struct CategoriasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @State private var mostrarNovaCategoria = false

    var body: some View {
        PaginaDePerfil(legenda: "ORGANIZA OS GASTOS", titulo: "Categorias") {
            VStack(spacing: 0) {
                ForEach(categorias) { categoria in
                    HStack {
                        Label {
                            Text(categoria.nome)
                                .font(Tema.fonte(15))
                                .foregroundStyle(Tema.tinta)
                        } icon: {
                            Image(systemName: categoria.simbolo)
                                .font(Tema.fonte(13))
                                .foregroundStyle(Tema.douradoEscuro)
                        }
                        Spacer()
                        Text(categoria.orcamentoMensal.map(FormatadorDeMoeda.texto) ?? "—")
                            .font(Tema.fonte(15))
                            .monospacedDigit()
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 12)
                    .contextMenu {
                        Button("Eliminar categoria", role: .destructive) {
                            contexto.delete(categoria)
                            try? contexto.save()
                        }
                    }
                    Divider().overlay(Tema.separador)
                }
            }

            Button("Adicionar categoria") { mostrarNovaCategoria = true }
                .font(Tema.fonte(13, .medium))
                .foregroundStyle(Tema.douradoEscuro)

            Text("O valor à direita é o limite mensal — edita-o no Planear, em \"Editar limites\".")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .sheet(isPresented: $mostrarNovaCategoria) {
            FormularioDeCategoria(proximaOrdem: categorias.count)
        }
    }
}

// MARK: - Contas fixas

private struct RecorrentesView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @State private var mostrarNovaRecorrente = false

    var body: some View {
        PaginaDePerfil(legenda: "TODOS OS MESES, SEM SUSTOS", titulo: "Contas fixas") {
            VStack(spacing: 0) {
                ForEach(recorrentes) { recorrente in
                    LinhaDeRecorrenteEditavel(recorrente: recorrente)
                        .contextMenu {
                            Button("Eliminar recorrente", role: .destructive) {
                                contexto.delete(recorrente)
                                try? contexto.save()
                            }
                        }
                    Divider().overlay(Tema.separador)
                }
            }

            Button("Adicionar recorrente") { mostrarNovaRecorrente = true }
                .font(Tema.fonte(13, .medium))
                .foregroundStyle(Tema.douradoEscuro)

            Text("As recorrentes ativas são descontadas ao mês inteiro no cálculo do número diário. Mantém o dedo numa linha para eliminar.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .sheet(isPresented: $mostrarNovaRecorrente) {
            FormularioDeRecorrente(categorias: categorias)
        }
    }
}

// MARK: - Notificações, aparência e moeda

private struct NotificacoesView: View {
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]

    var body: some View {
        PaginaDePerfil(legenda: "SÓ O QUE IMPORTA", titulo: "Notificações") {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Um lembrete na altura certa.")
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: "bell")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.douradoEscuro)
                }
                Text("Recebes um aviso na véspera de cada conta fixa ativa. Gere as autorizações nas Definições do iPhone.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))

            VStack(spacing: 0) {
                ForEach(recorrentes.filter(\.ativa)) { recorrente in
                    HStack {
                        Text(recorrente.nome)
                            .font(Tema.fonte(15))
                            .foregroundStyle(Tema.tinta)
                        Spacer()
                        Text("véspera do dia \(recorrente.diaDoMes)")
                            .font(Tema.fonte(13))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Tema.separador)
                }
            }

            if !recorrentes.contains(where: \.ativa) {
                Text("Sem recorrentes ativas — ativa uma em Contas fixas para receberes lembretes.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
    }
}

private struct AparenciaView: View {
    var body: some View {
        PaginaDePerfil(legenda: "OURO SOBRE BRANCO", titulo: "Aparência") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Branco")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("O Lume usa o tema claro do design — fundo branco, tinta espresso e ouro nos destaques. No modo escuro do iPhone, a paleta adapta-se sozinha.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                    .strokeBorder(Tema.separador, lineWidth: 1)
            )
        }
    }
}

private struct MoedaView: View {
    var body: some View {
        PaginaDePerfil(legenda: "CONVENÇÕES PORTUGUESAS", titulo: "Moeda") {
            HStack {
                Text("Euro")
                    .font(Tema.fonte(15))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Text("EUR · €")
                    .font(Tema.fonte(15))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(.vertical, 12)
            Divider().overlay(Tema.separador)
            Text("Os valores usam vírgula decimal e espaço nos milhares — \"1 092,90 €\".")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }
}

// MARK: - Inteligência (Claude) e dados

private struct InteligenciaView: View {
    @State private var chaveClaude = CofreDeChaves.ler(CofreDeChaves.contaClaude) ?? ""

    var body: some View {
        PaginaDePerfil(legenda: "A APP FAZ AS CONTAS", titulo: "Inteligência") {
            SecureField("Chave da API (sk-ant-…)", text: $chaveClaude)
                .font(Tema.fonte(15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.campo)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )
                .onChange(of: chaveClaude) {
                    // Guardar texto vazio equivale a apagar do Keychain.
                    CofreDeChaves.guardar(
                        chaveClaude.trimmingCharacters(in: .whitespacesAndNewlines),
                        para: CofreDeChaves.contaClaude
                    )
                }

            Text("Com uma chave da Anthropic, o Claude passa a interpretar os registos, com os interpretadores locais como recurso. A chave fica no Keychain do aparelho e as contas continuam a ser feitas pela app.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }
}

private struct DadosView: View {
    @Environment(\.modelContext) private var contexto
    @State private var confirmarApagarMovimentos = false
    @State private var confirmarReposicao = false

    var body: some View {
        PaginaDePerfil(legenda: "SEM VOLTA A DAR", titulo: "Dados") {
            VStack(spacing: 0) {
                Button("Apagar todos os movimentos", role: .destructive) {
                    confirmarApagarMovimentos = true
                }
                .font(Tema.fonte(15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                Divider().overlay(Tema.separador)
                Button("Repor a app", role: .destructive) {
                    confirmarReposicao = true
                }
                .font(Tema.fonte(15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                Divider().overlay(Tema.separador)
            }

            Text("Repor a app apaga movimentos, recorrentes, categorias, contas, objetivos e definições dos meses.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
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
    }
}

// MARK: - Linhas e formulários partilhados

private struct LinhaDeRecorrenteEditavel: View {
    @Bindable var recorrente: Recorrente

    var body: some View {
        Toggle(isOn: $recorrente.ativa) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recorrente.nome)
                    .font(Tema.fonte(15))
                    .foregroundStyle(Tema.tinta)
                Text("dia \(recorrente.diaDoMes) · \(FormatadorDeMoeda.texto(recorrente.valor))")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
        .tint(Tema.dourado)
        .padding(.vertical, 8)
    }
}

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
        FolhaDeFormulario(
            legenda: "COMEÇA COM O QUE JÁ SABES",
            titulo: "Nova conta",
            textoDoBotao: "Guardar conta",
            podeGuardar: !nome.trimmingCharacters(in: .whitespaces).isEmpty,
            aoGuardar: {
                contexto.insert(Conta(nome: nome, tipo: tipo, saldoInicial: saldoInicial))
                try? contexto.save()
                dismiss()
            }
        ) {
            CampoDeFormulario(legenda: "NOME") {
                TextField("Revolut", text: $nome)
            }
            CampoDeFormulario(legenda: "TIPO") {
                Picker("Tipo", selection: $tipo) {
                    ForEach(TipoConta.allCases, id: \.self) { Text($0.nome).tag($0) }
                }
                .labelsHidden()
                .tint(Tema.tinta)
            }
            CampoDeFormulario(legenda: "SALDO INICIAL") {
                TextField("0 €", value: $saldoInicial, format: moeda)
                    .keyboardType(.decimalPad)
            }
        }
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
        FolhaDeFormulario(
            legenda: "ORGANIZA OS GASTOS",
            titulo: "Nova categoria",
            textoDoBotao: "Guardar categoria",
            podeGuardar: !nome.trimmingCharacters(in: .whitespaces).isEmpty,
            aoGuardar: {
                contexto.insert(Categoria(
                    nome: nome,
                    simbolo: simbolo,
                    corHex: "8E641F",
                    orcamentoMensal: orcamento > .zero ? orcamento : nil,
                    ordem: proximaOrdem
                ))
                try? contexto.save()
                dismiss()
            }
        ) {
            CampoDeFormulario(legenda: "NOME") {
                TextField("Animais", text: $nome)
            }
            CampoDeFormulario(legenda: "SÍMBOLO") {
                Picker("Símbolo", selection: $simbolo) {
                    ForEach(Self.simbolos, id: \.self) { nome in
                        Image(systemName: nome).tag(nome)
                    }
                }
                .labelsHidden()
                .tint(Tema.douradoEscuro)
            }
            CampoDeFormulario(legenda: "LIMITE MENSAL (OPCIONAL)") {
                TextField("0 €", value: $orcamento, format: moeda)
                    .keyboardType(.decimalPad)
            }
        }
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
        FolhaDeFormulario(
            legenda: "TODOS OS MESES, SEM SUSTOS",
            titulo: "Nova recorrente",
            textoDoBotao: "Guardar recorrente",
            podeGuardar: !nome.trimmingCharacters(in: .whitespaces).isEmpty && valor > .zero,
            aoGuardar: {
                contexto.insert(Recorrente(
                    nome: nome,
                    valor: valor,
                    diaDoMes: diaDoMes,
                    categoria: categoria
                ))
                try? contexto.save()
                dismiss()
            }
        ) {
            CampoDeFormulario(legenda: "NOME") {
                TextField("Ginásio", text: $nome)
            }
            CampoDeFormulario(legenda: "VALOR") {
                TextField("0 €", value: $valor, format: moeda)
                    .keyboardType(.decimalPad)
            }
            CampoDeFormulario(legenda: "DIA DO MÊS") {
                Stepper("Dia \(diaDoMes)", value: $diaDoMes, in: 1...31)
                    .font(Tema.fonte(15))
                    .foregroundStyle(Tema.tinta)
            }
            CampoDeFormulario(legenda: "CATEGORIA") {
                Picker("Categoria", selection: $categoria) {
                    Text("Sem categoria").tag(Categoria?.none)
                    ForEach(categorias) { categoria in
                        Text(categoria.nome).tag(Categoria?.some(categoria))
                    }
                }
                .labelsHidden()
                .tint(Tema.tinta)
            }
        }
    }
}

/// Folha de formulário na linguagem dos frames: cabeçalho com legenda,
/// campos com linha fina e botão dourado.
private struct FolhaDeFormulario<Conteudo: View>: View {
    let legenda: String
    let titulo: String
    let textoDoBotao: String
    let podeGuardar: Bool
    let aoGuardar: () -> Void
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(legenda: legenda, titulo: titulo)
                conteudo()
                Button {
                    aoGuardar()
                } label: {
                    Text(textoDoBotao)
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Color(hex: "302B24"))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                }
                .disabled(!podeGuardar)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Campo com a legenda pequena em maiúsculas e uma hairline por baixo.
private struct CampoDeFormulario<Conteudo: View>: View {
    let legenda: String
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(legenda)
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
            conteudo()
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
            Divider().overlay(Tema.separador)
        }
    }
}

#Preview {
    DefinicoesView()
        .modelContainer(ContentorDeDados.emMemoria())
}
