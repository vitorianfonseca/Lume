import SwiftData
import SwiftUI

/// As contas como cartões físicos: desliza para escolher, vê o saldo
/// e os últimos movimentos de cada uma. A gestão vive nas Definições.
struct ContasView: View {
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]

    @State private var contaSelecionada: PersistentIdentifier?

    /// A principal (o cartão dourado) vem sempre à frente do carrossel.
    private var ordenadas: [Conta] {
        contas.sorted { ($0.principal ? 0 : 1, $0.nome) < ($1.principal ? 0 : 1, $1.nome) }
    }

    private var contaAtual: Conta? {
        contas.first { $0.persistentModelID == contaSelecionada } ?? ordenadas.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if contas.isEmpty {
                        ContentUnavailableView(
                            "Sem contas",
                            systemImage: "creditcard",
                            description: Text("Cria contas nas Definições para as veres aqui.")
                        )
                    } else {
                        carrossel
                        resumoDaConta
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Tema.fundo)
            .navigationTitle("Contas")
        }
    }

    /// Um cartão por página, com paragem alinhada — como folhear a carteira.
    /// A folga vertical dá espaço à sombra, que a ScrollView cortaria.
    private var carrossel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(ordenadas) { conta in
                    CartaoDeConta(conta: conta)
                        .containerRelativeFrame(.horizontal)
                        // Os cartões inclinam em 3D ao deslizar, como numa carteira.
                        .scrollTransition(axis: .horizontal) { conteudo, fase in
                            conteudo
                                .rotation3DEffect(.degrees(fase.value * -10), axis: (x: 0, y: 1, z: 0))
                                .scaleEffect(fase.isIdentity ? 1 : 0.94)
                                .opacity(fase.isIdentity ? 1 : 0.75)
                        }
                        .id(conta.persistentModelID)
                }
            }
            .padding(.vertical, 18)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $contaSelecionada)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tema.margemDoEcra, for: .scrollContent)
    }

    // MARK: - Resumo do mês da conta

    /// O que este separador acrescenta ao Movimentos: a visão por conta.
    /// O extrato completo e pesquisável vive no separador Movimentos.
    @ViewBuilder
    private var resumoDaConta: some View {
        if let conta = contaAtual {
            let resumo = resumoDoMes(de: conta)
            VStack(alignment: .leading, spacing: 4) {
                Text("Este mês — \(conta.nome)")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)

                VStack(spacing: 0) {
                    linhaDeResumo("Recebido", "+\(FormatadorDeMoeda.texto(resumo.recebido))", cor: Tema.positivo)
                    Divider().overlay(Tema.separador)
                    linhaDeResumo("Gasto", "−\(FormatadorDeMoeda.texto(resumo.gasto))", cor: Tema.tinta)
                    Divider().overlay(Tema.separador)
                    linhaDeResumo("Movimentos", "\(resumo.quantos)", cor: Tema.tinta)
                }

                Text("O extrato completo, com pesquisa, vive no separador Movimentos.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.top, 10)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .animation(.snappy, value: conta.persistentModelID)
        }
    }

    private func linhaDeResumo(_ titulo: String, _ valor: String, cor: Color) -> some View {
        HStack {
            Text(titulo)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
            Spacer()
            Text(valor)
                .font(Tema.fonte(15))
                .monospacedDigit()
                .foregroundStyle(cor)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func resumoDoMes(de conta: Conta) -> (gasto: Decimal, recebido: Decimal, quantos: Int) {
        let calendario = Calendar.current
        let doMes = transacoes.filter { transacao in
            transacao.conta?.persistentModelID == conta.persistentModelID
                && calendario.isDate(transacao.data, equalTo: .now, toGranularity: .month)
        }
        let gasto = doMes.filter { $0.tipo == .despesa }.reduce(Decimal.zero) { $0 + $1.valor }
        let recebido = doMes.filter { $0.tipo == .receita }.reduce(Decimal.zero) { $0 + $1.valor }
        return (gasto, recebido, doMes.count)
    }
}

/// Carrossel reutilizável dos cartões — no novo design vive no Planear.
struct CarrosselDeContas: View {
    @Query(sort: \Conta.nome) private var contas: [Conta]

    private var ordenadas: [Conta] {
        contas.sorted { ($0.principal ? 0 : 1, $0.nome) < ($1.principal ? 0 : 1, $1.nome) }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(ordenadas) { conta in
                    CartaoDeConta(conta: conta)
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(axis: .horizontal) { conteudo, fase in
                            conteudo
                                .rotation3DEffect(.degrees(fase.value * -10), axis: (x: 0, y: 1, z: 0))
                                .scaleEffect(fase.isIdentity ? 1 : 0.94)
                                .opacity(fase.isIdentity ? 1 : 0.75)
                        }
                        .id(conta.persistentModelID)
                }
            }
            .padding(.vertical, 14)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tema.margemDoEcra, for: .scrollContent)
    }
}

