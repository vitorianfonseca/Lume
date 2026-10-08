import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Sistema visual (espelho do Tema.swift da app)

/// As cores vivem em `CoresDoWidget` (IlustracoesDoWidget.swift): o
/// "Ouro no branco" da app, com modo escuro em preto fosco.
private enum Paleta {
    static let fundo = CoresDoWidget.fundo
    static let tinta = CoresDoWidget.tinta
    static let suave = CoresDoWidget.suave
    static let dourado = CoresDoWidget.dourado
    static let douradoClaro = CoresDoWidget.douradoClaro
    static let warm = CoresDoWidget.trilho
    static let areia = CoresDoWidget.cartao
    static let positivo = CoresDoWidget.positivo
    static let separador = CoresDoWidget.separador
}

/// A fonte do sistema (SF Pro) — o mesmo espelho de `Tema.fonte` da app.
private enum Fonte {
    static func lume(_ tamanho: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        .system(size: tamanho, weight: peso)
    }
}

// MARK: - Dados partilhados (espelho de PartilhaComWidget)

private struct Limite: Codable {
    var nome: String
    var gasto: Decimal
    var orcamento: Decimal

    var fracao: Double {
        guard orcamento > .zero else { return 0 }
        return min(1, (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue)
    }
}

private struct Movimento: Codable {
    var titulo: String
    var detalhe: String
    var valor: Decimal
    var receita: Bool
}

private struct Resumo: Codable {
    var versao = 2
    var disponivelDoMes: Decimal
    var porDia: Decimal
    var diasRestantes: Int
    var gastoDoMes: Decimal
    var rendimento: Decimal
    var gastoDeHoje: Decimal
    var disponivelHoje: Decimal
    var acumulado: [Double]
    var dentroDoLimite: Bool
    var limites: [Limite]
    var movimentos: [Movimento]
    var atualizadoEm: Date
    /// Perfil → Privacidade → "Esconder valores".
    var valoresEscondidos: Bool = false

    var fracaoUsada: Double {
        guard rendimento > .zero else { return 0 }
        return min(1, (gastoDoMes as NSDecimalNumber).doubleValue / (rendimento as NSDecimalNumber).doubleValue)
    }

    var percentagemUsada: Int {
        Int((fracaoUsada * 100).rounded())
    }

    static func doGrupo() -> Resumo? {
        guard let defaults = UserDefaults(suiteName: "group.com.vitoriafonseca.lume"),
              let dados = defaults.data(forKey: "resumoDoDia") else { return nil }
        return try? JSONDecoder().decode(Resumo.self, from: dados)
    }

