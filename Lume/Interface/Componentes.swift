import SwiftUI

/// Linhas partilhadas entre o ecrã Hoje e o separador Movimentos.
/// Planas, como no Figma: texto sobre o fundo, sem ícones nem cartões.

/// O cabeçalho de todos os ecrãs, como nos frames do Figma:
/// legenda pequena em maiúsculas, título grande e o símbolo da Lume à direita.
///
/// Regras (auditoria UX): a legenda é sempre contexto ou data, nunca um
/// slogan; o título é fixo por separador; a marca só aparece no Resumo
/// (`mostrarMarca`); os ecrãs secundários têm voltar/fechar (`aoVoltar`).
struct CabecalhoDeEcra<Acessorio: View>: View {
    let legenda: String
    let titulo: String
    var mostrarMarca = false
    /// Ecrãs secundários: mostra um botão de voltar à esquerda, por cima.
    var aoVoltar: (() -> Void)?
    var simboloDeVoltar = "chevron.left"
    /// Uma ação no canto superior direito (o sítio mais valioso do ecrã).
    @ViewBuilder var acessorio: () -> Acessorio

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let aoVoltar {
                BotaoRedondo(simbolo: simboloDeVoltar, rotulo: simboloDeVoltar == "xmark" ? "Fechar" : "Voltar", acao: aoVoltar)
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Legenda(legenda)
                    Text(titulo)
                        .font(Tema.fonte(27, .semibold))
                        .foregroundStyle(Tema.tinta)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                acessorio()
                if mostrarMarca {
                    Image("SimboloLume")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 39.2)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

extension CabecalhoDeEcra where Acessorio == EmptyView {
    init(legenda: String, titulo: String, mostrarMarca: Bool = false, aoVoltar: (() -> Void)? = nil, simboloDeVoltar: String = "chevron.left") {
        self.init(legenda: legenda, titulo: titulo, mostrarMarca: mostrarMarca, aoVoltar: aoVoltar, simboloDeVoltar: simboloDeVoltar) { EmptyView() }
    }
}

/// A legenda pequena em maiúsculas — um só estilo em toda a app (cinzento,
/// espaçado), por cima de títulos e dentro de cartões.
struct Legenda: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        // Tracking mais contido do que tinha com a Instrument Sans — a SF
        // Pro já tem a abertura própria das legendas da Apple.
        Text(texto.uppercased())
            .font(Tema.fonte(11, .medium))
            .tracking(0.8)
            .foregroundStyle(Tema.tintaSuave)
    }
}

/// Botão circular de 36 pt para voltar, fechar ou ações de cabeçalho.
struct BotaoRedondo: View {
    let simbolo: String
    let rotulo: String
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Image(systemName: simbolo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tema.tinta)
                .frame(width: 36, height: 36)
                .background(Tema.bege, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(EscalaAoTocar())
        .accessibilityLabel(rotulo)
    }
}

/// Barra de topo dos ecrãs de edição: "Cancelar · Título · Guardar".
struct BarraDeEdicao: View {
    let titulo: String
    var textoDeConfirmar = "Guardar"
    var podeConfirmar = true
    let aoCancelar: () -> Void
    let aoConfirmar: () -> Void

    var body: some View {
        HStack {
            Button("Cancelar", action: aoCancelar)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(titulo)
                .font(Tema.fonte(16, .semibold))
                .foregroundStyle(Tema.tinta)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(textoDeConfirmar, action: aoConfirmar)
                .font(Tema.fonte(15, .semibold))
                .foregroundStyle(podeConfirmar ? Tema.ouro : AnyShapeStyle(Tema.placeholder))
                .disabled(!podeConfirmar)
        }
        .frame(height: 44)
    }
}

/// O seletor segmentado da Lume — o único em toda a app (Registar,
/// Movimentos, Planear, Temas): um contentor cinza-pedra com a opção
/// escolhida num "comprimido" branco que desliza.
struct SeletorSegmentado<Opcao: Hashable>: View {
    let opcoes: [Opcao]
    @Binding var escolhida: Opcao
    let titulo: (Opcao) -> String
    var simbolo: ((Opcao) -> String?)?
    var altura: CGFloat = 38

