import SwiftUI
import WidgetKit

// A paleta da Lume, replicada aqui — o widget não partilha código com a app.
private enum Paleta {
    static let fundo = Color(red: 1, green: 1, blue: 1)
    static let tinta = Color(red: 0x30 / 255, green: 0x2B / 255, blue: 0x24 / 255)
    static let suave = Color(red: 0x7B / 255, green: 0x73 / 255, blue: 0x67 / 255)
    static let dourado = Color(red: 0x8E / 255, green: 0x64 / 255, blue: 0x1F / 255)
    static let douradoClaro = Color(red: 0xE8 / 255, green: 0xCD / 255, blue: 0x91 / 255)
    static let warm = Color(red: 0xF0 / 255, green: 0xEB / 255, blue: 0xE1 / 255)
}

/// Espelho de `PartilhaComWidget.Resumo` — mesmas chaves do App Group.
private struct Resumo: Codable {
    var disponivelDoMes: Decimal
    var porDia: Decimal
    var diasRestantes: Int
    var gastoDoMes: Decimal
    var rendimento: Decimal
    var atualizadoEm: Date

    static func doGrupo() -> Resumo? {
        guard let defaults = UserDefaults(suiteName: "group.com.aurea.lume"),
              let dados = defaults.data(forKey: "resumoDoDia") else { return nil }
        return try? JSONDecoder().decode(Resumo.self, from: dados)
    }
}

private func euros(_ valor: Decimal) -> String {
    valor.formatted(.currency(code: "EUR").locale(Locale(identifier: "pt_PT")))
}

// MARK: - Timeline

private struct EntradaDoDia: TimelineEntry {
    let date: Date
    let resumo: Resumo?
}

private struct Fornecedor: TimelineProvider {
    func placeholder(in context: Context) -> EntradaDoDia {
        EntradaDoDia(date: .now, resumo: .init(
            disponivelDoMes: 357.10, porDia: 59.52, diasRestantes: 6,
            gastoDoMes: 1092.90, rendimento: 1450, atualizadoEm: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaDoDia) -> Void) {
        completion(EntradaDoDia(date: .now, resumo: Resumo.doGrupo() ?? placeholder(in: context).resumo))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaDoDia>) -> Void) {
        let entrada = EntradaDoDia(date: .now, resumo: Resumo.doGrupo())
        // Renova à meia-noite — o "por dia" muda de dia para dia.
        let meiaNoite = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        completion(Timeline(entries: [entrada], policy: .after(meiaNoite)))
    }
}

// MARK: - Vistas

private struct VistaDoWidget: View {
    @Environment(\.widgetFamily) private var familia
    let entrada: EntradaDoDia

    var body: some View {
        Group {
            if let resumo = entrada.resumo {
                switch familia {
                case .systemMedium: medio(resumo)
                default: pequeno(resumo)
                }
            } else {
                vazio
            }
        }
        .containerBackground(Paleta.fundo, for: .widget)
    }

    private func pequeno(_ resumo: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AINDA DISPONÍVEIS")
                .font(.custom("Instrument Sans", size: 9).weight(.semibold))
                .foregroundStyle(Paleta.dourado)
            Text(euros(resumo.disponivelDoMes))
                .font(.custom("Instrument Sans", size: 22).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Paleta.tinta)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            barra(resumo)
            Text("Por dia · \(resumo.diasRestantes) \(resumo.diasRestantes == 1 ? "dia" : "dias")")
                .font(.custom("Instrument Sans", size: 10))
                .foregroundStyle(Paleta.suave)
            Text(euros(resumo.porDia))
                .font(.custom("Instrument Sans", size: 14).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Paleta.tinta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medio(_ resumo: Resumo) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AINDA DISPONÍVEIS")
                    .font(.custom("Instrument Sans", size: 10).weight(.semibold))
                    .foregroundStyle(Paleta.dourado)
                Text(euros(resumo.disponivelDoMes))
                    .font(.custom("Instrument Sans", size: 28).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
                Spacer(minLength: 0)
                barra(resumo)
                Text("\(euros(resumo.gastoDoMes)) gastos de \(euros(resumo.rendimento))")
                    .font(.custom("Instrument Sans", size: 10))
                    .foregroundStyle(Paleta.suave)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("POR DIA")
                    .font(.custom("Instrument Sans", size: 10).weight(.semibold))
                    .foregroundStyle(Paleta.suave)
                Text(euros(resumo.porDia))
                    .font(.custom("Instrument Sans", size: 20).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
                Text("\(resumo.diasRestantes) \(resumo.diasRestantes == 1 ? "dia" : "dias") até ao fim do mês")
                    .font(.custom("Instrument Sans", size: 10))
                    .foregroundStyle(Paleta.suave)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barra(_ resumo: Resumo) -> some View {
        let fracao: Double = {
            guard resumo.rendimento > .zero else { return 0 }
            return min(1, ((resumo.gastoDoMes / resumo.rendimento) as NSDecimalNumber).doubleValue)
        }()
        return GeometryReader { geometria in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Paleta.warm)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Paleta.douradoClaro)
                    .frame(width: geometria.size.width * fracao)
            }
        }
        .frame(height: 5)
    }

    private var vazio: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LUME")
                .font(.custom("Instrument Sans", size: 9).weight(.semibold))
                .foregroundStyle(Paleta.dourado)
            Text("Abre a app para veres o teu mês.")
                .font(.custom("Instrument Sans", size: 12))
                .foregroundStyle(Paleta.suave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LumeWidget: Widget {
    let kind: String = "LumeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Fornecedor()) { entrada in
            VistaDoWidget(entrada: entrada)
        }
        .configurationDisplayName("O teu mês")
        .description("O que ainda podes gastar, sem abrir a app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    LumeWidget()
} timeline: {
    EntradaDoDia(date: .now, resumo: .init(
        disponivelDoMes: 357.10, porDia: 59.52, diasRestantes: 6,
        gastoDoMes: 1092.90, rendimento: 1450, atualizadoEm: .now
    ))
}