    static let exemplo = Resumo(
        disponivelDoMes: 357.10,
        porDia: 59.52,
        diasRestantes: 6,
        gastoDoMes: 1092.90,
        rendimento: 1450,
        gastoDeHoje: 32.04,
        disponivelHoje: 27.48,
        acumulado: [42, 96, 150, 228, 310, 366, 430, 512, 590, 648, 712, 790,
                    848, 902, 944, 1002, 1060, 1092.90],
        dentroDoLimite: true,
        limites: [
            Limite(nome: "Casa", gasto: 441, orcamento: 450),
            Limite(nome: "Supermercado", gasto: 128, orcamento: 220),
            Limite(nome: "Transportes", gasto: 142.80, orcamento: 180),
        ],
        movimentos: [
            Movimento(titulo: "Pingo Doce", detalhe: "Supermercado", valor: 28.64, receita: false),
            Movimento(titulo: "Café", detalhe: "Restaurantes", valor: 3.40, receita: false),
            Movimento(titulo: "Galp", detalhe: "Transportes", valor: 20, receita: false),
        ],
        atualizadoEm: .now
    )
}

private func euros(_ valor: Decimal) -> String {
    agrupado(valor.formatted(.currency(code: "EUR").locale(Locale(identifier: "pt_PT"))))
}

/// Inteiros sem símbolo, para os pares "441 / 450 €".
private func inteiro(_ valor: Decimal) -> String {
    "\((valor as NSDecimalNumber).intValue)"
}

/// Com "Esconder valores" ativo, mostra pontos em vez do número — a forma
/// fica, o valor não. Usa-se em todo o sítio onde apareceria um euros(_:)
/// ou inteiro(_:).
private func euros(_ valor: Decimal, escondido: Bool) -> String {
    escondido ? "•••• €" : euros(valor)
}

private func inteiro(_ valor: Decimal, escondido: Bool) -> String {
    escondido ? "••" : inteiro(valor)
}

/// O pt-PT só agrupa a partir de 10 000 — o design escreve "1 092,90 €".
private func agrupado(_ original: String) -> String {
    guard let fim = original.firstIndex(of: ",") else { return original }
    var inicio = fim
    while inicio > original.startIndex, original[original.index(before: inicio)].isNumber {
        inicio = original.index(before: inicio)
    }
    let digitos = Array(original[inicio..<fim])
    guard digitos.count > 3 else { return original }
    var resultado = ""
    for (indice, digito) in digitos.enumerated() {
        if indice > 0, (digitos.count - indice) % 3 == 0 { resultado.append("\u{00A0}") }
        resultado.append(digito)
    }
    return original.replacingCharacters(in: inicio..<fim, with: resultado)
}

// MARK: - Ligações para a app

private enum Ligacao {
    static let resumo = URL(string: "lume://resumo")!
    static let movimentos = URL(string: "lume://movimentos")!
    static let texto = URL(string: "lume://registar/texto")!
    static let voz = URL(string: "lume://registar/voz")!
    static let talao = URL(string: "lume://registar/talao")!
    static let planear = URL(string: "lume://planear")!
}

// MARK: - Peças

/// A barra do orçamento: fina, cantos pouco arredondados, castanho liso.
private struct Barra: View {
    let fracao: Double
    var altura: CGFloat = 5

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5).fill(Paleta.warm)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(CoresDoWidget.ouroDaBarra)
                    .frame(width: geometria.size.width * min(max(fracao, 0), 1))
            }
        }
        .frame(height: altura)
    }
}

/// O ritmo do mês: linha dourada do acumulado contra a referência tracejada
/// (gastar o orçamento a ritmo constante) — o mesmo gráfico do Resumo.
private struct Ritmo: View {
    let pontos: [Double]
    let orcamento: Decimal