    @Namespace private var espaco

    var body: some View {
        HStack(spacing: 2) {
            ForEach(opcoes, id: \.self) { opcao in
                let selecionada = opcao == escolhida
                Button {
                    withAnimation(.snappy(duration: 0.22)) { escolhida = opcao }
                } label: {
                    HStack(spacing: 6) {
                        if let nome = simbolo?(opcao) {
                            Image(systemName: nome)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(titulo(opcao))
                            .font(Tema.fonte(13, selecionada ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selecionada ? Tema.ouro : AnyShapeStyle(Tema.tintaSuave))
                    .frame(maxWidth: .infinity)
                    .frame(height: altura - 6)
                    .background {
                        if selecionada {
                            RoundedRectangle(cornerRadius: Tema.Raio.chip - 3)
                                .fill(Tema.superficie)
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "escolhida", in: espaco)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selecionada ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Tema.bege, in: RoundedRectangle(cornerRadius: Tema.Raio.chip))
        .sensoryFeedback(.selection, trigger: escolhida)
    }
}

/// Uma linha de formulário — o único padrão para campos: rótulo à
/// esquerda, valor + chevron à direita.
struct LinhaDeFormulario<Valor: View>: View {
    let rotulo: String
    var simbolo: String?
    var mostrarChevron = true
    @ViewBuilder var valor: () -> Valor

    var body: some View {
        HStack(spacing: 12) {
            if let simbolo {
                Image(systemName: simbolo)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(width: 20)
            }
            Text(rotulo)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
            Spacer(minLength: 8)
            valor()
                .font(Tema.fonte(15, .medium))
                .foregroundStyle(Tema.tinta)
            if mostrarChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tema.placeholder)
            }
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// Campo de valor que se vê que é editável: fundo cinza-pedra, alinhado à
/// direita, algarismos tabulares e "1 450,00 €" com espaço nos milhares.
struct CampoDeEuros: View {
    @Binding var valor: Decimal
    var tamanho: CGFloat = 15
    var largura: CGFloat = 118
    var cor: Color = Tema.tinta

    var body: some View {
        TextField(value: $valor, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
            Text("Valor")
        }
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(Tema.fonte(tamanho, .semibold))
        .monospacedDigit()
        .foregroundStyle(cor)
        .padding(.horizontal, 10)
        .frame(width: largura, height: 36)
        .background(Tema.bege, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Título de secção como no frame: grande e negro, com uma ação dourada à direita.
struct TituloDeSeccao: View {
    let titulo: String
    var acao: String?
    var aoTocar: (() -> Void)?

    var body: some View {
        HStack {
            Text(titulo)
                .font(Tema.fonte(17, .semibold))
                .foregroundStyle(Tema.tinta)
            Spacer()
            if let acao, let aoTocar {
                Button(acao) { aoTocar() }
                    .font(Tema.fonte(12, .medium))
                    .textoDourado()
            }
        }
    }
}

struct LinhaDeTransacao: View {
    /// No Resumo o subtítulo é "Hoje · Supermercado"; no extrato dos
    /// Movimentos (já agrupado por dia) é "Restauração · 13:20 · Revolut".
    /// O método de registo (texto, voz, talão) não aparece: é ruído.
    enum Estilo {
        case resumo
        case extrato
    }

    let transacao: Transacao
    var estilo = Estilo.resumo

    var body: some View {
        // A linha do componente "Lume / Movimento": 62 pt de altura,
        // avatar 40, nome 14 Medium, detalhe 11, valor 14 Medium.
        HStack(spacing: 12) {
            IconeDeCategoria(categoria: transacao.categoria, textoAlternativo: titulo)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                if let detalhe {
                    Text(detalhe)
                        .font(Tema.fonte(11))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }

            Spacer()

            Text(valorFormatado)
                .font(Tema.fonte(14, .medium))
                .monospacedDigit()
                .foregroundStyle(transacao.tipo == .receita ? Tema.positivo : Tema.tinta)
        }
        .frame(height: 62)
        .accessibilityElement(children: .combine)
    }

    /// A loja manda no título ("Pingo Doce"); sem loja, fica a descrição.
    private var titulo: String {
        transacao.loja ?? transacao.descricao
    }

    private var detalhe: String? {
        let partes: [String?] = switch estilo {
        case .resumo: [dataCurta, transacao.categoria?.nome]
        case .extrato: [transacao.categoria?.nome, hora, transacao.conta?.nome]
        }
        let visiveis = partes.compactMap { $0 }.filter { !$0.isEmpty }
        return visiveis.isEmpty ? nil : visiveis.joined(separator: " · ")
    }

    /// "13:20". À meia-noite em ponto é um movimento sem hora (contas
    /// fixas, registos com só a data) e a hora fica de fora.
    private var hora: String? {
        let componentes = Calendar.current.dateComponents([.hour, .minute], from: transacao.data)
        guard componentes.hour != 0 || componentes.minute != 0 else { return nil }
        return transacao.data.formatted(
            .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(FormatadorDeMoeda.localidade)
        )
    }

    private var dataCurta: String? {
        let calendario = Calendar.current
        if calendario.isDateInToday(transacao.data) { return "Hoje" }
        if calendario.isDateInYesterday(transacao.data) { return "Ontem" }
        return transacao.data.formatted(
            .dateTime.day().month(.abbreviated).locale(FormatadorDeMoeda.localidade)
        )
    }

    private var valorFormatado: String {
        let texto = FormatadorDeMoeda.texto(transacao.valor)
        return transacao.tipo == .receita ? "+\(texto)" : "−\(texto)"
    }
}

/// Os cartões da Lume: fundo, contorno subtil e duas sombras (uma curta
/// de contacto e uma longa e difusa) para terem profundidade. As sombras
/// vivem só na forma de fundo, não no texto. No escuro, a sombra é mais
/// forte e o contorno ganha um brilho fino para o cartão se separar do fundo.
struct EstiloDeCartao: ViewModifier {
    var fundo: Color = Tema.superficie
    var raio: CGFloat = Tema.Raio.cartao
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: raio)
                .fill(fundo)
                .overlay {
                    RoundedRectangle(cornerRadius: raio)
                        .strokeBorder(
                            esquema == .dark ? Color.white.opacity(0.07) : Tema.separador.opacity(0.7),
                            lineWidth: esquema == .dark ? 0.8 : 0.5
                        )
                }
                .modifier(SombraDeCartao())
        }
    }
}

/// A sombra dupla dos cartões, também útil sozinha (miniaturas, seletores).
struct SombraDeCartao: ViewModifier {
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        let escuro = esquema == .dark
        return content
            .shadow(color: .black.opacity(escuro ? 0.35 : 0.05), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(escuro ? 0.45 : 0.08), radius: 16, y: 8)
    }
}

extension View {
    /// Cartão de destaque na cor escolhida em Tema → Cartões e barras.
    @ViewBuilder
    func cartaoCafe(raio: CGFloat = Tema.Raio.cartao) -> some View {
        // Cartões escuros (Café, Azul-noite…) desenham o conteúdo com as
        // cores escuras do tema, para o texto ficar claro.
        if Tema.acento.cartaoEscuro {
            self
                .environment(\.colorScheme, .dark)
                .cartao(Tema.cafe, raio: raio)
        } else {
            self.cartao(Tema.cafe, raio: raio)
        }
    }

    /// Fundo de cartão com contorno e sombra, como em toda a app.
    func cartao(_ fundo: Color = Tema.superficie, raio: CGFloat = Tema.Raio.cartao) -> some View {
        modifier(EstiloDeCartao(fundo: fundo, raio: raio))
    }

    func sombraDeCartao() -> some View {
        modifier(SombraDeCartao())
    }
}

extension View {
    /// Texto ou símbolo de destaque, no castanho-bege da Lume (ou na cor de
    /// acento do tema). Liso, sem sombra, para se ler bem em qualquer tamanho.
    func textoDourado() -> some View {
        self.foregroundStyle(Tema.ouro)
    }
}

/// Pulso suave enquanto algo está ativo (a gravação de voz).
struct Pulso: ViewModifier {
    let ativo: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var grande = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(grande ? 1.06 : 1)
            .onChange(of: ativo) { _, agora in
                guard !reduzirMovimento else { return }
                if agora {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        grande = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { grande = false }
                }
            }
            .onAppear {
                guard ativo, !reduzirMovimento else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    grande = true
                }
            }
    }
}

extension View {
    func pulso(_ ativo: Bool) -> some View {
        modifier(Pulso(ativo: ativo))
    }
}

/// Os botões de ação da Lume, sempre com fundo:
/// - principal: dourado claro, para guardar e criar o que é central;
/// - secundário: areia com texto dourado, para "Adicionar …";
/// - destrutivo: vermelho suave, para eliminar e apagar.
/// Ao toque afundam com mola, vibram de leve e o ícone dá um salto.
struct BotaoLume: View {
    enum Estilo {
        /// Dourado de ação (um só em toda a app).
        case principal
        /// Cinza-pedra com texto castanho, para ações de apoio.
        case secundario
        /// Vermelho suave, para eliminar e apagar.
        case destrutivo
        /// Só texto castanho, para ações discretas ("Limpar", "Já tenho conta").
        case texto
    }

    let titulo: String
    var simbolo: String?
    var estilo: Estilo = .principal
    /// Fundo próprio, para quando o botão fica sobre um cartão de destaque
    /// (oliva) — o creme habitual perde-se lá, por isso passa a branco.
    var fundoPersonalizado: Color?
    let acao: () -> Void

    /// Conta os toques: cada um faz o ícone saltar uma vez.
    @State private var toques = 0

    var body: some View {
        Button(role: estilo == .destrutivo ? .destructive : nil) {
            toques += 1
            acao()
        } label: {
            HStack(spacing: 8) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolEffect(.bounce, value: toques)
                }
                Text(titulo)
                    .font(Tema.fonte(15, .semibold))
            }
            .frame(maxWidth: estilo == .texto ? nil : .infinity, minHeight: estilo == .principal ? 52 : (estilo == .texto ? 36 : 48))
        }
        .buttonStyle(EstiloDeBotaoLume(estilo: estilo, fundoPersonalizado: fundoPersonalizado))
    }
}

/// Fundo, cor e resposta ao toque dos `BotaoLume`.
struct EstiloDeBotaoLume: ButtonStyle {
    let estilo: BotaoLume.Estilo
    var fundoPersonalizado: Color?
    @Environment(\.isEnabled) private var ativo

    static var vermelho: Color { Tema.negativo }
    static var fundoVermelho: Color { Tema.fundoNegativo }
    /// O único desativado da app: cinzento neutro, texto legível.
    static let fundoDesativado = Color(claro: 0xE9E8E5, escuro: 0x2C2B29)
    static let textoDesativado = Color(claro: 0x6E6E73, escuro: 0x98989D)

    func makeBody(configuration: Configuration) -> some View {
        let (texto, fundo): (AnyShapeStyle, AnyShapeStyle) = switch estilo {
        // Desativado: cinzento neutro em vez do dourado desbotado (amarelado).
        case .texto: (ativo ? Tema.ouro : AnyShapeStyle(Self.textoDesativado), AnyShapeStyle(Color.clear))
        case _ where !ativo: (AnyShapeStyle(Self.textoDesativado), AnyShapeStyle(Self.fundoDesativado))
        case .principal where fundoPersonalizado != nil: (Tema.ouro, AnyShapeStyle(fundoPersonalizado!))
        // O mesmo creme das barras — nem dourado metálico, nem amarelo liso.
        case .principal: (Tema.ouro, Tema.douradoDaBarra)
        // Oliva, não cinza — para não ficar nem bege nem verde a meio.
        case .secundario: (Tema.ouro, AnyShapeStyle(Tema.cafe))
        case .destrutivo: (AnyShapeStyle(Self.vermelho), AnyShapeStyle(Self.fundoVermelho))
        }
        return configuration.label
            .foregroundStyle(texto)
            .background(fundo, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .contentShape(RoundedRectangle(cornerRadius: Tema.Raio.campo))
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, carregado in
                guard carregado else { return nil }
                return estilo == .destrutivo ? .impact(weight: .medium) : .impact(weight: .light)
            }
    }
}

/// Botões principais afundam ligeiramente ao toque.
struct EscalaAoTocar: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// O "T" serifado dos frames — o SF Symbols não tem este glifo,
/// por isso desenha-se com texto.
struct IconeDeTexto: View {
    var tamanho: CGFloat = 13

    var body: some View {
        Text("T")
            .font(.system(size: tamanho, weight: .medium, design: .serif))
            .accessibilityHidden(true)
    }
}

/// Avatar quadrado com as iniciais da loja, como no componente do Figma:
/// 40 pt, raio 13, fundo warm e iniciais 12 SemiBold em dourado.
struct AvatarDeIniciais: View {
    let texto: String
    var lado: CGFloat = 40
    var fundo = Tema.bege

    var body: some View {
        Text(iniciais)
            .font(Tema.fonte(lado >= 54 ? 18 : (lado >= 48 ? 16 : 12), .semibold))
            .textoDourado()
            .frame(width: lado, height: lado)
            .background(fundo, in: RoundedRectangle(cornerRadius: lado >= 54 ? 18 : (lado >= 48 ? 16 : 13)))
            .accessibilityHidden(true)
    }

    private var iniciais: String {
        let palavras = texto.split(separator: " ").prefix(2)
        let letras = palavras.compactMap(\.first)
        return letras.isEmpty ? "•" : String(letras).uppercased()
    }
}

extension OrigemTransacao {
    /// Nome curto no extrato ("Talão", "Voz"); o manual não se anuncia.
    var nome: String? {
        switch self {
        case .manual: nil
        case .texto: "Texto"
        case .voz: "Voz"
        case .talao: "Talão"
        case .applePay: "Apple Pay"
        }
    }
}

struct LinhaDeRecorrente: View {
    let recorrente: Recorrente
    let data: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(recorrente.nome)
                    .font(Tema.fonte(15))
                    .foregroundStyle(Tema.tinta)
                Text(data.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(FormatadorDeMoeda.localidade)))
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
            }

