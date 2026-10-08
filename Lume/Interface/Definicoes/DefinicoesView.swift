import Charts
import PhotosUI
import SwiftUI
import SwiftData

/// O Perfil (separador "Perfil"): cartão de perfil com o estado do iCloud,
/// as definições em dois grupos — "O teu dinheiro" e "Preferências" — e a
/// nota de privacidade.
struct DefinicoesView: View {
    @Environment(\.modelContext) private var contexto
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query private var garantias: [Garantia]

    /// O valor por omissão ("O teu nome") vem das versões antigas e conta
    /// como vazio: nunca se mostra como se fosse um nome.
    @AppStorage("nomeDePerfil") private var nomeDePerfil = DefinicoesView.nomePorOmissao
    /// Vazio = sem foto; guardada já pequena e compacta (ver `EditarPerfilView`).
    @AppStorage("fotoDePerfil") private var fotoDePerfilData = Data()
    @State private var aEditarPerfil = false
    /// O Keychain não avisa quando muda: relê-se ao voltar ao Perfil.
    @State private var temChaveClaude = InteligenciaView.temChave
    @AppStorage("bloqueioAtivo") private var bloqueioAtivo = false
    @AppStorage("recebeuPagamentoApplePay") private var recebeuPagamentoApplePay = false

    static let nomePorOmissao = "O teu nome"

    /// Posto a verdadeiro pela RaizView quando o botão "Definir rendimento"
    /// do Resumo manda abrir diretamente a página do rendimento.
    var abrirRendimento: Binding<Bool> = .constant(false)

    private var nome: String? {
        let limpo = nomeDePerfil.trimmingCharacters(in: .whitespaces)
        return limpo.isEmpty || limpo == Self.nomePorOmissao ? nil : limpo
    }