/// Um cartão bancário "físico": gradiente profundo com brilho de plástico,
/// chip EMV em dourado polido, contactless e texto gravado em relevo.
struct CartaoDeConta: View {
    let conta: Conta

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(conta.nome.uppercased())
                    .font(Tema.fonte(13, .semibold))
                    .kerning(2)
                    .gravado()
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(Tema.fonte(16, .medium))
                    .opacity(0.85)
            }

            chip
                .padding(.top, 18)

            Spacer(minLength: 12)

            Text("••••  ••••  ••••  \(digitos)")
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .gravado()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SALDO")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.6)
                    Text(FormatadorDeMoeda.texto(conta.saldoAtual))
                        .font(Tema.fonte(18, .semibold))
                        .monospacedDigit()
                        .gravado()
                }
                Spacer()
                Text(conta.tipo.nome.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .foregroundStyle(corDaTinta)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .background { fundo }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        // Sombra curta e suave, como um cartão pousado na mesa.
        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(conta.nome), \(conta.tipo.nome), saldo \(FormatadorDeMoeda.texto(conta.saldoAtual))")
    }

    /// No cartão dourado a tinta é escura e fixa; nos restantes é branca.
    private var corDaTinta: Color {
        conta.principal ? Color(hex: "38342E") : .white
    }

    private var fundo: some View {
        ZStack {
            LinearGradient(colors: paleta, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Brilho de plástico a apanhar luz no canto superior.
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
                center: .topLeading, startRadius: 0, endRadius: 260
            )
            // Reflexo diagonal fino a atravessar o cartão.
            LinearGradient(
                colors: [.clear, .white.opacity(0.07), .clear],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
        }
    }

    /// O módulo EMV com as linhas de contacto. No cartão dourado o chip
    /// é bronze escuro, para não se fundir com o plástico.
    private var corDoChip: LinearGradient {
        conta.principal
            ? LinearGradient(
                colors: [Color(hex: "5E4718"), Color(hex: "8C6A2C"), Color(hex: "B8934A")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            : Tema.douradoPolido
    }

    private var chip: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(corDoChip)
            .frame(width: 46, height: 34)
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.black.opacity(0.25), lineWidth: 0.8)
                    Path { caminho in
                        caminho.move(to: CGPoint(x: 0, y: 11))
                        caminho.addLine(to: CGPoint(x: 46, y: 11))
                        caminho.move(to: CGPoint(x: 0, y: 23))
                        caminho.addLine(to: CGPoint(x: 46, y: 23))
                        caminho.move(to: CGPoint(x: 23, y: 11))
                        caminho.addLine(to: CGPoint(x: 23, y: 23))
                    }
                    .stroke(.black.opacity(0.25), lineWidth: 0.8)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
    }

    /// Paletas de cartão; a escolha é estável por nome, para cada conta
    /// manter a sua cor entre execuções.
    private static let paletas: [[Color]] = [
        [Color(hex: "23242B"), Color(hex: "44464F")],  // grafite
        [Color(hex: "0F2C4B"), Color(hex: "23578C")],  // meia-noite
        [Color(hex: "14392B"), Color(hex: "2A6B51")],  // esmeralda
        [Color(hex: "3B1523"), Color(hex: "6E2A42")],  // bordô
        [Color(hex: "3A2E14"), Color(hex: "7A5A22")],  // bronze
    ]

    private var paleta: [Color] {
        // A conta principal usa o dourado da identidade — é o cartão de ouro.
        if conta.principal {
            return [Color(hex: "8C6A2C"), Color(hex: "C9A45A"), Color(hex: "E8CE8F")]
        }
        let semente = conta.nome.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.paletas[semente % Self.paletas.count]
    }

    /// Quatro dígitos decorativos, estáveis por nome — nunca dados reais.
    private var digitos: String {
        let semente = conta.nome.unicodeScalars.reduce(7) { ($0 * 31 + Int($1.value)) % 10000 }
        return String(format: "%04d", semente)
    }
}

private extension View {
    /// Texto "gravado" no plástico: sombra escura abaixo, luz acima.
    func gravado() -> some View {
        self
            .shadow(color: .black.opacity(0.45), radius: 0.6, y: 0.8)
            .shadow(color: .white.opacity(0.18), radius: 0.4, y: -0.5)
    }
}

#Preview {
    ContasView()
        .modelContainer(ContentorDeDados.emMemoria())
}