    var body: some View {
        GeometryReader { geometria in
            let largura = geometria.size.width
            let altura = geometria.size.height
            let teto = max(
                pontos.last ?? 0,
                (orcamento as NSDecimalNumber).doubleValue,
                1
            )

            ZStack {
                // Referência: do canto inferior esquerdo ao orçamento cheio.
                Path { caminho in
                    caminho.move(to: CGPoint(x: 0, y: altura))
                    caminho.addLine(to: CGPoint(
                        x: largura,
                        y: altura - altura * ((orcamento as NSDecimalNumber).doubleValue / teto)
                    ))
                }
                .stroke(Paleta.suave.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                // Gasto acumulado.
                Path { caminho in
                    guard pontos.count > 1 else { return }
                    let passo = largura / CGFloat(pontos.count - 1)
                    for (indice, valor) in pontos.enumerated() {
                        let ponto = CGPoint(
                            x: CGFloat(indice) * passo,
                            y: altura - altura * (valor / teto)
                        )
                        if indice == 0 {
                            caminho.move(to: ponto)
                        } else {
                            caminho.addLine(to: ponto)
                        }
                    }
                }
                .stroke(CoresDoWidget.ouroDaBarra, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// As três ações de registo, cada uma com a sua ligação para a app.
private struct AcoesDeRegisto: View {
    var compacto = false

    var body: some View {
        HStack(spacing: 6) {
            acao("Escrever", simbolo: nil, ligacao: Ligacao.texto)
            acao("Falar", simbolo: "mic.fill", ligacao: Ligacao.voz)
            acao("Talão", simbolo: "camera.fill", ligacao: Ligacao.talao)
        }
    }

    /// As três no mesmo cinza-pedra — o verde e o pêssego ficam só para o
    /// estado do ritmo, para não repetir a mesma cor com dois significados
    /// (ela achou o widget com muitos pastéis diferentes, "enjoativo").
    private func acao(_ titulo: String, simbolo: String?, ligacao: URL) -> some View {
        Link(destination: ligacao) {
            HStack(spacing: 5) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: compacto ? 10 : 11))
                        .foregroundStyle(CoresDoWidget.dourado)
                } else {
                    Text("T")
                        .font(.system(size: compacto ? 11 : 12, weight: .medium, design: .serif))
                        .foregroundStyle(CoresDoWidget.dourado)
                }
                if !compacto {
                    Text(titulo)
                        .font(Fonte.lume(11, .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(Paleta.tinta)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: compacto ? 28 : 32)
            .background(CoresDoWidget.cartao, in: RoundedRectangle(cornerRadius: 11))
        }
    }
}

private struct LinhaDeLimite: View {
    let limite: Limite
    var escondido = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(limite.nome)
                    .font(Fonte.lume(11, .medium))
                    .foregroundStyle(Paleta.tinta)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(inteiro(limite.gasto, escondido: escondido)) / \(inteiro(limite.orcamento, escondido: escondido)) €")
                    .font(Fonte.lume(10))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.suave)
            }
            Barra(fracao: escondido ? 0 : limite.fracao, altura: 4)
        }
    }
}

// MARK: - Widget "O teu mês"

private struct EntradaDoMes: TimelineEntry {
    let date: Date
    let resumo: Resumo?
}

private struct FornecedorDoMes: TimelineProvider {
    func placeholder(in context: Context) -> EntradaDoMes {
        EntradaDoMes(date: .now, resumo: .exemplo)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaDoMes) -> Void) {
        completion(EntradaDoMes(date: .now, resumo: Resumo.doGrupo() ?? .exemplo))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaDoMes>) -> Void) {
        // Renova à meia-noite: o "por dia" e os dias restantes mudam de dia.
        let meiaNoite = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        completion(Timeline(
            entries: [EntradaDoMes(date: .now, resumo: Resumo.doGrupo())],
            policy: .after(meiaNoite)
        ))
    }
}

private struct VistaDoMes: View {
    @Environment(\.widgetFamily) private var familia
    let entrada: EntradaDoMes

    var body: some View {
        Group {
            if let resumo = entrada.resumo {
                switch familia {
                case .systemLarge: grande(resumo)
                case .systemMedium: medio(resumo)
                case .accessoryCircular: circular(resumo)
                case .accessoryRectangular: retangular(resumo)
                case .accessoryInline: Text(
                    resumo.valoresEscondidos
                        ? "Lume · valores escondidos"
                        : "\(euros(resumo.porDia))/dia · \(euros(resumo.disponivelDoMes))"
                )
                default: pequeno(resumo)
                }
            } else {
                vazio
            }
        }
        .containerBackground(Paleta.fundo, for: .widget)
    }

    /// O cartão pastel do estado do mês: verde quando o ritmo está bom,
    /// pêssego quando está acima.
    private func corDoEstado(_ resumo: Resumo) -> Color {
        resumo.dentroDoLimite ? CoresDoWidget.menta : CoresDoWidget.pessego
    }

    private func ilustracao(_ resumo: Resumo) -> IlustracaoDoWidget {
        IlustracaoDoWidget(tipo: resumo.dentroDoLimite ? .frasco : .graficos)
    }

    private func diasEmFalta(_ resumo: Resumo) -> String {
        resumo.diasRestantes == 1 ? "falta 1 dia" : "faltam \(resumo.diasRestantes) dias"
    }