            Spacer()

            Text(FormatadorDeMoeda.texto(recorrente.valor))
                .font(Tema.fonte(15))
                .monospacedDigit()
                .foregroundStyle(Tema.tintaSuave)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

extension Conta {
    /// A cor "do cartão" desta conta — dourado escuro para a principal
    /// (legível sobre fundo claro); senão, a cor do banco, se o nome da
    /// conta o mencionar; senão, a mesma paleta estável por nome de sempre.
    var corDoCartao: Color {
        if principal { return Tema.douradoEscuro }
        if let corDoBanco = Self.corDoBanco(paraNome: nome) { return corDoBanco }
        let cores: [Color] = [
            Color(hex: "23242B"), Color(hex: "0F2C4B"), Color(hex: "14392B"),
            Color(hex: "3B1523"), Color(hex: "3A2E14"),
        ]
        let semente = nome.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return cores[semente % cores.count]
    }

    /// Cores aproximadas de alguns bancos comuns em Portugal — não são os
    /// logótipos (não temos esses recursos autorizados), só uma cor que
    /// lembra a marca, quando o nome da conta a menciona.
    private static func corDoBanco(paraNome nome: String) -> Color? {
        let normalizado = nome.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let bancos: [(chave: String, hex: String)] = [
            ("cgd", "0A3D62"), ("caixa geral", "0A3D62"),
            ("millennium", "004B87"), ("bcp", "004B87"),
            ("santander", "EC0000"),
            ("novobanco", "DA291C"), ("novo banco", "DA291C"),
            ("bpi", "00205B"),
            ("activobank", "FF6600"),
            ("revolut", "0666EB"),
            ("n26", "36A18B"),
            ("montepio", "006633"),
            ("credito agricola", "006A4D"),
            ("bankinter", "D52B1E"),
            ("abanca", "00AEEF"),
        ]
        guard let encontrado = bancos.first(where: { normalizado.contains($0.chave) }) else { return nil }
        return Color(hex: encontrado.hex)
    }
}

// MARK: - Edição de movimentos

extension PropostaDeTransacao {
    /// Proposta pré-preenchida a partir de um movimento existente,
    /// para o cartão de confirmação servir também de editor.
    init(de transacao: Transacao) {
        self.init(
            valor: transacao.valor,
            tipo: transacao.tipo,
            descricao: transacao.descricao,
            loja: transacao.loja,
            nomeDaCategoria: transacao.categoria?.nome,
            data: transacao.data,
            nota: transacao.nota,
            fotoDoTalao: transacao.fotoDoTalao
        )
    }
}

extension Transacao {
    /// Aplica os campos editados; a categoria é resolvida pelo nome,
    /// como na confirmação original.
    func aplicar(_ proposta: PropostaDeTransacao, categorias: [Categoria]) {
        valor = proposta.valor
        tipo = proposta.tipo
        descricao = proposta.descricao
        loja = proposta.loja
        data = proposta.data
        categoria = categorias.first { $0.nome == proposta.nomeDaCategoria }
        nota = proposta.nota?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            ? nil : proposta.nota
        fotoDoTalao = proposta.fotoDoTalao
    }
}

/// A barra de progresso: fina (5 pt), cantos pouco arredondados e
/// preenchimento castanho liso, sem reflexo.
/// Aparece já cheia e só anima, depressa, quando o valor muda.
struct BarraDeProgresso: View {
    let fracao: Double
    var dourada = true
    /// Mais fina do que era — ela achou a barra pesada.
    var altura: CGFloat = 4
    /// Limites: âmbar a partir de 75% e vermelho a partir de 100%.
    var comEstado = false
    /// Um traço vertical a marcar onde o mês vai (fração do tempo).
    var marcador: Double?

