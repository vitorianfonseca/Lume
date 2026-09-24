import SwiftData
import SwiftUI

/// As contas como cartões físicos: desliza para escolher, vê o saldo
/// e os últimos movimentos de cada uma. A gestão vive nas Definições.
struct ContasView: View {
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]

    @State private var contaSelecionada: PersistentIdentifier?

    private var contaAtual: Conta? {
        contas.first { $0.persistentModelID == contaSelecionada } ?? contas.first
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
                        movimentosDaConta
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
    private var carrossel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(contas) { conta in
                    CartaoDeConta(conta: conta)
                        .containerRelativeFrame(.horizontal)
                        .id(conta.persistentModelID)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $contaSelecionada)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tema.margemDoEcra, for: .scrollContent)
    }

    @ViewBuilder
    private var movimentosDaConta: some View {
        if let conta = contaAtual {
            let daConta = Array(
                transacoes
                    .filter { $0.conta?.persistentModelID == conta.persistentModelID }
                    .prefix(6)
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("Movimentos — \(conta.nome)")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)

                if daConta.isEmpty {
                    Text("Ainda sem movimentos nesta conta.")
                        .font(.footnote)
                        .foregroundStyle(Tema.tintaSuave)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(daConta) { transacao in
                            LinhaDeTransacao(transacao: transacao)
                            Divider().overlay(Tema.separador)
                        }
                    }
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .animation(.snappy, value: conta.persistentModelID)
        }
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
                    .font(.footnote.weight(.semibold))
                    .kerning(2)
                    .gravado()
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.body.weight(.medium))
                    .opacity(0.85)
            }

            chip
                .padding(.top, 18)

            Spacer(minLength: 12)

            Text("••••  ••••  ••••  \(digitos)")
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .kerning(1)
                .gravado()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SALDO")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1.5)
                        .opacity(0.6)
                    Text(FormatadorDeMoeda.texto(conta.saldoAtual))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .gravado()
                }
                Spacer()
                Text(conta.tipo.nome.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.5)
                    .opacity(0.7)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .background { fundo }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(conta.nome), \(conta.tipo.nome), saldo \(FormatadorDeMoeda.texto(conta.saldoAtual))")
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

    /// O módulo EMV: dourado polido com as linhas de contacto.
    private var chip: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Tema.douradoPolido)
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
