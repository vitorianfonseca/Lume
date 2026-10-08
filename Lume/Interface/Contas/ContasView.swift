import SwiftData
import SwiftUI

/// As contas como cartões: desliza para escolher (o próximo cartão
/// espreita à direita e os pontos dizem quantas há), vê o saldo e o resumo
/// do mês de cada uma. A gestão vive nas Definições.
///
/// Abre-se dentro do `NavigationStack` do Perfil: não tem pilha própria,
/// esconde a barra do sistema e mostra o voltar do cabeçalho padrão.
struct ContasView: View {
    @Environment(\.dismiss) private var dismiss
    /// Verdadeiro quando foi empurrado (Perfil); na raiz não há voltar.
    @Environment(\.isPresented) private var foiAberto
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query(sort: \Transacao.data, order: .reverse) private var transacoes: [Transacao]

    @State private var contaSelecionada: PersistentIdentifier?
    @State private var contaDosMovimentos: Conta?

    private var ordenadas: [Conta] { contas.ordenadasPorPrincipal }

    private var contaAtual: Conta? {
        contas.first { $0.persistentModelID == contaSelecionada } ?? ordenadas.first
    }

    private var legenda: String {
        contas.count == 1 ? "1 conta" : "\(contas.count) contas"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: legenda,
                    titulo: "Contas",
                    aoVoltar: foiAberto ? { dismiss() } : nil
                )
                .padding(.horizontal, Tema.margemDoEcra)