    private func estado(_ resumo: Resumo) -> some View {
        Text(resumo.dentroDoLimite ? "Bom ritmo" : "Acima do ritmo")
            .font(Fonte.lume(10, .semibold))
            .foregroundStyle(resumo.dentroDoLimite ? AnyShapeStyle(Paleta.positivo) : AnyShapeStyle(CoresDoWidget.castanho))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    // MARK: Ecrã inicial

    private func pequeno(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("POR DIA")
                        .font(Fonte.lume(9, .semibold))
                        .foregroundStyle(CoresDoWidget.castanho)
                    estado(resumo)
                }
                Spacer(minLength: 0)
                ilustracao(resumo)
                    .frame(width: 44, height: 44)
                    .background(corDoEstado(resumo), in: Circle())
            }

            Spacer(minLength: 2)

            Text(euros(resumo.porDia, escondido: resumo.valoresEscondidos))
                .font(Fonte.lume(26, .semibold))
                .monospacedDigit()
                .foregroundStyle(Paleta.tinta)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("podes gastar · \(diasEmFalta(resumo))")
                .font(Fonte.lume(9))
                .foregroundStyle(Paleta.suave)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            Barra(fracao: resumo.valoresEscondidos ? 0 : resumo.fracaoUsada)
            HStack(spacing: 4) {
                Text("Gasto")
                    .font(Fonte.lume(9))
                    .foregroundStyle(Paleta.suave)
                Spacer(minLength: 0)
                Text(euros(resumo.gastoDoMes, escondido: resumo.valoresEscondidos))
                    .font(Fonte.lume(9, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
            }
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(Ligacao.resumo)
        .overlay(alignment: .bottomTrailing) {
            // Um toque para registar, sem ter de abrir primeiro o Resumo.
            Link(destination: Ligacao.texto) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CoresDoWidget.dourado)
                    .frame(width: 26, height: 26)
                    .background(CoresDoWidget.cartao, in: Circle())
            }
            .accessibilityLabel("Registar")
        }
    }

    private func medio(_ resumo: Resumo) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("POR DIA")
                    .font(Fonte.lume(9, .semibold))
                    .foregroundStyle(CoresDoWidget.castanho)
                Text(euros(resumo.porDia, escondido: resumo.valoresEscondidos))
                    .font(Fonte.lume(28, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(
                    resumo.valoresEscondidos
                        ? "Valores escondidos"
                        : "Gasto \(euros(resumo.gastoDoMes)) de \(euros(resumo.rendimento))"
                )
                    .font(Fonte.lume(9))
                    .foregroundStyle(Paleta.suave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 1)

                Spacer(minLength: 6)
                Barra(fracao: resumo.valoresEscondidos ? 0 : resumo.fracaoUsada)
                Spacer(minLength: 8)

                // À largura do médio, os rótulos não cabem: ficam os ícones.
                AcoesDeRegisto(compacto: true)
            }

            // O estado do mês num cartão pastel com a ilustração.
            VStack(alignment: .leading, spacing: 4) {
                ilustracao(resumo)
                    .frame(width: 50, height: 50)
                    .frame(maxWidth: .infinity)
                estado(resumo)
                Text(diasEmFalta(resumo))
                    .font(Fonte.lume(9))
                    .foregroundStyle(Paleta.suave)
                if !resumo.valoresEscondidos {
                    Ritmo(pontos: resumo.acumulado, orcamento: resumo.rendimento)
                        .frame(height: 22)
                }
            }
            .padding(10)
            .frame(width: 112)
            .frame(maxHeight: .infinity)
            .background(corDoEstado(resumo), in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func grande(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Link(destination: Ligacao.resumo) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("POR DIA")
                            .font(Fonte.lume(9, .semibold))
                            .foregroundStyle(CoresDoWidget.castanho)
                        Text(euros(resumo.porDia, escondido: resumo.valoresEscondidos))
                            .font(Fonte.lume(32, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Paleta.tinta)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("podes gastar · \(diasEmFalta(resumo))")
                            .font(Fonte.lume(10))
                            .foregroundStyle(Paleta.suave)
                        estado(resumo)
                            .padding(.top, 3)
                    }
                    Spacer(minLength: 4)
                    ilustracao(resumo)
                        .frame(width: 66, height: 66)
                }
                .padding(12)
                .background(corDoEstado(resumo), in: RoundedRectangle(cornerRadius: 18))
            }

            HStack {
                Text(
                    resumo.valoresEscondidos
                        ? "Valores escondidos"
                        : "Gasto \(euros(resumo.gastoDoMes)) de \(euros(resumo.rendimento))"
                )
                    .font(Fonte.lume(10))
                    .foregroundStyle(Paleta.suave)
                Spacer()
                if !resumo.valoresEscondidos {
                    Ritmo(pontos: resumo.acumulado, orcamento: resumo.rendimento)
                        .frame(width: 80, height: 18)
                }
            }
            .padding(.top, 10)
            Barra(fracao: resumo.valoresEscondidos ? 0 : resumo.fracaoUsada)
                .padding(.top, 5)

            if !resumo.limites.isEmpty {
                Link(destination: Ligacao.planear) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(resumo.limites.prefix(2), id: \.nome) { limite in
                            LinhaDeLimite(limite: limite, escondido: resumo.valoresEscondidos)
                        }
                    }
                }
                .padding(.top, 12)
            }

            if !resumo.movimentos.isEmpty {
                Divider().overlay(Paleta.separador).padding(.vertical, 9)
                Link(destination: Ligacao.movimentos) {
                    VStack(spacing: 6) {
                        ForEach(Array(resumo.movimentos.prefix(2).enumerated()), id: \.offset) { _, movimento in
                            HStack(spacing: 8) {
                                Text(iniciais(de: movimento.titulo))
                                    .font(Fonte.lume(9, .semibold))
                                    .foregroundStyle(Paleta.tinta)
                                    .frame(width: 26, height: 26)
                                    // Um só neutro — o verde e o pêssego ficam só
                                    // para o estado do ritmo, como no resto do widget.
                                    .background(CoresDoWidget.trilho, in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(movimento.titulo)
                                        .font(Fonte.lume(11, .medium))
                                        .foregroundStyle(Paleta.tinta)
                                        .lineLimit(1)
                                    Text(movimento.detalhe)
                                        .font(Fonte.lume(9))
                                        .foregroundStyle(Paleta.suave)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text((movimento.receita ? "+" : "−") + euros(movimento.valor, escondido: resumo.valoresEscondidos))
                                    .font(Fonte.lume(11, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(movimento.receita ? Paleta.positivo : Paleta.tinta)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 8)
            AcoesDeRegisto()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Ecrã bloqueado

    private func circular(_ resumo: Resumo) -> some View {
        // Escondido, o aro fica vazio em vez de denunciar a percentagem.
        Gauge(value: resumo.valoresEscondidos ? 0 : resumo.fracaoUsada) {
            Image(systemName: "eurosign")
        } currentValueLabel: {
            Text(inteiro(resumo.disponivelDoMes, escondido: resumo.valoresEscondidos))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(Ligacao.resumo)
    }

    private func retangular(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("POR DIA")
                .font(.system(size: 10, weight: .semibold))
            Text(euros(resumo.porDia, escondido: resumo.valoresEscondidos))
                .font(.system(size: 18, weight: .medium))
                .monospacedDigit()
            Text(
                "Disponível \(euros(resumo.disponivelDoMes, escondido: resumo.valoresEscondidos)) · "
                    + "\(resumo.diasRestantes) \(resumo.diasRestantes == 1 ? "dia" : "dias")"
            )
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(Ligacao.resumo)
    }

    private var vazio: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                Text("LUME")
                    .font(Fonte.lume(9, .semibold))
                    .foregroundStyle(CoresDoWidget.castanho)
                Spacer()
                IlustracaoDoWidget(tipo: .carteira)
                    .frame(width: 48, height: 48)
                    .background(CoresDoWidget.menta, in: Circle())
            }
            Spacer(minLength: 0)
            Text("Define o orçamento do mês para ver os teus números aqui.")
                .font(Fonte.lume(11))
                .foregroundStyle(Paleta.suave)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(Ligacao.planear)
    }

    private func iniciais(de texto: String) -> String {
        let letras = texto.split(separator: " ").prefix(2).compactMap(\.first)
        return letras.isEmpty ? "•" : String(letras).uppercased()
    }
}

struct WidgetDoMes: Widget {
    let kind = "LumeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FornecedorDoMes()) { entrada in
            VistaDoMes(entrada: entrada)
        }
        .configurationDisplayName("O teu mês")
        .description("O que ainda podes gastar, o ritmo do mês e o registo a um toque.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - Widget "Os teus limites"

private struct VistaDosLimites: View {
    @Environment(\.widgetFamily) private var familia
    let entrada: EntradaDoMes

    var body: some View {
        Group {
            if let resumo = entrada.resumo, !resumo.limites.isEmpty {
                VStack(alignment: .leading, spacing: familia == .systemSmall ? 8 : 10) {
                    HStack(alignment: .top) {
                        Text("OS TEUS LIMITES")
                            .font(Fonte.lume(9, .semibold))
                            .foregroundStyle(CoresDoWidget.castanho)
                        Spacer()
                        IlustracaoDoWidget(tipo: .graficos)
                            .frame(width: 30, height: 30)
                            .background(CoresDoWidget.ceu, in: Circle())
                    }
                    ForEach(resumo.limites.prefix(familia == .systemSmall ? 2 : 3), id: \.nome) { limite in
                        LinhaDeLimite(limite: limite, escondido: resumo.valoresEscondidos)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(Ligacao.planear)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OS TEUS LIMITES")
                        .font(Fonte.lume(9, .semibold))
                        .foregroundStyle(CoresDoWidget.castanho)
                    Text("Define limites por categoria no Planear.")
                        .font(Fonte.lume(11))
                        .foregroundStyle(Paleta.suave)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(Ligacao.planear)
            }
        }
        .containerBackground(Paleta.fundo, for: .widget)
    }
}

struct WidgetDosLimites: Widget {
    let kind = "LumeLimites"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FornecedorDoMes()) { entrada in
            VistaDosLimites(entrada: entrada)
        }
        .configurationDisplayName("Os teus limites")
        .description("As categorias mais apertadas do mês, sempre à vista.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Controlo (Centro de Controlo, Botão de Ação e ecrã bloqueado)

@available(iOS 18.0, *)
@available(iOS 18.0, *)
struct ControloDeRegistoGeral: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aurea.lume.controlo.registarGeral") {
            ControlWidgetButton(action: OpenURLIntent(Ligacao.texto)) {
                Label("Registar", systemImage: "plus")
            }
        }
        .displayName("Registar")
        .description("Abre a Lume para registares uma despesa ou receita.")
    }
}

@available(iOS 18.0, *)
struct ControloDeRegisto: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aurea.lume.controlo.registar") {
            ControlWidgetButton(action: OpenURLIntent(Ligacao.voz)) {
                Label("Registar", systemImage: "mic.fill")
            }
        }
        .displayName("Registar por voz")
        .description("Abre a Lume a ouvir.")
    }
}

// MARK: - Pré-visualizações

#Preview("Pequeno", as: .systemSmall) {
    WidgetDoMes()
} timeline: {
    EntradaDoMes(date: .now, resumo: .exemplo)
}

#Preview("Médio", as: .systemMedium) {
    WidgetDoMes()
} timeline: {
    EntradaDoMes(date: .now, resumo: .exemplo)
}

#Preview("Grande", as: .systemLarge) {
    WidgetDoMes()
} timeline: {
    EntradaDoMes(date: .now, resumo: .exemplo)
}

#Preview("Limites", as: .systemMedium) {
    WidgetDosLimites()
} timeline: {
    EntradaDoMes(date: .now, resumo: .exemplo)
}
