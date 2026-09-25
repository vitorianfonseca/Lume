import SwiftUI

/// Linhas partilhadas entre o ecrã Hoje e o separador Movimentos.
/// Planas, como no Figma: texto sobre o fundo, sem ícones nem cartões.

/// O cabeçalho de todos os ecrãs, como nos frames do Figma:
/// legenda pequena em maiúsculas, título grande e o símbolo da Lume à direita.
struct CabecalhoDeEcra: View {
    let legenda: String
    let titulo: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(legenda)
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
                Text(titulo)
                    .font(Tema.fonte(27, .semibold))
                    .foregroundStyle(Tema.tinta)
            }
            Spacer()
            Image("SimboloLume")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
        }
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
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.douradoEscuro)
            }
        }
    }
}

struct LinhaDeTransacao: View {
    /// Como no Figma: no Resumo o subtítulo é "Hoje · Supermercado";
    /// no extrato dos Movimentos é "Supermercado · Talão".
    enum Estilo {
        case resumo
        case extrato
    }

    let transacao: Transacao
    var estilo = Estilo.resumo

    var body: some View {
        HStack(spacing: 12) {
            AvatarDeIniciais(texto: titulo)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(Tema.fonte(15, .medium))
                    .foregroundStyle(Tema.tinta)
                if let detalhe {
                    Text(detalhe)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }

            Spacer()

            Text(valorFormatado)
                .font(Tema.fonte(15))
                .monospacedDigit()
                .foregroundStyle(transacao.tipo == .receita ? Tema.positivo : Tema.tinta)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// A loja manda no título ("Pingo Doce"); sem loja, fica a descrição.
    private var titulo: String {
        transacao.loja ?? transacao.descricao
    }

    private var detalhe: String? {
        let partes: [String?] = switch estilo {
        case .resumo: [dataCurta, transacao.categoria?.nome]
        case .extrato: [transacao.categoria?.nome, transacao.origem.nome]
        }
        let visiveis = partes.compactMap { $0 }
        return visiveis.isEmpty ? nil : visiveis.joined(separator: " · ")
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

/// Avatar quadrado com as iniciais da loja, como nos frames.
struct AvatarDeIniciais: View {
    let texto: String
    var lado: CGFloat = 38

    var body: some View {
        Text(iniciais)
            .font(lado > 44 ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(Tema.douradoEscuro)
            .frame(width: lado, height: lado)
            .background(Tema.bege, in: RoundedRectangle(cornerRadius: lado > 44 ? 14 : 10))
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
    /// (legível sobre fundo claro), senão a mesma paleta estável por nome
    /// que pinta os cartões no separador Contas.
    var corDoCartao: Color {
        if principal { return Tema.douradoEscuro }
        let cores: [Color] = [
            Color(hex: "23242B"), Color(hex: "0F2C4B"), Color(hex: "14392B"),
            Color(hex: "3B1523"), Color(hex: "3A2E14"),
        ]
        let semente = nome.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return cores[semente % cores.count]
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
            data: transacao.data
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
    }
}

/// Barra fina do sistema visual: trilho discreto, preenchimento dourado
/// metálico (o único gradiente permitido) ou cinzento quando ainda há folga.
/// Enche com mola ao aparecer e anima as mudanças de valor.
struct BarraDeProgresso: View {
    let fracao: Double
    var dourada = true
    var altura: CGFloat = 6

    @State private var visivel = false

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.separador)
                Capsule()
                    .fill(dourada ? AnyShapeStyle(Tema.douradoMetalico) : AnyShapeStyle(Tema.tintaSuave.opacity(0.55)))
                    .frame(width: geometria.size.width * min(max(visivel ? fracao : 0, 0), 1))
            }
        }
        .frame(height: altura)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) {
                visivel = true
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: fracao)
        .accessibilityHidden(true)
    }
}

/// O sol da Lume, desenhado em código: núcleo dourado e raios em cápsula,
/// a rodar devagarinho — vivo sem distrair.
struct SolDeLume: View {
    var animado = true

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
            guard animado else { return }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                aRodar = true
            }
        }
        .accessibilityHidden(true)
    }
}