                if contas.isEmpty {
                    EstadoVazio(
                        ilustracao: .cartoes,
                        titulo: "Sem contas",
                        texto: "Cria contas no Perfil, em Contas e carteiras, para as veres aqui."
                    )
                    .padding(.horizontal, Tema.margemDoEcra)
                    .padding(.top, 40)
                } else {
                    CarrosselDeCartoes(contas: ordenadas, selecionada: $contaSelecionada)

                    if let conta = contaAtual {
                        VStack(alignment: .leading, spacing: 16) {
                            if conta.saldoAtual < .zero {
                                avisoDeDescoberto(conta)
                            }
                            resumo(de: conta)
                        }
                        .padding(.horizontal, Tema.margemDoEcra)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Tema.fundo)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $contaDosMovimentos) { conta in
            MovimentosDaContaView(conta: conta)
        }
    }

    // MARK: - Descoberto

    /// Um descoberto é informação crítica, mas dita com calma: vermelho
    /// suave, sem alarmes.
    private func avisoDeDescoberto(_ conta: Conta) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tema.negativo)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Conta a descoberto")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.negativo)
                Text("O saldo está em \(FormatadorDeMoeda.texto(conta.saldoAtual)). Uma receita ou transferência repõe-no acima de zero.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Tema.fundoNegativo, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Resumo do mês da conta

    /// O que este ecrã acrescenta ao Movimentos: a visão por conta.
    /// O extrato da conta abre-se na última linha do cartão.
    private func resumo(de conta: Conta) -> some View {
        let resumo = resumoDoMes(de: conta)
        return VStack(alignment: .leading, spacing: 0) {
            Legenda("Este mês · \(conta.nome)")
                .padding(.top, 16)
                .padding(.bottom, 4)

            linhaDeResumo("Saldo atual", FormatadorDeMoeda.texto(conta.saldoAtual),
                          cor: conta.saldoAtual < .zero ? Tema.negativo : Tema.tinta)
            Divider().overlay(Tema.separador)
            linhaDeResumo("Recebido",
                          resumo.recebido > .zero ? "+\(FormatadorDeMoeda.texto(resumo.recebido))" : FormatadorDeMoeda.texto(.zero),
                          cor: resumo.recebido > .zero ? Tema.positivo : Tema.tinta)
            Divider().overlay(Tema.separador)
            linhaDeResumo("Gasto", resumo.gasto > .zero ? "−\(FormatadorDeMoeda.texto(resumo.gasto))" : FormatadorDeMoeda.texto(.zero), cor: Tema.tinta)
            Divider().overlay(Tema.separador)
            linhaDeResumo("Movimentos", "\(resumo.quantos)", cor: Tema.tinta)
            Divider().overlay(Tema.separador)

            Button {
                contaDosMovimentos = conta
            } label: {
                HStack {
                    Text("Ver movimentos desta conta")
                        .font(Tema.fonte(15, .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Tema.ouro)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(EscalaAoTocar())
        }
        .padding(.horizontal, 18)
        .cartao()
    }

    private func linhaDeResumo(_ titulo: String, _ valor: String, cor: Color) -> some View {
        HStack {
            Text(titulo)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
            Spacer()
            Text(valor)
                .font(Tema.fonte(15, .medium))
                .monospacedDigit()
                .foregroundStyle(cor)
        }
        .frame(minHeight: 48)
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

// MARK: - Movimentos de uma conta

/// O extrato de uma só conta, agrupado por dia, com o cabeçalho padrão.
private struct MovimentosDaContaView: View {
    let conta: Conta
    @Environment(\.dismiss) private var dismiss

    private var movimentos: [Transacao] {
        (conta.transacoes ?? []).sorted { $0.data > $1.data }
    }

    private var porDia: [(dia: Date, transacoes: [Transacao])] {
        let calendario = Calendar.current
        return Dictionary(grouping: movimentos) { calendario.startOfDay(for: $0.data) }
            .sorted { $0.key > $1.key }
            .map { (dia: $0.key, transacoes: $0.value.sorted { $0.data > $1.data }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: movimentos.count == 1 ? "1 movimento" : "\(movimentos.count) movimentos",
                    titulo: conta.nome,
                    aoVoltar: { dismiss() }
                )

                if movimentos.isEmpty {
                    EstadoVazio(
                        ilustracao: .carteira,
                        titulo: "Sem movimentos",
                        texto: "Os registos feitos nesta conta aparecem aqui."
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(porDia, id: \.dia) { grupo in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(titulo(para: grupo.dia))
                                    .font(Tema.fonte(15, .semibold))
                                    .foregroundStyle(Tema.tinta)
                                Spacer()
                                Text(saldoDoDia(grupo.transacoes))
                                    .font(Tema.fonte(12, .medium))
                                    .monospacedDigit()
                                    .textoDourado()
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(grupo.transacoes.enumerated()), id: \.element.persistentModelID) { indice, transacao in
                                    if indice > 0 {
                                        Divider().overlay(Tema.separador)
                                    }
                                    LinhaDeTransacao(transacao: transacao, estilo: .extrato)
                                }
                            }
                            .padding(.horizontal, 16)
                            .cartao()
                        }
                    }
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Tema.fundo)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// "Hoje, 1 outubro" · "Ontem, 30 setembro" · "Segunda-feira, 28 setembro".
    private func titulo(para dia: Date) -> String {
        let calendario = Calendar.current
        let local = FormatadorDeMoeda.localidade
        let diaEMes = "\(dia.formatted(.dateTime.day().locale(local))) \(dia.formatted(.dateTime.month(.wide).locale(local)))"
        if calendario.isDateInToday(dia) { return "Hoje, \(diaEMes)" }
        if calendario.isDateInYesterday(dia) { return "Ontem, \(diaEMes)" }
        let semana = dia.formatted(.dateTime.weekday(.wide).locale(local))
        return "\(semana.prefix(1).uppercased() + semana.dropFirst()), \(diaEMes)"
    }

    /// O total do dia, só com os movimentos desse dia: "+12,00 €" ou "−106,90 €".
    private func saldoDoDia(_ transacoes: [Transacao]) -> String {
        let total = transacoes.reduce(Decimal.zero) { soma, transacao in
            transacao.tipo == .receita ? soma + transacao.valor : soma - transacao.valor
        }
        let texto = FormatadorDeMoeda.texto(total)
        return total > .zero ? "+\(texto)" : texto
    }
}

// MARK: - Carrossel

/// Carrossel reutilizável dos cartões (Perfil → Contas e carteiras).
struct CarrosselDeContas: View {
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @State private var selecionada: PersistentIdentifier?

    var body: some View {
        CarrosselDeCartoes(contas: contas.ordenadasPorPrincipal, selecionada: $selecionada)
    }
}

/// Um cartão por paragem, com o seguinte a espreitar à direita e pontos
/// de página por baixo — percebe-se logo que há mais para deslizar.
/// Sem inclinações nem efeitos ao deslizar: só o movimento do dedo.
private struct CarrosselDeCartoes: View {
    let contas: [Conta]
    @Binding var selecionada: PersistentIdentifier?

    /// Quanto do próximo cartão fica à vista.
    private let espreitadela: CGFloat = 28

    private var atual: PersistentIdentifier? {
        selecionada ?? contas.first?.persistentModelID
    }

    var body: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(contas) { conta in
                        CartaoDeConta(conta: conta)
                            .containerRelativeFrame(.horizontal) { largura, _ in
                                contas.count > 1 ? max(largura - espreitadela, 0) : largura
                            }
                            .id(conta.persistentModelID)
                    }
                }
                .padding(.vertical, 10)
                .scrollTargetLayout()
            }
            // A sombra dos cartões não fica cortada nas margens da ScrollView.
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selecionada)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Tema.margemDoEcra, for: .scrollContent)

            if contas.count > 1 {
                pontos
            }
        }
    }

    private var pontos: some View {
        HStack(spacing: 6) {
            ForEach(contas) { conta in
                let ativa = conta.persistentModelID == atual
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        selecionada = conta.persistentModelID
                    }
                } label: {
                    Circle()
                        .fill(ativa ? Tema.ouro : AnyShapeStyle(Tema.separador))
                        .frame(width: 7, height: 7)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotuloDosPontos)
    }

    private var rotuloDosPontos: String {
        let posicao = (contas.firstIndex { $0.persistentModelID == atual } ?? 0) + 1
        return "Conta \(posicao) de \(contas.count)"
    }
}

