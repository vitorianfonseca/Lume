import AppIntents
import CoreText
import SwiftUI
import WidgetKit

// MARK: - Sistema visual (espelho do Tema.swift da app)

private enum Paleta {
    static let fundo = Color(red: 1, green: 1, blue: 1)
    static let tinta = Color(red: 0x30 / 255, green: 0x2B / 255, blue: 0x24 / 255)
    static let suave = Color(red: 0x7B / 255, green: 0x73 / 255, blue: 0x67 / 255)
    static let dourado = Color(red: 0x8E / 255, green: 0x64 / 255, blue: 0x1F / 255)
    static let douradoClaro = Color(red: 0xE8 / 255, green: 0xCD / 255, blue: 0x91 / 255)
    static let warm = Color(red: 0xF0 / 255, green: 0xEB / 255, blue: 0xE1 / 255)
    static let areia = Color(red: 0xF7 / 255, green: 0xEE / 255, blue: 0xDB / 255)
    static let positivo = Color(red: 0x45 / 255, green: 0x6B / 255, blue: 0x56 / 255)
    static let separador = Color(red: 0xE7 / 255, green: 0xE0 / 255, blue: 0xD5 / 255)
}

/// O Instrument Sans vive no contentor partilhado; a app põe-o lá e o widget
/// regista-o no próprio processo. Se faltar, o `.custom` cai na fonte do
/// sistema sem quebrar nada.
private enum Fonte {
    private static let registada: Bool = {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.aurea.lume")?
            .appending(path: "InstrumentSans.ttf") else { return false }
        var erro: Unmanaged<CFError>?
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, &erro)
    }()

    static func lume(_ tamanho: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        _ = registada
        return .custom("Instrument Sans", size: tamanho).weight(peso)
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

    var fracaoUsada: Double {
        guard rendimento > .zero else { return 0 }
        return min(1, (gastoDoMes as NSDecimalNumber).doubleValue / (rendimento as NSDecimalNumber).doubleValue)
    }

    var percentagemUsada: Int {
        Int((fracaoUsada * 100).rounded())
    }

    static func doGrupo() -> Resumo? {
        guard let defaults = UserDefaults(suiteName: "group.com.aurea.lume"),
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

/// A barra do orçamento: goldLight sobre warm, como na app.
private struct Barra: View {
    let fracao: Double
    var altura: CGFloat = 5

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Paleta.warm)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Paleta.douradoClaro)
                    .frame(width: geometria.size.width * max(0.02, fracao))
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
                .stroke(Paleta.douradoClaro, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
            acao("Falar", simbolo: "mic", ligacao: Ligacao.voz)
            acao("Talão", simbolo: "camera", ligacao: Ligacao.talao)
        }
    }

    private func acao(_ titulo: String, simbolo: String?, ligacao: URL) -> some View {
        Link(destination: ligacao) {
            HStack(spacing: 5) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: compacto ? 10 : 11))
                } else {
                    Text("T")
                        .font(.system(size: compacto ? 11 : 12, weight: .medium, design: .serif))
                }
                if !compacto {
                    Text(titulo)
                        .font(Fonte.lume(11, .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(Paleta.dourado)
            .frame(maxWidth: .infinity)
            .frame(height: compacto ? 26 : 30)
            .background(Paleta.areia, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct LinhaDeLimite: View {
    let limite: Limite

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(limite.nome)
                    .font(Fonte.lume(11, .medium))
                    .foregroundStyle(Paleta.tinta)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(inteiro(limite.gasto)) / \(inteiro(limite.orcamento)) €")
                    .font(Fonte.lume(10))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.suave)
            }
            Barra(fracao: limite.fracao, altura: 4)
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
                case .accessoryInline: Text("\(euros(resumo.disponivelDoMes)) · \(euros(resumo.porDia))/dia")
                default: pequeno(resumo)
                }
            } else {
                vazio
            }
        }
        .containerBackground(Paleta.fundo, for: .widget)
    }

    // MARK: Ecrã inicial

    private func pequeno(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AINDA DISPONÍVEIS")
                .font(Fonte.lume(9, .semibold))
                .foregroundStyle(Paleta.dourado)
            Text(euros(resumo.disponivelDoMes))
                .font(Fonte.lume(24, .medium))
                .monospacedDigit()
                .foregroundStyle(Paleta.tinta)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .padding(.top, 2)

            Spacer(minLength: 6)

            Barra(fracao: resumo.fracaoUsada)
            HStack(spacing: 4) {
                Text("\(resumo.percentagemUsada)% usado")
                    .font(Fonte.lume(9))
                    .foregroundStyle(Paleta.suave)
                Spacer(minLength: 0)
                Text(resumo.dentroDoLimite ? "no ritmo" : "acima")
                    .font(Fonte.lume(9, .medium))
                    .foregroundStyle(resumo.dentroDoLimite ? Paleta.positivo : Paleta.dourado)
            }
            .padding(.top, 5)

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Por dia")
                        .font(Fonte.lume(9))
                        .foregroundStyle(Paleta.suave)
                    Text(euros(resumo.porDia))
                        .font(Fonte.lume(14, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Paleta.tinta)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Hoje")
                        .font(Fonte.lume(9))
                        .foregroundStyle(Paleta.suave)
                    Text(euros(resumo.gastoDeHoje))
                        .font(Fonte.lume(14, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Paleta.tinta)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(Ligacao.resumo)
    }

    private func medio(_ resumo: Resumo) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("AINDA DISPONÍVEIS")
                    .font(Fonte.lume(9, .semibold))
                    .foregroundStyle(Paleta.dourado)
                Text(euros(resumo.disponivelDoMes))
                    .font(Fonte.lume(26, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("de \(euros(resumo.rendimento)) · \(resumo.diasRestantes) \(resumo.diasRestantes == 1 ? "dia" : "dias")")
                    .font(Fonte.lume(9))
                    .foregroundStyle(Paleta.suave)
                    .padding(.top, 1)

                Spacer(minLength: 6)
                Barra(fracao: resumo.fracaoUsada)
                Spacer(minLength: 8)

                // À largura do médio, os rótulos não cabem: ficam os ícones.
                AcoesDeRegisto(compacto: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("POR DIA")
                    .font(Fonte.lume(9, .semibold))
                    .foregroundStyle(Paleta.suave)
                Text(euros(resumo.porDia))
                    .font(Fonte.lume(18, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Ritmo(pontos: resumo.acumulado, orcamento: resumo.rendimento)
                    .frame(height: 30)
                    .padding(.top, 2)

                Text(resumo.dentroDoLimite ? "Dentro do limite" : "Acima do ritmo")
                    .font(Fonte.lume(10, .medium))
                    .foregroundStyle(resumo.dentroDoLimite ? Paleta.positivo : Paleta.dourado)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .frame(width: 118)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func grande(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Link(destination: Ligacao.resumo) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("AINDA DISPONÍVEIS")
                            .font(Fonte.lume(9, .semibold))
                            .foregroundStyle(Paleta.dourado)
                        Spacer()
                        Text(resumo.dentroDoLimite ? "Dentro do limite" : "Acima do ritmo")
                            .font(Fonte.lume(10, .medium))
                            .foregroundStyle(resumo.dentroDoLimite ? Paleta.positivo : Paleta.dourado)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(euros(resumo.disponivelDoMes))
                            .font(Fonte.lume(32, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Paleta.tinta)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Ritmo(pontos: resumo.acumulado, orcamento: resumo.rendimento)
                            .frame(width: 110, height: 28)
                    }
                    .padding(.top, 2)
                    Text("\(euros(resumo.gastoDoMes)) gastos de \(euros(resumo.rendimento)) · por dia \(euros(resumo.porDia))")
                        .font(Fonte.lume(10))
                        .foregroundStyle(Paleta.suave)
                        .padding(.top, 2)
                    Barra(fracao: resumo.fracaoUsada)
                        .padding(.top, 7)
                }
            }

            if !resumo.limites.isEmpty {
                Divider().overlay(Paleta.separador).padding(.vertical, 10)
                Link(destination: Ligacao.planear) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(resumo.limites.prefix(3), id: \.nome) { limite in
                            LinhaDeLimite(limite: limite)
                        }
                    }
                }
            }

            if !resumo.movimentos.isEmpty {
                Divider().overlay(Paleta.separador).padding(.vertical, 10)
                Link(destination: Ligacao.movimentos) {
                    VStack(spacing: 6) {
                        ForEach(resumo.movimentos.prefix(3), id: \.titulo) { movimento in
                            HStack(spacing: 8) {
                                Text(iniciais(de: movimento.titulo))
                                    .font(Fonte.lume(9, .semibold))
                                    .foregroundStyle(Paleta.dourado)
                                    .frame(width: 26, height: 26)
                                    .background(Paleta.warm, in: RoundedRectangle(cornerRadius: 9))
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
                                Text((movimento.receita ? "+" : "−") + euros(movimento.valor))
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
        Gauge(value: resumo.fracaoUsada) {
            Image(systemName: "eurosign")
        } currentValueLabel: {
            Text(inteiro(resumo.disponivelDoMes))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(Ligacao.resumo)
    }

    private func retangular(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("AINDA DISPONÍVEIS")
                .font(.system(size: 10, weight: .semibold))
            Text(euros(resumo.disponivelDoMes))
                .font(.system(size: 18, weight: .medium))
                .monospacedDigit()
            Text("Por dia \(euros(resumo.porDia)) · \(resumo.diasRestantes) \(resumo.diasRestantes == 1 ? "dia" : "dias")")
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(Ligacao.resumo)
    }

    private var vazio: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("LUME")
                .font(Fonte.lume(9, .semibold))
                .foregroundStyle(Paleta.dourado)
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
                    Text("OS TEUS LIMITES")
                        .font(Fonte.lume(9, .semibold))
                        .foregroundStyle(Paleta.dourado)
                    ForEach(resumo.limites.prefix(familia == .systemSmall ? 2 : 3), id: \.nome) { limite in
                        LinhaDeLimite(limite: limite)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(Ligacao.planear)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OS TEUS LIMITES")
                        .font(Fonte.lume(9, .semibold))
                        .foregroundStyle(Paleta.dourado)
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
