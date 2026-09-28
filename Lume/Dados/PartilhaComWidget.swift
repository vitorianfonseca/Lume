import Foundation
import SwiftData
import WidgetKit

/// A app publica o retrato do mês no App Group; o widget só lê e desenha.
/// O widget tem um espelho desta estrutura (mesmas chaves) — daí o `versao`,
/// para uma app nova nunca partir um widget antigo.
nonisolated enum PartilhaComWidget {
    static let grupo = "group.com.aurea.lume"
    static let chave = "resumoDoDia"

    struct Limite: Codable {
        var nome: String
        var gasto: Decimal
        var orcamento: Decimal
    }

    struct Movimento: Codable {
        var titulo: String
        var detalhe: String
        var valor: Decimal
        var receita: Bool
    }

    struct Resumo: Codable {
        var versao = 2
        /// Números do mês.
        var disponivelDoMes: Decimal
        var porDia: Decimal
        var diasRestantes: Int
        var gastoDoMes: Decimal
        var rendimento: Decimal
        /// Hoje.
        var gastoDeHoje: Decimal
        var disponivelHoje: Decimal
        /// Ritmo: gasto acumulado por dia do mês, para o gráfico.
        var acumulado: [Double]
        var dentroDoLimite: Bool
        /// Contexto.
        var limites: [Limite]
        var movimentos: [Movimento]
        var atualizadoEm: Date
    }

    static func publicar(_ resumo: Resumo) {
        guard let defaults = UserDefaults(suiteName: grupo),
              let dados = try? JSONEncoder().encode(resumo) else { return }
        defaults.set(dados, forKey: chave)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// A tipografia da marca também tem de existir dentro do widget, que é
    /// outro processo: a app deixa o ficheiro no contentor partilhado e o
    /// widget regista-o. Assim o Instrument Sans é o mesmo nos dois lados.
    static func partilharFonte() {
        let gestor = FileManager.default
        guard let destino = gestor
            .containerURL(forSecurityApplicationGroupIdentifier: grupo)?
            .appending(path: "InstrumentSans.ttf"),
              !gestor.fileExists(atPath: destino.path),
              let origem = Bundle.main.url(forResource: "InstrumentSans", withExtension: "ttf")
        else { return }
        try? gestor.copyItem(at: origem, to: destino)
    }
}

// MARK: - Construção do retrato

@MainActor
extension PartilhaComWidget {
    /// Junta tudo o que o widget mostra a partir dos dados da app.
    /// As contas são as mesmas da `CalculadoraDoDia` — nada é recalculado
    /// de forma diferente aqui.
    static func retrato(
        dia: CalculadoraDoDia.Dia,
        transacoes: [Transacao],
        categorias: [Categoria],
        rendimento: Decimal,
        hoje: Date = .now
    ) -> Resumo {
        let calendario = Calendar.current
        let despesasDoMes = transacoes.filter {
            $0.tipo == .despesa && calendario.isDate($0.data, equalTo: hoje, toGranularity: .month)
        }
        let gastoDoMes = despesasDoMes.reduce(Decimal.zero) { $0 + $1.valor }
        let gastoDeHoje = despesasDoMes
            .filter { calendario.isDate($0.data, inSameDayAs: hoje) }
            .reduce(Decimal.zero) { $0 + $1.valor }

        // Acumulado dia a dia, para a linha do ritmo.
        let diaAtual = calendario.component(.day, from: hoje)
        var corrida = Decimal.zero
        let acumulado: [Double] = (1...max(diaAtual, 1)).map { numeroDoDia in
            corrida += despesasDoMes
                .filter { calendario.component(.day, from: $0.data) == numeroDoDia }
                .reduce(Decimal.zero) { $0 + $1.valor }
            return (corrida as NSDecimalNumber).doubleValue
        }

        // Dentro do limite = abaixo do ritmo constante do orçamento.
        let diasNoMes = calendario.range(of: .day, in: .month, for: hoje)?.count ?? 30
        let ritmoIdeal = (rendimento as NSDecimalNumber).doubleValue
            * Double(diaAtual) / Double(diasNoMes)
        let dentroDoLimite = (gastoDoMes as NSDecimalNumber).doubleValue <= ritmoIdeal

        // Os limites mais apertados primeiro — é o que interessa ver de fora.
        let limites = categorias
            .compactMap { categoria -> (Limite, Double)? in
                guard let orcamento = categoria.orcamentoMensal, orcamento > .zero else { return nil }
                let gasto = despesasDoMes
                    .filter { $0.categoria?.persistentModelID == categoria.persistentModelID }
                    .reduce(Decimal.zero) { $0 + $1.valor }
                let fracao = (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
                return (Limite(nome: categoria.nome, gasto: gasto, orcamento: orcamento), fracao)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)

        let movimentos = transacoes
            .sorted { $0.data > $1.data }
            .prefix(3)
            .map { transacao in
                Movimento(
                    titulo: transacao.loja ?? transacao.descricao,
                    detalhe: transacao.categoria?.nome ?? "Sem categoria",
                    valor: transacao.valor,
                    receita: transacao.tipo == .receita
                )
            }

        return Resumo(
            disponivelDoMes: dia.disponivelDoMes,
            porDia: dia.diasRestantes > 0
                ? (dia.disponivelDoMes / Decimal(dia.diasRestantes)).arredondadoACentimos()
                : dia.disponivelDoMes,
            diasRestantes: dia.diasRestantes,
            gastoDoMes: gastoDoMes,
            rendimento: rendimento,
            gastoDeHoje: gastoDeHoje,
            disponivelHoje: dia.hojePodesGastar,
            acumulado: acumulado,
            dentroDoLimite: dentroDoLimite,
            limites: Array(limites),
            movimentos: Array(movimentos),
            atualizadoEm: .now
        )
    }
}