// MARK: - Cartão

/// O cartão de uma conta: nome, tipo e saldo sobre o gradiente da conta
/// (dourado para a principal). Baixo e limpo — sem chip, contactless nem
/// número mascarado, que ocupavam espaço sem dar informação.
struct CartaoDeConta: View {
    let conta: Conta

    private var descoberto: Bool { conta.saldoAtual < .zero }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(conta.nome)
                        .font(Tema.fonte(17, .semibold))
                        .lineLimit(1)
                    Text(conta.tipo.nome)
                        .font(Tema.fonte(12, .medium))
                        .opacity(0.72)
                }
                Spacer(minLength: 8)
                if conta.principal {
                    Text("PRINCIPAL")
                        .font(Tema.fonte(10, .semibold))
                        .tracking(1.2)
                        .opacity(0.72)
                }
            }

            Spacer(minLength: 12)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saldo")
                        .font(Tema.fonte(11, .medium))
                        .opacity(0.72)
                    saldo
                }
                Spacer(minLength: 8)
                if descoberto {
                    Text("A descoberto")
                        .font(Tema.fonte(11, .semibold))
                        .foregroundStyle(Tema.negativo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Tema.fundoNegativo, in: Capsule())
                        .environment(\.colorScheme, .light)
                }
            }
        }
        .padding(20)
        .foregroundStyle(corDaTinta)
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .background {
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .fill(LinearGradient(colors: paleta, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
                .sombraDeCartao()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotulo)
    }

    /// Euros grandes e cêntimos menores, com o sinal "−" tipográfico.
    private var saldo: some View {
        let texto = FormatadorDeMoeda.texto(conta.saldoAtual)
        let virgula = texto.lastIndex(of: ",") ?? texto.endIndex
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(texto[..<virgula])
                .font(Tema.fonte(28, .semibold))
            Text(texto[virgula...])
                .font(Tema.fonte(14, .medium))
                .opacity(0.8)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var rotulo: String {
        var partes = [conta.nome, conta.tipo.nome]
        if conta.principal { partes.append("conta principal") }
        partes.append("saldo \(FormatadorDeMoeda.falado(conta.saldoAtual))")
        if descoberto { partes.append("a descoberto") }
        return partes.joined(separator: ", ")
    }

    /// No cartão dourado a tinta é escura e fixa; nos restantes é branca.
    private var corDaTinta: Color {
        conta.principal ? Color(hex: "38342E") : .white
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
            return [Color(hex: "B8934A"), Color(hex: "D4B06A"), Color(hex: "E8CE8F")]
        }
        let semente = conta.nome.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.paletas[semente % Self.paletas.count]
    }
}

private extension Array where Element == Conta {
    /// A principal (o cartão dourado) vem sempre à frente do carrossel.
    var ordenadasPorPrincipal: [Conta] {
        sorted { ($0.principal ? 0 : 1, $0.nome) < ($1.principal ? 0 : 1, $1.nome) }
    }
}

#Preview {
    NavigationStack {
        ContasView()
    }
    .modelContainer(ContentorDeDados.emMemoria())
}