    private var rendimentoDoMes: Decimal? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }?.rendimentoEsperado
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CabecalhoDeEcra(legenda: "Perfil", titulo: "O teu espaço")

                    perfil

                    grupo("O teu dinheiro") {
                        linhaDeNavegacao(
                            "Rendimento do mês",
                            icone: "IconePerfil-rendimento",
                            valor: rendimentoDoMes.flatMap { $0 > .zero ? FormatadorDeMoeda.texto($0) : nil } ?? "Por definir"
                        ) {
                            RendimentoView()
                        }
                        linhaDeNavegacao("Contas e carteiras", icone: "IconePerfil-contas", valor: "\(contas.count) \(contas.count == 1 ? "conta" : "contas")") {
                            ContasECarteirasView()
                        }
                        linhaDeNavegacao("Categorias", icone: "IconePerfil-categorias", valor: "\(categorias.count) \(categorias.count == 1 ? "categoria" : "categorias")") {
                            CategoriasView()
                        }
                        linhaDeNavegacao("Contas fixas", icone: "IconePerfil-fixas", valor: recorrentes.isEmpty ? "Nenhuma" : "\(recorrentes.count) \(recorrentes.count == 1 ? "ativa" : "ativas")") {
                            RecorrentesView()
                        }
                        linhaDeNavegacao("Garantias", simbolo: "shield.lefthalf.filled", valor: garantias.isEmpty ? "Nenhuma" : "\(garantias.count) \(garantias.count == 1 ? "guardada" : "guardadas")") {
                            GarantiasView()
                        }
                    }

                    grupo("Preferências") {
                        linhaDeNavegacao("Tema", icone: "IconePerfil-tema", valor: Tema.paleta.nome) {
                            TemasView()
                        }
                        linhaDeNavegacao("Moeda", icone: "IconePerfil-moeda", valor: "Euro · EUR") {
                            MoedaView()
                        }
                        linhaDeNavegacao("Notificações", icone: "IconePerfil-notificacoes", valor: recorrentes.contains(where: \.ativa) ? "Ativas" : "Desligadas") {
                            NotificacoesView()
                        }
                        // Honesto: sem chave, tudo corre no iPhone.
                        linhaDeNavegacao("Inteligência", icone: "IconePerfil-inteligencia", valor: temChaveClaude ? "Claude" : "No iPhone") {
                            InteligenciaView()
                        }
                        linhaDeNavegacao("Dados", icone: "IconePerfil-dados", valor: "") {
                            DadosView()
                        }
                        linhaDeNavegacao("Botão de Ação", simbolo: "button.programmable", valor: "") {
                            BotaoDeAcaoView()
                        }
                        linhaDeNavegacao("Registo automático", simbolo: "wallet.pass.fill", valor: recebeuPagamentoApplePay ? "Ativo" : "Por configurar") {
                            RegistoAutomaticoView()
                        }
                    }

                    grupo("Privacidade") {
                        linhaDeNavegacao("Bloqueio", simbolo: "faceid", valor: bloqueioAtivo ? "Ativo" : "Desativado") {
                            PrivacidadeView()
                        }
                    }

                    notaDePrivacidade

                    HStack {
                        Button("Ajuda e apoio") {}
                            .font(Tema.fonte(13, .medium))
                            .textoDourado()
                        Spacer()
                        Text("Lume · versão 1.0")
                            .font(Tema.fonte(11))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .background(Tema.fundo)
            // O título dá nome ao voltar do sistema nas sub-páginas.
            .navigationTitle("Perfil")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { temChaveClaude = InteligenciaView.temChave }
            .navigationDestination(isPresented: abrirRendimento) {
                RendimentoView()
            }
        }
        .sheet(isPresented: $aEditarPerfil) {
            EditarPerfilView(nomeDePerfil: $nomeDePerfil, fotoDePerfilData: $fotoDePerfilData)
        }
    }

    // MARK: - Perfil e iCloud

    private var fotoDePerfil: UIImage? {
        fotoDePerfilData.isEmpty ? nil : UIImage(data: fotoDePerfilData)
    }

    /// O cartão de perfil: foto ou avatar, nome (ou o convite para o
    /// adicionar) com um lápis, e a linha do iCloud.
    private var perfil: some View {
        Button {
            aEditarPerfil = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    if let fotoDePerfil {
                        Image(uiImage: fotoDePerfil)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    } else if let nome {
                        AvatarDeIniciais(texto: nome, lado: 48, fundo: Tema.areia)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Tema.tintaSuave)
                            .frame(width: 48, height: 48)
                            .background(Tema.bege, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityHidden(true)
                    }
                    HStack(spacing: 8) {
                        if let nome {
                            Text(nome)
                                .font(Tema.fonte(21, .semibold))
                                .foregroundStyle(Tema.tinta)
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Tema.tintaSuave)
                        } else {
                            // Estado vazio: um convite, não um nome a fingir.
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Adicionar o teu nome")
                                .font(Tema.fonte(17, .semibold))
                        }
                    }
                    .foregroundStyle(nome == nil ? Tema.ouro : AnyShapeStyle(Tema.tinta))
                    Spacer()
                }
                HStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .font(Tema.fonte(13))
                    Text("iCloud atualizado · há instantes")
                        .font(Tema.fonte(12))
                }
                .foregroundStyle(Tema.positivo)
                .frame(height: 32)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartao()
        }
        .buttonStyle(EscalaAoTocar())
        .accessibilityLabel(nome.map { "\($0). Alterar o nome" } ?? "Adicionar o teu nome")
    }

    /// Privacidade em cinza-pedra, com o cadeado de ouro.
    private var notaDePrivacidade: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Os teus dados são teus.")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("Regista sem rede. Tudo fica no teu iPhone e no teu iCloud — a Lume não tem servidores.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Ilustracao(tipo: .cadeado, escala: 0.42)
        }
        .padding(.leading, 18)
        .padding(.vertical, 8)
        .padding(.trailing, 6)
        .cartao(Tema.bege)
        .accessibilityElement(children: .combine)
    }

    /// Um grupo de definições: legenda por cima e as linhas num cartão.
    private func grupo(_ titulo: String, @ViewBuilder linhas: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Legenda(titulo)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                linhas()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .cartao()
        }
    }

    private func linhaDeNavegacao(
        _ titulo: String,
        icone: String,
        valor: String,
        @ViewBuilder destino: @escaping () -> some View
    ) -> some View {
        linha(titulo, valor: valor, destino: destino) {
            // O ícone em ouro polido (render 3D), discreto: 28 pt.
            Image(icone)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .shadow(color: Tema.sombraDoOuro.opacity(0.15), radius: 1.5, y: 1)
        }
    }

    /// Para linhas sem render próprio ainda (ex. Privacidade): o mesmo
    /// mosaico dourado vazio com o símbolo do sistema em relevo, como nas
    /// categorias e nos objetivos.
    private func linhaDeNavegacao(
        _ titulo: String,
        simbolo: String,
        valor: String,
        @ViewBuilder destino: @escaping () -> some View
    ) -> some View {
        linha(titulo, valor: valor, destino: destino) {
            IconeDourado(simbolo: simbolo, lado: 28)
        }
    }

    private func linha(
        _ titulo: String,
        valor: String,
        @ViewBuilder destino: @escaping () -> some View,
        @ViewBuilder icone: () -> some View
    ) -> some View {
        NavigationLink {
            destino()
        } label: {
            HStack(spacing: 12) {
                icone()
                    .accessibilityHidden(true)
                Text(titulo)
                    .font(Tema.fonte(15, .medium))
                    .foregroundStyle(Tema.tinta)
                Spacer(minLength: 8)
                if !valor.isEmpty {
                    Text(valor)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tema.placeholder)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Estrutura comum das sub-páginas

/// Sub-página do Perfil: o cabeçalho padrão e o fundo da app. Empurrada
/// pela pilha do Perfil, usa o voltar do sistema; apresentada numa folha,
/// recebe `aoFechar` e mostra o botão de fechar.
/// Foto e nome, numa só folha — em vez do alerta só de texto que havia antes.
private struct EditarPerfilView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var nomeDePerfil: String
    @Binding var fotoDePerfilData: Data

    @State private var nomeEmEdicao: String
    @State private var itemEscolhido: PhotosPickerItem?

    init(nomeDePerfil: Binding<String>, fotoDePerfilData: Binding<Data>) {
        self._nomeDePerfil = nomeDePerfil
        self._fotoDePerfilData = fotoDePerfilData
        let atual = nomeDePerfil.wrappedValue
        self.nomeEmEdicao = atual == DefinicoesView.nomePorOmissao ? "" : atual
    }

    private var foto: UIImage? {
        fotoDePerfilData.isEmpty ? nil : UIImage(data: fotoDePerfilData)
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                BotaoRedondo(simbolo: "xmark", rotulo: "Fechar") { dismiss() }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 8)

            PhotosPicker(selection: $itemEscolhido, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let foto {
                        Image(uiImage: foto)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Tema.areia)
                            .frame(width: 96, height: 96)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Tema.tintaSuave)
                            }
                    }
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tema.superficie)
                        .padding(8)
                        .background(Tema.douradoEscuro, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mudar foto de perfil")

            if foto != nil {
                Button("Remover foto", role: .destructive) { fotoDePerfilData = Data() }
                    .font(Tema.fonte(13, .medium))
            }

            VStack(alignment: .leading, spacing: 6) {
                Legenda("NOME")
                TextField(text: $nomeEmEdicao, prompt: Text("O teu nome").foregroundStyle(Tema.placeholder)) {
                    Text("Nome")
                }
                .font(Tema.fonte(17, .medium))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Tema.bege, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            }
            .padding(.horizontal, Tema.margemDoEcra)

            BotaoLume(titulo: "Guardar", simbolo: "checkmark") {
                let limpo = nomeEmEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
                nomeDePerfil = limpo.isEmpty ? DefinicoesView.nomePorOmissao : limpo
                dismiss()
            }
            .padding(.horizontal, Tema.margemDoEcra)

            Spacer()
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .task(id: itemEscolhido) {
            guard let itemEscolhido,
                  let dados = try? await itemEscolhido.loadTransferable(type: Data.self),
                  let imagem = UIImage(data: dados)
            else { return }
            fotoDePerfilData = Self.comprimida(imagem)
        }
    }

    /// 300 pt no lado maior, JPEG a 80% — chega de sobra para um avatar e
    /// mantém o UserDefaults leve.
    private static func comprimida(_ imagem: UIImage) -> Data {
        let alvo: CGFloat = 300
        let escala = min(alvo / imagem.size.width, alvo / imagem.size.height, 1)
        let novoTamanho = CGSize(width: imagem.size.width * escala, height: imagem.size.height * escala)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let imagemRedimensionada = UIGraphicsImageRenderer(size: novoTamanho, format: formato).image { _ in
            imagem.draw(in: CGRect(origin: .zero, size: novoTamanho))
        }
        return imagemRedimensionada.jpegData(compressionQuality: 0.8) ?? Data()
    }
}

