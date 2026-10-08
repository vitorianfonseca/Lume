import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Modo de entrada do registo — texto, voz ou talão.
enum ModoDeRegisto: String, CaseIterable, Identifiable {
    case texto = "Texto"
    case voz = "Voz"
    case talao = "Talão"

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .texto: "character.cursor.ibeam"
        case .voz: "mic"
        case .talao: "camera"
        }
    }

    /// A legenda explica o fluxo de cada modo em três passos — contexto,
    /// não slogan (auditoria UX). O título fica sempre "Registar".
    var legenda: String {
        switch self {
        case .texto: "ESCREVE. CONFIRMA. FEITO."
        case .voz: "FALA. CONFIRMA. FEITO."
        case .talao: "FOTOGRAFA. CONFIRMA. FEITO."
        }
    }
}

/// O ecrã Registar: texto (com pré-visualização ao vivo, exemplos e os
/// últimos registos), voz (o cartão é o botão do microfone, com os estados
/// a ouvir / a perceber / erro / sem permissão) e talão (fotografar ou
/// escolher da galeria).
struct RegistarView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.openURL) private var abrirURL
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    /// Editável em Perfil → Garantias; por defeito, o do ficheiro de regras.
    @AppStorage("valorMinimoDeGarantia") private var valorMinimoDeGarantiaTexto = ""
    @State private var transacaoParaGarantia: Transacao?

    @Binding var modo: ModoDeRegisto
    /// Sobe a cada vez que se chega aqui por um atalho que promete "já a
    /// ouvir" (Botão de Ação, Centro de Controlo) — a gravação arranca só.
    var pedidoDeEscuta = 0
    /// Se este é o separador visível agora — o TabView mantém todos os
    /// separadores vivos, por isso a animação do exemplo tinha de ser
    /// travada à mão quando não é este o ecrã à vista, senão corria para
    /// sempre em fundo (ela sentiu a app mais lenta por causa disto).
    var ativo = true

    @State private var viewModel = HojeViewModel()
    @State private var gravador = GravadorDeVoz()
    @State private var fotoDeTalao: PhotosPickerItem?
    @State private var proposta: PropostaDeTransacao?
    /// Leitura ao vivo (valor + categoria) do que se escreve ou se diz.
    @State private var propostaEmDireto: PropostaDeTransacao?
    @State private var contaEscolhida: Conta?
    /// A conta do movimento repetido, aplicada quando a proposta chega.
    @State private var contaDoRepetido: Conta?
    @State private var inicioDaGravacao: Date?
    @State private var mostrarFototeca = false
    @State private var mostrarEscolhaDaOrigem = false
    @State private var mostrarCamara = false
    @State private var mostrarEdicaoDoTalao = false
    @State private var mostrarGuardado = false
    @State private var receitaParaDividir: ValorParaDividir?
    @State private var toquesNosExemplos = 0
    /// Só na primeira vez que se vê este ecrã nesta sessão — a app abre aqui.
    @State private var mostrarBanner = true
    /// O texto do exemplo que se vai escrevendo e apagando no campo vazio.
    @State private var textoDoExemploAnimado = ""
    @FocusState private var campoFocado: Bool

    /// Exemplos tocáveis do modo texto — incluem uma receita, para se ver
    /// que também se regista dinheiro a entrar.
    private let exemplos = ["café 1,20", "jantar 25 ontem", "Uber 8,40", "Recebi 1450 de salário"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cabecalho
                if mostrarBanner {
                    banner
                }
                SeletorSegmentado(
                    opcoes: ModoDeRegisto.allCases,
                    escolhida: $modo,
                    titulo: \.rawValue,
                    simbolo: { $0.simbolo }
                )
                entrada
                if viewModel.aInterpretar, modo == .texto {
                    // Na voz, é o próprio círculo que mostra "A perceber…";
                    // no talão, é o papel que mostra "A ler o talão…".
                    ProgressView("A analisar…")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                        .frame(maxWidth: .infinity)
                } else if proposta != nil, !aReverTalao {
                    // No talão, o resultado vive dentro do próprio painel.
                    percebido
                }
                if let mensagem = viewModel.mensagemDeErro, modo != .voz {
                    // Na voz, o erro tem o seu próprio estado no cartão.
                    Label(mensagem, systemImage: "exclamationmark.circle")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.negativo)
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: viewModel.gravacoes)
        .sensoryFeedback(.selection, trigger: toquesNosExemplos)
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
        // Pré-visualização ao vivo: espera 250 ms depois da última tecla (ou
        // da última palavra ditada) e lê a frase com as regras locais.
        .task(id: viewModel.textoDeRegisto) {
            let texto = viewModel.textoDeRegisto
            guard !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                propostaEmDireto = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            propostaEmDireto = await viewModel.preVisualizar(texto, categorias: categorias)
        }
        .onChange(of: viewModel.proposta) {
            proposta = viewModel.proposta
            // Cada registo novo começa na conta principal (ou na do
            // movimento repetido); só muda se a pessoa a trocar no cartão.
            if proposta != nil {
                contaEscolhida = contaDoRepetido ?? contas.first(where: \.principal) ?? contas.first
            }
            contaDoRepetido = nil
        }
        .onChange(of: viewModel.gravacoes) {
            SomDoSistema.sucesso.tocar()
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
            // Trocar de modo recomeça o registo — o resultado de um modo
            // não pode ficar pendurado debaixo dos painéis dos outros.
            if gravador.aGravar { gravador.parar() }
            gravador.limpar()
            proposta = nil
            viewModel.proposta = nil
            viewModel.mensagemDeErro = nil
        }
        .onChange(of: gravador.transcricao) {
            guard gravador.aGravar else { return }
            viewModel.textoDeRegisto = gravador.transcricao
        }
        .onChange(of: pedidoDeEscuta) {
            guard modo == .voz, !gravador.aGravar else { return }
            alternarVoz()
        }
        .onChange(of: gravador.aGravar) { antes, agora in
            inicioDaGravacao = agora ? .now : nil
            // Parou de ouvir (por toque ou por silêncio): analisa o que se disse.
            guard antes, !agora, modo == .voz,
                  !viewModel.textoDeRegisto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            interpretar(origem: .voz)
        }
        .sheet(item: $receitaParaDividir) { receita in
            DividirRendimentoView(valor: receita.valor)
        }
        .sheet(item: $transacaoParaGarantia) { transacao in
            SugerirGarantiaView(transacao: transacao)
        }
        .fullScreenCover(isPresented: $mostrarCamara) {
            CamaraDoTalao { dados in
                Task { await viewModel.interpretarTalao(dados, categorias: categorias) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $mostrarEdicaoDoTalao) {
            if let atual = proposta {
                CartaoDeConfirmacaoView(
                    proposta: atual,
                    categorias: categorias,
                    titulo: "EDITAR DETALHES",
                    textoDeConfirmacao: "Aplicar",
                    aoConfirmar: { editada in
                        proposta = editada
                        mostrarEdicaoDoTalao = false
                    },
                    aoCancelar: { mostrarEdicaoDoTalao = false },
                    fraseOriginal: viewModel.textoDeRegisto,
                    conta: contaEscolhida,
                    aoEscolherConta: { contaEscolhida = $0 }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Cabeçalho

    /// Depois de uma gravação de voz, o ecrã mostra "DISSESTE" e o cartão de revisão.
    private var aReverVoz: Bool {
        proposta != nil && viewModel.origemDoRegisto == .voz && modo == .voz
    }

    private var cabecalho: some View {
        // Título fixo: é o seletor que diz em que modo se está.
        CabecalhoDeEcra(
            legenda: aReverVoz ? "REGISTADO POR VOZ" : modo.legenda,
            titulo: "Registar"
        )
    }

    /// Saudação de abertura, só na primeira vez que se vê este ecrã —
    /// a app abre aqui, por isso é a primeira coisa a aparecer.
    private var banner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("SimboloLume")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bem-vindo à Lume")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("Escreve, fala ou fotografa o talão — confirmas sempre antes de ficar guardado.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button {
                withAnimation(.snappy(duration: 0.2)) { mostrarBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .accessibilityLabel("Fechar")
        }
        .padding(16)
        .cartaoCafe()
        .transition(.opacity)
    }

    // MARK: - Entrada por modo

    @ViewBuilder
    private var entrada: some View {
        switch modo {
        case .texto:
            entradaDeTexto
            if !viewModel.aInterpretar, proposta == nil { acoesDoTexto }
        case .voz:
            // Na revisão, o painel dá lugar ao cartão "DISSESTE".
            if aReverVoz {
                disseste
            } else {
                entradaDeVoz
            }
        case .talao: entradaDeTalao
        }
    }

    // MARK: Texto

    private var entradaDeTexto: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("O que gastaste ou recebeste?")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
            TextField(
                "Registo",
                text: $viewModel.textoDeRegisto,
                prompt: Text(textoDoExemploAnimado).foregroundStyle(Tema.placeholder),
                axis: .vertical
            )
            .font(Tema.fonte(21, .medium))
            .foregroundStyle(Tema.tinta)
            .lineLimit(2...4)
            .focused($campoFocado)
            .submitLabel(.done)
            .task(id: ativo) {
                guard ativo else { return }
                await animarExemplos()
            }
            .onChange(of: viewModel.textoDeRegisto) { _, texto in
                // Num campo de várias linhas o Enter insere uma quebra de
                // linha em vez de submeter: apanha-se aqui e analisa-se.
                guard texto.contains("\n") else { return }
                viewModel.textoDeRegisto = texto.replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                if podeInterpretar { interpretar() }
            }

            Divider()
                .overlay(Tema.separador)
                .padding(.top, 6)

            // A pré-visualização ao vivo do que a Lume percebeu.
            HStack(spacing: 8) {
                if let direto = propostaEmDireto {
                    previsao(direto)
                } else {
                    Text("Escreve o valor e o que foi.")
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.placeholder)
                    Spacer(minLength: 8)
                    Text("Hoje, \(Date.now.formatted(.dateTime.hour().minute().locale(FormatadorDeMoeda.localidade)))")
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
            .frame(minHeight: 28)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    /// Escreve e apaga os exemplos, um a um, enquanto o campo estiver vazio
    /// — mostra o que se pode escrever sem precisar de um texto de ajuda à
    /// parte. Com "Reduzir movimento", fica só o primeiro exemplo, fixo.
    private func animarExemplos() async {
        guard !reduzirMovimento else {
            textoDoExemploAnimado = exemplos.first ?? ""
            return
        }
        while !Task.isCancelled {
            for exemplo in exemplos {
                await aguardarCampoVazio()
                await escrever(exemplo)
                try? await Task.sleep(for: .seconds(1.1))
                await aguardarCampoVazio()
                await apagarExemplo()
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    private func aguardarCampoVazio() async {
        while !Task.isCancelled, !viewModel.textoDeRegisto.isEmpty {
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    private func escrever(_ exemplo: String) async {
        textoDoExemploAnimado = ""
        for caracter in exemplo {
            guard !Task.isCancelled, viewModel.textoDeRegisto.isEmpty else { return }
            textoDoExemploAnimado.append(caracter)
            try? await Task.sleep(for: .milliseconds(45))
        }
    }

    private func apagarExemplo() async {
        while !textoDoExemploAnimado.isEmpty {
            guard !Task.isCancelled, viewModel.textoDeRegisto.isEmpty else { return }
            textoDoExemploAnimado.removeLast()
            try? await Task.sleep(for: .milliseconds(22))
        }
    }

    /// "12,50 € · Restauração · Hoje" — em chip de valor + detalhe.
    private func previsao(_ lida: PropostaDeTransacao) -> some View {
        let receita = lida.tipo == .receita
        let detalhe = [
            receita ? "Receita" : nil,
            lida.nomeDaCategoria ?? (receita ? nil : "Sem categoria"),
            dataCurta(lida.data),
        ].compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 8) {
            Text(receita ? "+\(FormatadorDeMoeda.texto(lida.valor))" : FormatadorDeMoeda.texto(lida.valor))
                .font(Tema.fonte(12, .semibold))
                .monospacedDigit()
                .foregroundStyle(receita ? AnyShapeStyle(Tema.positivo) : Tema.ouro)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Tema.areia, in: Capsule())
            Text(detalhe)
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Percebido: \(FormatadorDeMoeda.texto(lida.valor)), \(detalhe)")
    }

    private func dataCurta(_ data: Date) -> String {
        let calendario = Calendar.current
        if calendario.isDateInToday(data) { return "Hoje" }
        if calendario.isDateInYesterday(data) { return "Ontem" }
        return data.formatted(.dateTime.day().month(.abbreviated).locale(FormatadorDeMoeda.localidade))
    }

    /// Há texto para analisar e nada em curso.
    private var podeInterpretar: Bool {
        !viewModel.textoDeRegisto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.aInterpretar
    }

    /// Por baixo do campo: "Analisar", os exemplos tocáveis e os últimos registos.
    @ViewBuilder
    private var acoesDoTexto: some View {
        BotaoLume(titulo: "Analisar") { interpretar() }
            .disabled(!podeInterpretar)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Ilustracao(tipo: .balao, escala: 0.42)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Escreve como falas")
                        .font(Tema.fonte(14, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text("Uma despesa ou uma receita, numa frase. Toca num exemplo:")
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            FilaDeChips {
                ForEach(exemplos, id: \.self) { exemplo in
                    Button {
                        toquesNosExemplos += 1
                        viewModel.mensagemDeErro = nil
                        viewModel.textoDeRegisto = exemplo
                    } label: {
                        Text(exemplo)
                            .font(Tema.fonte(13, .medium))
                            .foregroundStyle(Tema.tinta)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Tema.superficie, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(EscalaAoTocar())
                    .accessibilityHint("Preenche o campo com este exemplo")
                }
            }
        }
        .padding(14)
        .cartaoCafe()

        ultimosRegistos
    }

    /// Os três movimentos mais recentes e diferentes entre si (sem os
    /// pagamentos de recorrentes, que já entram sozinhos).
    private var ultimos: [Transacao] {
        var vistos = Set<String>()
        var escolhidos: [Transacao] = []
        for transacao in transacoes where transacao.recorrente == nil {
            let chave = "\(transacao.tipo.rawValue)|\((transacao.loja ?? transacao.descricao).lowercased())|\(transacao.valor)"
            guard vistos.insert(chave).inserted else { continue }
            escolhidos.append(transacao)
            if escolhidos.count == 3 { break }
        }
        return escolhidos
    }

    @ViewBuilder
    private var ultimosRegistos: some View {
        let lista = ultimos
        if !lista.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                TituloDeSeccao(titulo: "Últimos registos")
                VStack(spacing: 0) {
                    ForEach(Array(lista.enumerated()), id: \.element.persistentModelID) { indice, transacao in
                        if indice > 0 {
                            Divider().overlay(Tema.separador)
                        }
                        Button { repetir(transacao) } label: {
                            HStack(spacing: 10) {
                                LinhaDeTransacao(transacao: transacao)
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Tema.ouro)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(EscalaAoTocar())
                        .accessibilityHint("Regista outra vez, com a data de hoje")
                    }
                }
                .padding(.horizontal, 16)
                .cartao()
                Text("Toca num para o registar outra vez, com a data de hoje.")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
            }
        }
    }

    // MARK: Voz

    /// Os estados do ecrã de voz.
    private enum EstadoDaVoz: Equatable {
        case inicial
        case aOuvir
        case aPerceber
        case erro(String)
        case semPermissao(String)
    }

    private var estadoDaVoz: EstadoDaVoz {
        if gravador.aGravar { return .aOuvir }
        if viewModel.aInterpretar { return .aPerceber }
        if case .semPermissao(let motivo) = gravador.estado { return .semPermissao(motivo) }
        if let motivo = gravador.mensagem { return .erro(motivo) }
        // A análise falhou (sem valor): a mensagem do texto, dita para a voz.
        if viewModel.mensagemDeErro != nil, viewModel.origemDoRegisto == .voz {
            return .erro("Não encontrei um valor no que disseste. Experimenta dizer “café 1,20”.")
        }
        return .inicial
    }

    /// O cartão areia com a frase gravada, por cima da revisão.
    private var disseste: some View {
        VStack(alignment: .leading, spacing: 12) {
            Legenda("Disseste")
            Text("“\(viewModel.textoDeRegisto)”")
                .font(Tema.fonte(22, .medium))
                .foregroundStyle(Tema.tinta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cartaoCafe()
    }

    private var entradaDeVoz: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch estadoDaVoz {
            case .semPermissao(let motivo):
                cartaoDeProblema(
                    simbolo: "mic.slash",
                    titulo: "Sem acesso ao microfone",
                    mensagem: motivo,
                    botao: BotaoLume(titulo: "Abrir Definições", simbolo: "gear") { abrirDefinicoes() }
                )
            case .erro(let motivo):
                cartaoDeProblema(
                    simbolo: "exclamationmark.bubble",
                    titulo: "Não deu para perceber",
                    mensagem: motivo,
                    botao: BotaoLume(titulo: "Tentar outra vez", simbolo: "arrow.clockwise") { alternarVoz() }
                )
            case .inicial, .aOuvir, .aPerceber:
                botaoDoMicrofone
            }

            if (gravador.aGravar || viewModel.aInterpretar), !viewModel.textoDeRegisto.isEmpty {
                transcricaoEmDireto
            }

            if estadoDaVoz == .inicial {
                exemplosFalados
            }

            Text("A gravação só é guardada depois de confirmares.")
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    /// De volta ao desenho anterior: a moeda, o estado em texto e um botão
    /// próprio por baixo — não um círculo gigante que é o próprio botão.
    private var botaoDoMicrofone: some View {
        let estado = estadoDaVoz
        return VStack(spacing: 14) {
            VStack(spacing: 14) {
                Image("SimboloLume")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 56)
                    .accessibilityHidden(true)
                switch estado {
                case .aOuvir:
                    Text("A ouvir…")
                        .font(Tema.fonte(23, .medium))
                        .foregroundStyle(Tema.tinta)
                    // O nível da voz, ao vivo — só se mexe quando se fala.
                    BarraDeProgresso(fracao: gravador.nivel, altura: 6)
                        .frame(width: 150)
                        .accessibilityHidden(true)
                    if let inicio = inicioDaGravacao {
                        TimelineView(.periodic(from: inicio, by: 1)) { contextoDeTempo in
                            let segundos = max(0, Int(contextoDeTempo.date.timeIntervalSince(inicio)))
                            Text(String(format: "%02d:%02d", segundos / 60, segundos % 60))
                                .font(Tema.fonte(12, .medium))
                                .monospacedDigit()
                                .foregroundStyle(Tema.douradoEscuro)
                        }
                    }
                case .aPerceber:
                    Text("A perceber…")
                        .font(Tema.fonte(23, .medium))
                        .foregroundStyle(Tema.tinta)
                default:
                    Text("Toca em começar e fala")
                        .font(Tema.fonte(23, .medium))
                        .foregroundStyle(Tema.tinta)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .cartaoCafe()

            if estado == .aPerceber {
                ProgressView().frame(maxWidth: .infinity, minHeight: 52)
            } else {
                BotaoLume(titulo: estado == .aOuvir ? "Terminar e rever" : "Começar a falar", simbolo: estado == .aOuvir ? "stop.fill" : "mic.fill") {
                    alternarVoz()
                }
            }
        }
        .animation(.snappy, value: estado)
        .sensoryFeedback(.impact(weight: .light), trigger: gravador.aGravar)
        .accessibilityElement(children: .combine)
    }

    /// Os estados de erro e de falta de permissão: o que aconteceu e a saída.
    private func cartaoDeProblema(simbolo: String, titulo: String, mensagem: String, botao: BotaoLume) -> some View {
        VStack(spacing: 12) {
            Image(systemName: simbolo)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Tema.tintaSuave)
                .frame(width: 72, height: 72)
                .background(Tema.bege, in: Circle())
                .accessibilityHidden(true)
            Text(titulo)
                .font(Tema.fonte(19, .semibold))
                .foregroundStyle(Tema.tinta)
            Text(mensagem)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            botao
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .cartao()
    }

    /// O cartão branco da transcrição, com o valor e a categoria ao vivo.
    private var transcricaoEmDireto: some View {
        VStack(alignment: .leading, spacing: 12) {
            Legenda("Transcrição em tempo real")
            Text("“\(viewModel.textoDeRegisto)”")
                .font(Tema.fonte(22, .medium))
                .foregroundStyle(Tema.tinta)
            if let direto = propostaEmDireto {
                previsao(direto)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    /// Frases de exemplo para dizer — como os exemplos do modo texto.
    private var exemplosFalados: some View {
        VStack(alignment: .leading, spacing: 10) {
            Legenda("Experimenta dizer")
            ForEach(["“Gastei 12,50 no almoço”", "“Uber 8,40 ontem”", "“Recebi 1450 de salário”"], id: \.self) { frase in
                HStack(spacing: 10) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Tema.ouro)
                        .accessibilityHidden(true)
                    Text(frase)
                        .font(Tema.fonte(15))
                        .foregroundStyle(Tema.tinta)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao(Tema.bege)
    }

    // MARK: Talão

    /// Reconheceu-se um talão — mostra o cartão-resumo.
    private var aReverTalao: Bool {
        proposta != nil && viewModel.origemDoRegisto == .talao && modo == .talao
    }

    private var entradaDeTalao: some View {
        VStack(spacing: 14) {
            // Antes da fotografia, um talão em branco que se toca para
            // fotografar; depois, o mesmo papel com o que foi lido de verdade.
            Group {
                if let atual = proposta, aReverTalao {
                    talaoLido(atual)
                        .transition(.opacity)
                } else {
                    Button { mostrarEscolhaDaOrigem = true } label: {
                        TalaoADigitalizar(aLer: viewModel.aInterpretar)
                    }
                    .buttonStyle(EscalaAoTocar())
                    .disabled(viewModel.aInterpretar)
                    .accessibilityLabel(viewModel.aInterpretar ? "A ler o talão" : "Fotografar talão")
                    .transition(.opacity)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .cartaoCafe()
            .animation(.snappy(duration: 0.25), value: aReverTalao)

            if let atual = proposta, aReverTalao {
                talaoReconhecido(atual)
                BotaoLume(titulo: "Confirmar e guardar", acao: guardar)
                BotaoLume(titulo: "Fotografar outro", estilo: .texto) { descartar() }
            } else if proposta == nil {
                // De volta a uma só ação, como antes — a escolha entre
                // câmara e galeria fica para quando se toca, não em dois
                // botões lado a lado.
                BotaoLume(titulo: "Fotografar ou escolher talão", simbolo: "camera") {
                    mostrarEscolhaDaOrigem = true
                }
                .disabled(viewModel.aInterpretar)
                .confirmationDialog("Talão", isPresented: $mostrarEscolhaDaOrigem, titleVisibility: .hidden) {
                    Button("Fotografar") { abrirCamara() }
                    Button("Escolher da galeria") { mostrarFototeca = true }
                }
                .photosPicker(isPresented: $mostrarFototeca, selection: $fotoDeTalao, matching: .images)
            }

            Text("A fotografia fica associada ao movimento.")
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
                .frame(maxWidth: .infinity)
        }
    }

    /// O cartão "Resultado da leitura" — toca-se para editar.
    private func talaoReconhecido(_ atual: PropostaDeTransacao) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Talão reconhecido")
                    .font(Tema.fonte(12, .medium))
                    .foregroundStyle(Tema.positivo)
                Spacer()
                Image(systemName: "checkmark")
                    .font(Tema.fonte(13, .semibold))
                    .foregroundStyle(Tema.positivo)
            }
            HStack {
                Text(atual.loja ?? atual.descricao)
                    .font(Tema.fonte(17, .semibold))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Text(FormatadorDeMoeda.texto(atual.valor))
                    .font(Tema.fonte(23, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
            }
            HStack {
                Text(resumoDaLeitura(atual))
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                Text("Editar")
                    .font(Tema.fonte(12, .medium))
                    .textoDourado()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
        .contentShape(Rectangle())
        .onTapGesture { mostrarEdicaoDoTalao = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Toca para editar os detalhes")
    }

    private func resumoDaLeitura(_ atual: PropostaDeTransacao) -> String {
        let conta = contaEscolhida ?? contas.first(where: \.principal) ?? contas.first
        let nomeDaConta = conta.map { $0.principal ? "Conta principal" : $0.nome }
        return [atual.nomeDaCategoria ?? "Sem categoria", nomeDaConta]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// O talão depois da leitura, com o design do frame (papel branco, tipos
    /// monoespaçados, picotados) mas com a informação real: loja, data,
    /// linhas de produto e total. Loja e total seguem as correções feitas
    /// em "Editar detalhes".
    private func talaoLido(_ atual: PropostaDeTransacao) -> some View {
        let leitura = viewModel.leituraDoTalao
        let data = (leitura?.data ?? atual.data)
            .formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(FormatadorDeMoeda.localidade))
        return PapelDeTalao {
            Text((atual.loja ?? "Talão").uppercased())
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(data)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Tema.tintaSuave)
                .frame(maxWidth: .infinity)
            Picotado()
            if let itens = leitura?.itens, !itens.isEmpty {
                ForEach(itens) { item in
                    linhaDeTalao(item.nome, FormatadorDeMoeda.textoSimples(item.valor))
                }
                Picotado()
            }
            HStack {
                Text("TOTAL")
                Spacer()
                Text(FormatadorDeMoeda.textoSimples(atual.valor))
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Tema.tinta)
            .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
    }

    private func linhaDeTalao(_ nome: String, _ valor: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(nome)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(valor)
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Tema.tinta)
    }

    // MARK: - Confirmar

    private var tituloDoReconhecimento: String {
        viewModel.origemDoRegisto == .manual ? "A repetir. Confirma os detalhes." : "Confirma os detalhes."
    }

    private var textoDoBotaoGuardar: String {
        if viewModel.origemDoRegisto == .talao { return "Confirmar e guardar" }
        return proposta?.tipo == .receita ? "Guardar receita" : "Guardar despesa"
    }

    /// O cartão "Depois desta despesa": o limite da categoria depois de
    /// contar o valor proposto.
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Depois desta despesa")
                    .font(Tema.fonte(13, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("\(categoria.nome): \(FormatadorDeMoeda.textoSimples(depois)) € de \(FormatadorDeMoeda.textoInteiroAgrupado(orcamento)) €")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                Text(restante >= .zero
                    ? "Ficam \(FormatadorDeMoeda.textoSimples(restante)) € disponíveis."
                    : "Passas o limite em \(FormatadorDeMoeda.textoSimples(-restante)) €.")
                    .font(Tema.fonte(13))
                    .foregroundStyle(restante >= .zero ? Tema.tintaSuave : Tema.negativo)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cartao(Tema.bege)
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
                if !aReverVoz {
                    Label(tituloDoReconhecimento, systemImage: "checkmark")
                        .font(Tema.fonte(12, .medium))
                        .foregroundStyle(Tema.positivo)
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Despesa ou receita: a frase decide, mas corrige-se aqui.
                    SeletorSegmentado(
                        opcoes: TipoTransacao.allCases,
                        escolhida: ligacaoProposta.tipo,
                        titulo: { $0 == .despesa ? "Despesa" : "Receita" },
                        altura: 34
                    )

                    TextField(
                        "Descrição",
                        text: ligacaoProposta.descricao,
                        prompt: Text("Descrição").foregroundStyle(Tema.placeholder)
                    )
                    .font(Tema.fonte(aReverVoz ? 21 : 17, .semibold))
                    .foregroundStyle(Tema.tinta)

                    TextField(
                        "Valor",
                        value: ligacaoProposta.valor,
                        format: .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
                    )
                    .keyboardType(.decimalPad)
                    .font(Tema.fonte(aReverVoz ? 40 : 36, .medium))
                    .monospacedDigit()
                    .foregroundStyle(atual.tipo == .receita ? Tema.positivo : Tema.tinta)

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
                .cartao()

                depoisDaDespesa(atual)

                BotaoLume(titulo: textoDoBotaoGuardar, acao: guardar)

                if aReverVoz {
                    // Deitar fora a proposta e voltar ao microfone.
                    BotaoLume(titulo: "Voltar à gravação", estilo: .texto) { descartar() }
                        .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Text("Podes rever e corrigir tudo antes de guardar.")
                            .font(Tema.fonte(11))
                            .foregroundStyle(Tema.tintaSuave)
                        Spacer()
                        BotaoLume(titulo: "Descartar", estilo: .texto) { descartar() }
                    }
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

    /// Linha do cartão de detalhes: ícone + etiqueta à esquerda, o
    /// controlo de edição à direita.
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

    /// Toque no círculo: começa a ouvir, ou termina (e a análise arranca
    /// sozinha, no `onChange` de `aGravar`).
    private func alternarVoz() {
        if gravador.aGravar {
            gravador.parar()
            return
        }
        proposta = nil
        viewModel.proposta = nil
        viewModel.mensagemDeErro = nil
        viewModel.textoDeRegisto = ""
        gravador.limpar()
        Task { await gravador.alternar() }
    }

    private func abrirDefinicoes() {
        guard let endereco = URL(string: UIApplication.openSettingsURLString) else { return }
        abrirURL(endereco)
    }

    /// A câmara quando existe (e a app a pode usar); senão, a galeria.
    private func abrirCamara() {
        viewModel.mensagemDeErro = nil
        if CamaraDoTalao.disponivel {
            mostrarCamara = true
        } else {
            mostrarFototeca = true
        }
    }

    private func repetir(_ transacao: Transacao) {
        campoFocado = false
        contaDoRepetido = transacao.conta
        viewModel.repetir(transacao)
    }

    private func descartar() {
        proposta = nil
        viewModel.proposta = nil
        viewModel.mensagemDeErro = nil
    }

    private func interpretar(origem: OrigemTransacao = .texto) {
        campoFocado = false
        Task { await viewModel.interpretar(categorias: categorias, origem: origem) }
    }

    private func guardar() {
        guard let proposta else { return }
        // Recebeste dinheiro: propõe logo dividi-lo pelas categorias.
        if proposta.tipo == .receita, proposta.valor > .zero {
            receitaParaDividir = ValorParaDividir(valor: proposta.valor)
        }
        let transacao = viewModel.confirmar(
            proposta,
            categorias: categorias,
            contas: contas,
            contexto: contexto,
            conta: contaEscolhida,
            recorrentes: recorrentes
        )
        self.proposta = nil
        contaEscolhida = nil

        let regras = RegrasDeGarantia.atuais
        let valorMinimo = Decimal(string: valorMinimoDeGarantiaTexto, locale: Locale(identifier: "en_US_POSIX"))
            ?? regras.valorMinimoPorDefeito
        if transacao.tipo == .despesa, Garantias.deveSugerir(
            categoriaNome: transacao.categoria?.nome,
            valor: transacao.valor,
            valorMinimo: valorMinimo,
            categoriasSugeridas: regras.categoriasSugeridas
        ) {
            transacaoParaGarantia = transacao
        }
    }
}

/// A câmara do sistema para fotografar o talão. Só se usa quando há
/// câmara e a app declara para que a usa (no simulador, vai-se à galeria).
private struct CamaraDoTalao: UIViewControllerRepresentable {
    let aoFotografar: (Data) -> Void
    @Environment(\.dismiss) private var fechar

    static var disponivel: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
            && Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controlador = UIImagePickerController()
        controlador.sourceType = .camera
        controlador.delegate = context.coordinator
        return controlador
    }

    func updateUIViewController(_ controlador: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordenador { Coordenador(pai: self) }

    final class Coordenador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let pai: CamaraDoTalao

        init(pai: CamaraDoTalao) { self.pai = pai }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let imagem = info[.originalImage] as? UIImage,
               let dados = imagem.jpegData(compressionQuality: 0.85) {
                pai.aoFotografar(dados)
            }
            pai.fechar()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            pai.fechar()
        }
    }
}

/// Layout de fluxo para os chips de exemplo: encosta à esquerda e quebra linha.
private struct FilaDeChips: Layout {
    var espaco: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largura = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alturaDaLinha: CGFloat = 0, maior: CGFloat = 0
        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x + tamanho.width > largura, x > 0 {
                x = 0
                y += alturaDaLinha + espaco
                alturaDaLinha = 0
            }
            x += tamanho.width + espaco
            maior = max(maior, x - espaco)
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
        }
        return CGSize(width: proposal.width ?? maior, height: y + alturaDaLinha)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alturaDaLinha: CGFloat = 0
        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x + tamanho.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += alturaDaLinha + espaco
                alturaDaLinha = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += tamanho.width + espaco
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
        }
    }
}

/// O papel do talão: branco, borda inferior recortada e sombra leve.
private struct PapelDeTalao<Conteudo: View>: View {
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            conteudo()
        }
        .foregroundStyle(Tema.tinta)
        .padding(.top, 20)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 2))
        .overlay(alignment: .bottom) {
            BordaDeTalao()
                .fill(Tema.bege)
                .frame(height: 7)
        }
        .compositingGroup()
        .shadow(color: Color(hex: "332E24").opacity(0.07), radius: 10, y: 10)
    }
}

/// Os traços picotados entre secções do talão.
private struct Picotado: View {
    var body: some View {
        Line()
            .stroke(Tema.separador, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.vertical, 3)
    }
}

/// Antes da fotografia: um talão em branco, com linhas por preencher e o
/// botão da câmara ao centro — toca-se no papel para fotografar. Enquanto
/// o Vision lê, as linhas ganham cor e o rodapé diz "A ler o talão…".
/// Sem animações contínuas: só uma troca curta de estado.
private struct TalaoADigitalizar: View {
    let aLer: Bool

    private let larguras: [CGFloat] = [0.62, 0.48, 0.7, 0.4, 0.56]

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    /// O brilho só anima enquanto está a ler — não é uma animação contínua
    /// do ecrã parado, é o estado "a processar".
    @State private var brilho = false

    private var corDasLinhas: Color {
        aLer ? Tema.dourado.opacity(0.35) : Tema.bege
    }

    var body: some View {
        PapelDeTalao {
            Capsule().fill(corDasLinhas).frame(width: 110, height: 9)
                .frame(maxWidth: .infinity)
            Capsule().fill(corDasLinhas.opacity(0.7)).frame(width: 78, height: 6)
                .frame(maxWidth: .infinity)
            Picotado()
            VStack(spacing: 8) {
                ForEach(Array(larguras.enumerated()), id: \.offset) { _, largura in
                    HStack {
                        GeometryReader { geometria in
                            Capsule().fill(corDasLinhas)
                                .frame(width: geometria.size.width * largura, height: 6)
                        }
                        .frame(height: 6)
                        Capsule().fill(corDasLinhas).frame(width: 34, height: 6)
                    }
                    .padding(.vertical, 3)
                }
            }
            Picotado()
            HStack(spacing: 8) {
                Text(aLer ? "A ler o talão…" : "À espera do talão")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(aLer ? Tema.ouro : AnyShapeStyle(Tema.tintaSuave))
                Spacer()
                if aLer {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.top, 2)
        }
        .overlay {
            // Um brilho dourado a percorrer as linhas enquanto lê.
            if aLer, !reduzirMovimento {
                GeometryReader { geometria in
                    LinearGradient(
                        colors: [.clear, Tema.dourado.opacity(0.5), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geometria.size.width * 0.4)
                    .offset(x: brilho ? geometria.size.width : -geometria.size.width * 0.4)
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
        .animation(.snappy(duration: 0.2), value: aLer)
        .onChange(of: aLer) { _, ativo in
            guard !reduzirMovimento else { return }
            if ativo {
                brilho = false
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    brilho = true
                }
            } else {
                brilho = false
            }
        }
        .onAppear {
            guard aLer, !reduzirMovimento else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                brilho = true
            }
        }
    }
}

/// Linha horizontal para traços picotados.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// A borda inferior recortada do papel de talão — dentes triangulares.
private struct BordaDeTalao: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let largura: CGFloat = 12
        let dentes = Int((rect.width / largura).rounded(.up))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for dente in 0..<dentes {
            let x0 = rect.minX + CGFloat(dente) * largura
            path.addLine(to: CGPoint(x: x0 + largura / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: min(x0 + largura, rect.maxX), y: rect.maxY))
        }
        path.closeSubpath()
        return path
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