    private var limitada: CGFloat { CGFloat(min(max(fracao, 0), 1)) }

    private var preenchimento: AnyShapeStyle {
        if comEstado, let cor = Tema.corDoLimite(fracao) { return AnyShapeStyle(cor) }
        return dourada ? Tema.douradoDaBarra : AnyShapeStyle(Tema.tintaSuave.opacity(0.55))
    }

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                // Cápsula em vez de retângulo quase quadrado — mais delicada.
                Capsule().fill(Tema.bege)
                Capsule()
                    .fill(preenchimento)
                    .frame(width: geometria.size.width * limitada)
                if let marcador {
                    Capsule()
                        .fill(Tema.tinta.opacity(0.55))
                        .frame(width: 2, height: altura + 6)
                        .offset(x: geometria.size.width * CGFloat(min(max(marcador, 0), 1)) - 1)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: altura)
        .animation(.snappy(duration: 0.25), value: fracao)
        .accessibilityValue("\(Int(limitada * 100)) por cento")
    }
}

/// O sol da Lume, desenhado em código: núcleo dourado e raios em cápsula,
/// a rodar devagarinho — vivo sem distrair.
struct SolDeLume: View {
    var animado = true

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var aRodar = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { indice in
                Capsule()
                    .fill(Tema.dourado.opacity(0.85))
                    .frame(width: 3.5, height: 16)
                    .offset(y: -38)
                    .rotationEffect(.degrees(Double(indice) * 45))
            }
            Circle()
                .fill(Tema.douradoPolido)
                .frame(width: 44, height: 44)
                .shadow(color: Tema.dourado.opacity(0.5), radius: 14)
        }
        .frame(width: 110, height: 110)
        .rotationEffect(.degrees(aRodar ? 360 : 0))
        .onAppear {
            guard animado, !reduzirMovimento else { return }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                aRodar = true
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Botões") {
    VStack(spacing: 12) {
        BotaoLume(titulo: "Criar novo objetivo", simbolo: "plus") {}
        BotaoLume(titulo: "Adicionar conta", simbolo: "plus", estilo: .secundario) {}
        BotaoLume(titulo: "Eliminar movimento", simbolo: "trash", estilo: .destrutivo) {}
        BotaoLume(titulo: "Criar objetivo", simbolo: "plus") {}
            .disabled(true)
    }
    .padding(24)
    .background(Tema.fundo)
}

#Preview("Barras e cartão café") {
    VStack(spacing: 16) {
        BarraDeProgresso(fracao: 0.73)
        BarraDeProgresso(fracao: 0.35)
        Text("Bom ritmo este mês")
            .font(Tema.fonte(14, .semibold))
            .foregroundStyle(Tema.tinta)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cartaoCafe()
    }
    .padding(24)
    .background(Tema.fundo)
}