private struct PaginaDePerfil<Conteudo: View>: View {
    let legenda: String
    let titulo: String
    var aoFechar: (() -> Void)?
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(legenda: legenda, titulo: titulo, aoVoltar: aoFechar, simboloDeVoltar: "xmark")
                conteudo()
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, aoFechar == nil ? 4 : 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .toolbarBackground(Tema.fundo, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Tema.douradoEscuro)
    }
}

// MARK: - Rendimento do mês

/// O rendimento esperado do mês corrente: é daqui que sai o disponível e
/// o valor por dia do Resumo.
private struct RendimentoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Query private var definicoes: [DefinicoesDoMes]

    private var definicoesDoMes: DefinicoesDoMes? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }
    }

    /// Sem `@Attribute(.unique)` (CloudKit), procura-se antes de inserir.
    private func garantirDefinicoes() {
        guard definicoesDoMes == nil else { return }
        let calendario = Calendar.current
        contexto.insert(DefinicoesDoMes(
            ano: calendario.component(.year, from: .now),
            mes: calendario.component(.month, from: .now)
        ))
        try? contexto.save()
    }

    var body: some View {
        PaginaDePerfil(
            legenda: Date.now.formatted(.dateTime.month(.wide).year().locale(FormatadorDeMoeda.localidade)).uppercased(),
            titulo: "Rendimento do mês"
        ) {
            if let selecionadas = definicoesDoMes {
                cartao(selecionadas)
            }

            BotaoLume(titulo: "Guardar rendimento") {
                try? contexto.save()
                dismiss()
            }

            Text("Conta o que esperas receber este mês: salário, bolsa ou mesada. Os limites por categoria continuam no Planear, em \"Editar limites\".")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .onAppear { garantirDefinicoes() }
    }

    private func cartao(_ selecionadas: DefinicoesDoMes) -> some View {
        @Bindable var selecionadas = selecionadas
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Legenda("Quanto vais receber")
                // Zero conta como vazio: mostra-se o marcador "0,00 €" em
                // cinzento, não um valor de zero.
                TextField(
                    value: Binding<Decimal?>(
                        get: { selecionadas.rendimentoEsperado > .zero ? selecionadas.rendimentoEsperado : nil },
                        set: { selecionadas.rendimentoEsperado = $0 ?? .zero }
                    ),
                    format: .euros,
                    prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)
                ) {
                    Text("Rendimento do mês")
                }
                    .keyboardType(.decimalPad)
                    .font(Tema.fonte(31, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
                Text("É a base do teu disponível e do valor por dia.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Ilustracao(tipo: .carteira, escala: 0.45)
        }
        .padding(16)
        .cartaoCafe()
    }
}

// MARK: - Contas e carteiras

private struct ContasECarteirasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @State private var mostrarNovaConta = false

    var body: some View {
        PaginaDePerfil(legenda: "O teu dinheiro", titulo: "Contas e carteiras") {
            CarrosselDeContas()
                .padding(.horizontal, -Tema.margemDoEcra)

            // O resumo de cada conta (recebido, gasto, movimentos) vive no
            // ecrã Contas; aqui gere-se a lista.
            NavigationLink {
                ContasView()
            } label: {
                HStack {
                    Text("Ver resumo e movimentos das contas")
                        .font(Tema.fonte(15, .medium))
                        .textoDourado()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tema.placeholder)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .cartao()
            }
            .buttonStyle(.plain)

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

            BotaoLume(titulo: "Adicionar conta", simbolo: "plus", estilo: .secundario) { mostrarNovaConta = true }

            Text("Toca numa conta para a tornares principal: é o cartão dourado e a conta usada nos novos registos. Mantém o dedo numa conta para a eliminar.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        // Contas novas ou eliminadas entram e saem com mola.
        .animation(.snappy, value: contas.count)
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
        PaginaDePerfil(legenda: "O teu dinheiro", titulo: "Categorias") {
            VStack(spacing: 0) {
                ForEach(categorias) { categoria in
                    HStack {
                        // Categorias são "coisas": ícone 3D, como no resto da app.
                        HStack(spacing: 12) {
                            IconeDeCategoria(categoria: categoria, lado: 32)
                            Text(categoria.nome)
                                .font(Tema.fonte(15))
                                .foregroundStyle(Tema.tinta)
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

            BotaoLume(titulo: "Adicionar categoria", simbolo: "plus", estilo: .secundario) { mostrarNovaCategoria = true }

            Text("O valor à direita é o limite mensal — edita-o no Planear, em \"Editar limites\".")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .animation(.snappy, value: categorias.count)
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
    @Query private var transacoes: [Transacao]
    @Query private var sugestoesIgnoradas: [SugestaoDeRecorrenteIgnorada]
    @State private var mostrarNovaRecorrente = false

    private var custoAnualTotal: Decimal {
        recorrentes.filter(\.ativa).reduce(.zero) { $0 + AnaliseDeRecorrentes.custoAnual($1.valor) }
    }

    private var sugestoes: [AnaliseDeRecorrentes.Sugestao] {
        let calendario = Calendar.current
        let pagamentos = transacoes.compactMap { transacao -> AnaliseDeRecorrentes.Pagamento? in
            guard transacao.tipo == .despesa, transacao.recorrente == nil,
                  let loja = transacao.loja, !loja.isEmpty else { return nil }
            let componentes = calendario.dateComponents([.year, .month], from: transacao.data)
            guard let ano = componentes.year, let mes = componentes.month else { return nil }
            return AnaliseDeRecorrentes.Pagamento(nome: loja, valor: transacao.valor, mes: mes, ano: ano)
        }
        return AnaliseDeRecorrentes.sugerirNovasRecorrentes(
            pagamentos: pagamentos,
            nomesExistentes: Set(recorrentes.map(\.nome)),
            nomesIgnorados: Set(sugestoesIgnoradas.map(\.nome))
        )
    }

    var body: some View {
        PaginaDePerfil(legenda: "O teu dinheiro", titulo: "Contas fixas") {
            if custoAnualTotal > .zero {
                VStack(alignment: .leading, spacing: 4) {
                    Legenda("Por ano, nas ativas")
                    Text(FormatadorDeMoeda.texto(custoAnualTotal))
                        .font(Tema.fonte(26, .semibold))
                        .foregroundStyle(Tema.tinta)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .cartaoCafe()
            }

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

            BotaoLume(titulo: "Adicionar recorrente", simbolo: "plus", estilo: .secundario) { mostrarNovaRecorrente = true }

            if !sugestoes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Legenda("Talvez também sejam fixas")
                    ForEach(sugestoes, id: \.nome) { sugestao in
                        linhaDeSugestao(sugestao)
                    }
                }
            }

            Text("As recorrentes ativas são descontadas ao mês inteiro no cálculo do número diário. Mantém o dedo numa linha para eliminar.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
        .animation(.snappy, value: recorrentes.count)
        .sheet(isPresented: $mostrarNovaRecorrente) {
            FormularioDeRecorrente(categorias: categorias)
        }
    }

    private func linhaDeSugestao(_ sugestao: AnaliseDeRecorrentes.Sugestao) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pagaste \(sugestao.nome) com um valor parecido em 3 meses seguidos — \(FormatadorDeMoeda.texto(sugestao.valorMedio))/mês.")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tinta)
            HStack(spacing: 10) {
                BotaoLume(titulo: "Tornar fixa", simbolo: "plus", estilo: .secundario) {
                    let diaDoMes = transacoes
                        .filter { $0.loja == sugestao.nome }
                        .sorted { $0.data > $1.data }
                        .first
                        .map { Calendar.current.component(.day, from: $0.data) } ?? 1
                    contexto.insert(Recorrente(nome: sugestao.nome, valor: sugestao.valorMedio, diaDoMes: diaDoMes))
                    try? contexto.save()
                }
                BotaoLume(titulo: "Ignorar", simbolo: "xmark", estilo: .texto) {
                    contexto.insert(SugestaoDeRecorrenteIgnorada(nome: sugestao.nome))
                    try? contexto.save()
                }
            }
        }
        .padding(16)
        .cartao()
    }
}

// MARK: - Notificações, aparência e moeda

private struct NotificacoesView: View {
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]

    var body: some View {
        PaginaDePerfil(legenda: "Preferências", titulo: "Notificações") {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Um lembrete na altura certa.")
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: "bell")
                        .font(Tema.fonte(13))
                        .textoDourado()
                }
                Text("Recebes um aviso na véspera de cada conta fixa ativa. Gere as autorizações nas Definições do iPhone.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cartao(Tema.bege)

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

private struct BotaoDeAcaoView: View {
    var body: some View {
        PaginaDePerfil(legenda: "Preferências", titulo: "Botão de Ação") {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Fala assim que carregas.")
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: "button.programmable")
                        .font(Tema.fonte(13))
                        .textoDourado()
                }
                Text("Nos iPhone 15 Pro e seguintes, o Botão de Ação pode abrir a Lume já a ouvir, pronta para registares uma despesa a falar.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cartao(Tema.bege)

            VStack(alignment: .leading, spacing: 14) {
                passo(numero: 1, texto: "Abre Definições → Botão de Ação.")
                passo(numero: 2, texto: "Desliza até à opção \"Atalho\".")
                passo(numero: 3, texto: "Escolhe \"Registar por voz\" na lista.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .cartao()

            Text("Sem Botão de Ação, o mesmo atalho funciona por Siri: \"Ei Siri, registar por voz no Lume\".")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    private func passo(numero: Int, texto: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(numero)")
                .font(Tema.fonte(13, .semibold))
                .foregroundStyle(Tema.ouro)
                .frame(width: 18)
            Text(texto)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tinta)
        }
        .padding(.vertical, 10)
    }
}

private struct RegistoAutomaticoView: View {
    @Environment(\.openURL) private var abrirURL
    @Environment(\.modelContext) private var contexto
    @Query private var cartoes: [CartaoDaCarteira]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @AppStorage("recebeuPagamentoApplePay") private var recebeuPagamentoApplePay = false

    var body: some View {
        PaginaDePerfil(legenda: "Preferências", titulo: "Registo automático") {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(recebeuPagamentoApplePay ? "Ativo" : "Ainda por configurar")
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: "wallet.pass.fill")
                        .font(Tema.fonte(13))
                        .textoDourado()
                }
                Text("Quando pagas com Apple Pay, a Lume regista a despesa sozinha, a partir de uma automação que crias uma vez nos Atalhos.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cartao(Tema.bege)

            VStack(alignment: .leading, spacing: 14) {
                passo(numero: 1, texto: "Na app Atalhos, cria uma Automação Pessoal do tipo \"Transação\" e escolhe os teus cartões.")
                passo(numero: 2, texto: "Desliga \"Perguntar antes de executar\" para correr sozinha, sem notificação a pedir confirmação.")
                passo(numero: 3, texto: "Adiciona a ação \"Registar pagamento\" da Lume, com Comerciante, Valor e Cartão como variáveis da transação.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .cartao()

            BotaoLume(titulo: "Abrir a app Atalhos", simbolo: "arrow.up.right.square") {
                if let endereco = URL(string: "shortcuts://") {
                    abrirURL(endereco)
                }
            }

            if !cartoes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Legenda("Cartões associados")
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    ForEach(cartoes) { cartao in
                        linhaDoCartao(cartao)
                        if cartao.persistentModelID != cartoes.last?.persistentModelID {
                            Divider().overlay(Tema.separador)
                        }
                    }
                }
            }

            Text("Só funciona com pagamentos Apple Pay. Compras online, débitos diretos e pagamentos com o cartão físico não entram — regista-os à mão, como sempre.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    private func passo(numero: Int, texto: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(numero)")
                .font(Tema.fonte(13, .semibold))
                .foregroundStyle(Tema.ouro)
                .frame(width: 18)
            Text(texto)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tinta)
        }
        .padding(.vertical, 10)
    }

    private func linhaDoCartao(_ cartao: CartaoDaCarteira) -> some View {
        HStack {
            Text(cartao.nomeDoCartao)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tinta)
                .lineLimit(1)
            Spacer(minLength: 8)
            Menu {
                Picker("Conta", selection: Binding(
                    get: { cartao.conta },
                    set: { cartao.conta = $0; try? contexto.save() }
                )) {
                    Text("Nenhuma").tag(Conta?.none)
                    ForEach(contas) { conta in
                        Text(conta.nome).tag(Conta?.some(conta))
                    }
                }
            } label: {
                Text(cartao.conta?.nome ?? "Escolher")
                    .font(Tema.fonte(13, .medium))
                    .textoDourado()
            }
        }
        .padding(.vertical, 10)
    }
}

/// Duas folhas num só ecrã: primeiro cria-se o código, depois confirma-se
/// — só fica guardado (e ativo) se as duas vezes baterem certo.
private struct DefinirCodigoView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var codigoAtivo: Bool

    @State private var primeiroCodigo: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                BotaoRedondo(simbolo: "xmark", rotulo: "Fechar") { dismiss() }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 8)

            Spacer()
            if let primeiroCodigo {
                TecladoDeCodigo(titulo: "Confirma o código") { segundo in
                    guard segundo == primeiroCodigo else { return false }
                    CofreDeChaves.guardar(segundo, para: CofreDeChaves.contaCodigoDeBloqueio)
                    codigoAtivo = true
                    dismiss()
                    return true
                }
                .id("confirmar")
            } else {
                TecladoDeCodigo(titulo: "Cria um código de 4 dígitos") { codigo in
                    primeiroCodigo = codigo
                    return true
                }
                .id("criar")
            }
            Spacer()
        }
        .background(Tema.fundo)
    }
}

private struct PrivacidadeView: View {
    @AppStorage("bloqueioAtivo") private var bloqueioAtivo = false
    @AppStorage("bloqueioApos") private var bloqueioAposRaw = AtrasoDoBloqueio.imediato.rawValue
    @AppStorage("esconderValoresNoWidget") private var esconderValoresNoWidget = false
    @AppStorage("codigoDeBloqueioAtivo") private var codigoAtivo = false
    @AppStorage("preferirCodigo") private var preferirCodigo = false
    @State private var mostrarDefinirCodigo = false

    private var atraso: Binding<AtrasoDoBloqueio> {
        Binding(
            get: { AtrasoDoBloqueio(rawValue: bloqueioAposRaw) ?? .imediato },
            set: { bloqueioAposRaw = $0.rawValue }
        )
    }

    var body: some View {
        PaginaDePerfil(legenda: "Perfil", titulo: "Privacidade") {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("A tua identidade, só tua.")
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Tema.tinta)
                } icon: {
                    Image(systemName: "faceid")
                        .font(Tema.fonte(13))
                        .textoDourado()
                }
                Text("Com o bloqueio ativo, a Lume pede Face ID (ou o código do iPhone) sempre que voltas à app.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cartao(Tema.bege)

            VStack(spacing: 0) {
                HStack {
                    Text("Bloquear a Lume")
                        .font(Tema.fonte(15))
                        .foregroundStyle(Tema.tinta)
                    Spacer()
                    Toggle("Bloquear a Lume", isOn: $bloqueioAtivo)
                        .labelsHidden()
                        .tint(Tema.dourado)
                }
                .padding(.vertical, 12)

                if bloqueioAtivo {
                    Divider().overlay(Tema.separador)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PEDIR OUTRA VEZ")
                            .font(Tema.fonte(11, .semibold))
                            .foregroundStyle(Tema.tintaSuave)
                            .padding(.top, 12)
                        Picker("Pedir outra vez", selection: atraso) {
                            ForEach(AtrasoDoBloqueio.allCases) { opcao in
                                Text(opcao.nomeCurto).tag(opcao).accessibilityLabel(opcao.nome)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .cartao()
            .animation(.snappy(duration: 0.2), value: bloqueioAtivo)

            if bloqueioAtivo {
                VStack(spacing: 0) {
                    Button { mostrarDefinirCodigo = true } label: {
                        HStack {
                            Text("Código da Lume")
                                .font(Tema.fonte(15))
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Text(codigoAtivo ? "Definido" : "Por definir")
                                .font(Tema.fonte(13))
                                .foregroundStyle(Tema.tintaSuave)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tema.placeholder)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if codigoAtivo {
                        Divider().overlay(Tema.separador)
                        HStack {
                            Text("Preferir código a Face ID")
                                .font(Tema.fonte(15))
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Toggle("Preferir código a Face ID", isOn: $preferirCodigo)
                                .labelsHidden()
                                .tint(Tema.dourado)
                        }
                        .padding(.vertical, 12)

                        Divider().overlay(Tema.separador)
                        Button("Remover código", role: .destructive) {
                            CofreDeChaves.apagar(CofreDeChaves.contaCodigoDeBloqueio)
                            codigoAtivo = false
                            preferirCodigo = false
                        }
                        .font(Tema.fonte(14, .medium))
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .cartao()
                .animation(.snappy(duration: 0.2), value: codigoAtivo)
                .sheet(isPresented: $mostrarDefinirCodigo) {
                    DefinirCodigoView(codigoAtivo: $codigoAtivo)
                }

                Text("Com um código definido, é ele a reserva do Face ID — não o código do iPhone.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Esconder valores")
                            .font(Tema.fonte(15))
                            .foregroundStyle(Tema.tinta)
                        Text("No widget e no ecrã bloqueado.")
                            .font(Tema.fonte(12))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    Spacer()
                    Toggle("Esconder valores", isOn: $esconderValoresNoWidget)
                        .labelsHidden()
                        .tint(Tema.dourado)
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .cartao()

            Text("O registo por Siri e Atalhos continua a funcionar com a Lume bloqueada; abrir a app pede sempre autenticação.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }
}

private struct MoedaView: View {
    var body: some View {
        PaginaDePerfil(legenda: "Preferências", titulo: "Moeda") {
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

/// Onde a Lume pensa: no iPhone por omissão; com uma chave da Anthropic,
/// o Claude passa a interpretar os registos e liga o "Vale a pena?".
///
/// Também se abre do "Vale a pena?", numa folha (`aoFechar`).
struct InteligenciaView: View {
    var aoFechar: (() -> Void)?

    @State private var chaveClaude = CofreDeChaves.ler(CofreDeChaves.contaClaude) ?? ""

    /// Se há uma chave do Claude guardada no Keychain.
    static var temChave: Bool {
        CofreDeChaves.ler(CofreDeChaves.contaClaude)?.isEmpty == false
    }

    private var comChave: Bool {
        !chaveClaude.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        PaginaDePerfil(legenda: "Preferências", titulo: "Inteligência", aoFechar: aoFechar) {
            estado

            VStack(alignment: .leading, spacing: 8) {
                Legenda("Chave da Anthropic (opcional)")
                SecureField(text: $chaveClaude, prompt: Text("sk-ant-…").foregroundStyle(Tema.placeholder)) {
                    Text("Chave da Anthropic")
                }
                .font(Tema.fonte(15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .padding(.horizontal, 14)
                .frame(height: 48)
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
                Text("Cria-a em console.anthropic.com. Fica no Keychain deste iPhone e nunca sai daqui, a não ser nos pedidos ao Claude.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                linha("iphone", "Registos por texto, voz e talão", "No iPhone, sempre. Com a chave, o Claude percebe frases mais difíceis.")
                Divider().overlay(Tema.separador)
                linha("checkmark.seal", "\"Vale a pena?\"", "Precisa da chave: procura preços e opiniões na internet.")
                Divider().overlay(Tema.separador)
                linha("function", "As contas do mês", "Feitas sempre pela app, nunca por um modelo.")
            }
            .padding(.horizontal, 16)
            .cartao()

            if comChave, aoFechar != nil {
                BotaoLume(titulo: "Feito", simbolo: "checkmark") { aoFechar?() }
            }
        }
    }

    /// O que está ligado agora, em palavras simples.
    private var estado: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: comChave ? "sparkles" : "iphone")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Tema.ouro)
                .frame(width: 36, height: 36)
                .background(Tema.superficie, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(comChave ? "Análise inteligente ligada" : "Tudo no teu iPhone")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text(comChave
                    ? "O Claude interpreta os registos e responde ao \"Vale a pena?\". Se falhar, a Lume volta ao que corre no iPhone."
                    : "A Lume percebe os teus registos sem enviar nada para fora. Para usar o \"Vale a pena?\", adiciona uma chave da Anthropic.")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao(Tema.bege)
        .accessibilityElement(children: .combine)
    }

    private func linha(_ simbolo: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: simbolo)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Tema.tintaSuave)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                Text(texto)
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct DadosView: View {
    @Environment(\.modelContext) private var contexto
    @State private var confirmarApagarMovimentos = false
    @State private var confirmarReposicao = false
    @State private var confirmarDadosDeTeste = false
    @State private var dadosDeTesteCarregados = false

    var body: some View {
        PaginaDePerfil(legenda: "Preferências", titulo: "Dados") {
            // Para experimentar a app cheia: três meses de movimentos,
            // categorias com limites, contas, contas fixas e objetivos.
            VStack(alignment: .leading, spacing: 8) {
                BotaoLume(titulo: "Carregar dados de teste", simbolo: "wand.and.stars", estilo: .secundario) {
                    confirmarDadosDeTeste = true
                }
                Text(dadosDeTesteCarregados
                    ? "Dados de teste carregados. Vê o Resumo."
                    : "Substitui tudo por dados realistas: três meses de movimentos, limites, contas e objetivos.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(dadosDeTesteCarregados ? AnyShapeStyle(Tema.positivo) : AnyShapeStyle(Tema.tintaSuave))
            }

            VStack(spacing: 10) {
                BotaoLume(titulo: "Apagar todos os movimentos", simbolo: "trash", estilo: .destrutivo) {
                    confirmarApagarMovimentos = true
                }
                BotaoLume(titulo: "Repor a app", simbolo: "arrow.counterclockwise", estilo: .destrutivo) {
                    confirmarReposicao = true
                }
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
        .confirmationDialog("Carregar dados de teste?", isPresented: $confirmarDadosDeTeste, titleVisibility: .visible) {
            Button("Substituir pelos dados de teste", role: .destructive) {
                DadosDeExemplo.recarregar(em: contexto)
                dadosDeTesteCarregados = true
            }
        } message: {
            Text("Os teus dados atuais são apagados e trocados por dados de exemplo.")
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
    @State private var mostrarDetalhe = false

    var body: some View {
        HStack(spacing: 10) {
            Button { mostrarDetalhe = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recorrente.nome)
                        .font(Tema.fonte(15))
                        .foregroundStyle(Tema.tinta)
                    Text("dia \(recorrente.diaDoMes) · \(FormatadorDeMoeda.texto(recorrente.valor))")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("Ativa", isOn: $recorrente.ativa)
                .labelsHidden()
                .tint(Tema.dourado)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $mostrarDetalhe) {
            DetalheDaRecorrente(recorrente: recorrente)
        }
    }
}

private struct DetalheDaRecorrente: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Bindable var recorrente: Recorrente

    @State private var temFidelizacao: Bool
    @State private var fidelizacao: Date

    init(recorrente: Recorrente) {
        self.recorrente = recorrente
        self.temFidelizacao = recorrente.fimDaFidelizacao != nil
        self.fidelizacao = recorrente.fimDaFidelizacao ?? Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
    }

    private var pagamentosOrdenados: [Transacao] {
        (recorrente.pagamentos ?? []).sorted { $0.data < $1.data }
    }

    private var subida: AnaliseDeRecorrentes.Subida? {
        AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: pagamentosOrdenados.map(\.valor))
    }

    /// Há mais de 90 dias sem perguntar, e vale a pena perguntar.
    private var devePerguntarSeAindaUsa: Bool {
        guard recorrente.eSubscricao else { return false }
        guard let ultima = recorrente.ultimaPerguntaDeUso else { return true }
        return Date.now.timeIntervalSince(ultima) > 90 * 86_400
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(legenda: "Contas fixas", titulo: recorrente.nome, aoVoltar: { dismiss() }, simboloDeVoltar: "xmark")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Legenda("Por mês")
                            ValorEmEuros(valor: recorrente.valor, tamanho: 28)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Legenda("Por ano")
                            Text(FormatadorDeMoeda.texto(AnaliseDeRecorrentes.custoAnual(recorrente.valor)))
                                .font(Tema.fonte(17, .semibold))
                                .foregroundStyle(Tema.tinta)
                        }
                    }
                    if pagamentosOrdenados.count >= 2 {
                        Chart(pagamentosOrdenados) { pagamento in
                            LineMark(x: .value("Data", pagamento.data), y: .value("Valor", (pagamento.valor as NSDecimalNumber).doubleValue))
                                .foregroundStyle(Tema.douradoDaBarra)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            PointMark(x: .value("Data", pagamento.data), y: .value("Valor", (pagamento.valor as NSDecimalNumber).doubleValue))
                                .foregroundStyle(Tema.douradoDaBarra)
                                .symbolSize(18)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 50)
                        .padding(.top, 6)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartao()

                if let subida {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subiu \(FormatadorDeMoeda.texto(subida.diferenca)) (+\(Int((subida.fracao * 100).rounded()))%)")
                            .font(Tema.fonte(15, .semibold))
                            .foregroundStyle(Tema.tinta)
                        Text("De \(FormatadorDeMoeda.texto(subida.valorAntes)) para \(FormatadorDeMoeda.texto(subida.valorDepois)).")
                            .font(Tema.fonte(13))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .cartaoCafe()
                }

                if devePerguntarSeAindaUsa {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ainda usas \(recorrente.nome)?")
                            .font(Tema.fonte(15, .semibold))
                            .foregroundStyle(Tema.tinta)
                        HStack(spacing: 10) {
                            BotaoLume(titulo: "Sim", simbolo: "checkmark", estilo: .secundario) {
                                recorrente.ultimaPerguntaDeUso = .now
                                try? contexto.save()
                            }
                            BotaoLume(titulo: "Já não", simbolo: "xmark", estilo: .destrutivo) {
                                recorrente.ultimaPerguntaDeUso = .now
                                recorrente.ativa = false
                                try? contexto.save()
                            }
                        }
                    }
                    .padding(16)
                    .cartao(Tema.bege)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Toggle("É uma subscrição", isOn: $recorrente.eSubscricao)
                        .font(Tema.fonte(14))
                        .tint(Tema.dourado)
                    Divider().overlay(Tema.separador)
                    Toggle("Com fim de fidelização", isOn: $temFidelizacao)
                        .font(Tema.fonte(14))
                        .tint(Tema.dourado)
                    if temFidelizacao {
                        DatePicker("Acaba a", selection: $fidelizacao, displayedComponents: .date)
                            .font(Tema.fonte(14))
                            .environment(\.locale, FormatadorDeMoeda.localidade)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .cartao()
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .onChange(of: temFidelizacao) { _, novo in
            recorrente.fimDaFidelizacao = novo ? fidelizacao : nil
            try? contexto.save()
        }
        .onChange(of: fidelizacao) { _, novo in
            guard temFidelizacao else { return }
            recorrente.fimDaFidelizacao = novo
            try? contexto.save()
        }
        .onChange(of: recorrente.eSubscricao) {
            try? contexto.save()
        }
    }
}

/// Um campo de texto com o marcador em cinzento legível (≥3,5:1).
private func campoDeTexto(_ exemplo: String, texto: Binding<String>) -> some View {
    TextField(text: texto, prompt: Text(exemplo).foregroundStyle(Tema.placeholder)) {
        Text(exemplo)
    }
}

/// Um campo de euros vazio por omissão: "0,00 €" é o marcador, não um valor.
private func campoDeEuros(_ valor: Binding<Decimal?>) -> some View {
    TextField(value: valor, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
        Text("Valor")
    }
    .keyboardType(.decimalPad)
    .monospacedDigit()
}

private struct FormularioDeConta: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    @State private var nome = ""
    @State private var tipo = TipoConta.aOrdem
    @State private var saldoInicial: Decimal?

    var body: some View {
        FolhaDeFormulario(
            legenda: "Contas e carteiras",
            titulo: "Nova conta",
            textoDoBotao: "Guardar conta",
            podeGuardar: !nome.trimmingCharacters(in: .whitespaces).isEmpty,
            aoGuardar: {
                contexto.insert(Conta(nome: nome, tipo: tipo, saldoInicial: saldoInicial ?? .zero))
                try? contexto.save()
                dismiss()
            }
        ) {
            CampoDeFormulario(legenda: "NOME") {
                campoDeTexto("Ex.: Revolut", texto: $nome)
            }
            CampoDeFormulario(legenda: "TIPO") {
                Picker("Tipo", selection: $tipo) {
                    ForEach(TipoConta.allCases, id: \.self) { Text($0.nome).tag($0) }
                }
                .labelsHidden()
                .tint(Tema.tinta)
            }
            CampoDeFormulario(legenda: "SALDO INICIAL") {
                campoDeEuros($saldoInicial)
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
    @State private var orcamento: Decimal?

    private static let simbolos = [
        "tag", "cart.fill", "fork.knife", "tram.fill", "house.fill",
        "play.rectangle.fill", "cross.case.fill", "ticket.fill",
        "gift.fill", "pawprint.fill", "book.fill", "tshirt.fill",
        "banknote.fill", "airplane", "briefcase.fill", "ellipsis",
    ]

    var body: some View {
        FolhaDeFormulario(
            legenda: "Categorias",
            titulo: "Nova categoria",
            textoDoBotao: "Guardar categoria",
            podeGuardar: !nome.trimmingCharacters(in: .whitespaces).isEmpty,
            aoGuardar: {
                contexto.insert(Categoria(
                    nome: nome,
                    simbolo: simbolo,
                    corHex: "8E641F",
                    orcamentoMensal: (orcamento ?? .zero) > .zero ? orcamento : nil,
                    ordem: proximaOrdem
                ))
                try? contexto.save()
                dismiss()
            }
        ) {
            CampoDeFormulario(legenda: "NOME") {
                campoDeTexto("Ex.: Animais", texto: $nome)
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
                campoDeEuros($orcamento)
            }
        }
    }
}

private struct FormularioDeRecorrente: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let categorias: [Categoria]

    @State private var nome = ""
    @State private var valor: Decimal?
    @State private var diaDoMes = 1
    @State private var categoria: Categoria?
    @State private var eSubscricao = false

    var body: some View {
        FolhaDeFormulario(
            legenda: "Contas fixas",
            titulo: "Nova recorrente",
            textoDoBotao: "Guardar recorrente",
            podeGuardar: !nome.trimmingCharacters(in: .whitespaces).isEmpty && (valor ?? .zero) > .zero,
            aoGuardar: {
                contexto.insert(Recorrente(
                    nome: nome,
                    valor: valor ?? .zero,
                    diaDoMes: diaDoMes,
                    categoria: categoria,
                    eSubscricao: eSubscricao
                ))
                try? contexto.save()
                dismiss()
            }
        ) {
            CampoDeFormulario(legenda: "NOME") {
                campoDeTexto("Ex.: Ginásio", texto: $nome)
            }
            CampoDeFormulario(legenda: "VALOR") {
                campoDeEuros($valor)
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
            CampoDeFormulario(legenda: "SUBSCRIÇÃO") {
                Toggle("É uma subscrição", isOn: $eSubscricao)
                    .labelsHidden()
                    .tint(Tema.dourado)
            }
        }
    }
}

/// Folha de formulário: cabeçalho padrão com fechar, campos com linha fina
/// e o botão principal (cinzento enquanto não se pode guardar).
private struct FolhaDeFormulario<Conteudo: View>: View {
    @Environment(\.dismiss) private var dismiss

    let legenda: String
    let titulo: String
    let textoDoBotao: String
    let podeGuardar: Bool
    let aoGuardar: () -> Void
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(legenda: legenda, titulo: titulo, aoVoltar: { dismiss() }, simboloDeVoltar: "xmark")
                conteudo()
                BotaoLume(titulo: textoDoBotao, acao: aoGuardar)
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
            Legenda(legenda)
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
