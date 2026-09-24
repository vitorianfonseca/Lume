import Foundation

/// Toda a matemática do número diário. Sem SwiftUI nem SwiftData:
/// recebe valores, devolve valores. É aqui que "a app faz as contas" —
/// a IA nunca toca nestes números.
///
/// `nonisolated` porque é lógica pura, utilizável em qualquer contexto de
/// concorrência (o projeto usa isolação MainActor por defeito).
nonisolated enum CalculadoraDoDia {

    struct Despesa: Equatable {
        var valor: Decimal
        var data: Date
        /// Pagamentos de recorrentes são excluídos das despesas variáveis,
        /// porque o valor da recorrente já foi descontado ao mês inteiro.
        var ehPagamentoDeRecorrente: Bool

        init(valor: Decimal, data: Date, ehPagamentoDeRecorrente: Bool = false) {
            self.valor = valor
            self.data = data
            self.ehPagamentoDeRecorrente = ehPagamentoDeRecorrente
        }
    }

    struct Entrada {
        var hoje: Date
        var calendario: Calendar = .current
        /// `nil` quando o utilizador ainda não definiu o rendimento do mês.
        var rendimentoEsperado: Decimal?
        var poupancaPlaneada: Decimal = .zero
        /// Valores das recorrentes ativas deste mês.
        var recorrentesAtivas: [Decimal] = []
        /// Despesas do mês corrente; as de outros meses são ignoradas.
        var despesasDoMes: [Despesa] = []
    }

    struct Dia: Equatable {
        var disponivelDoMes: Decimal
        /// Pode ser negativo — a interface mostra-o com calma, sem alarmes.
        var hojePodesGastar: Decimal
        var gastoHoje: Decimal
        /// Dias até ao fim do mês, incluindo hoje.
        var diasRestantes: Int
    }

    enum Resultado: Equatable {
        case semRendimento
        case calculado(Dia)
    }

    static func calcular(_ entrada: Entrada) -> Resultado {
        guard let rendimento = entrada.rendimentoEsperado else {
            return .semRendimento
        }

        let calendario = entrada.calendario
        let inicioDeHoje = calendario.startOfDay(for: entrada.hoje)

        let variaveisDoMes = entrada.despesasDoMes.filter { despesa in
            !despesa.ehPagamentoDeRecorrente
                && calendario.isDate(despesa.data, equalTo: entrada.hoje, toGranularity: .month)
        }
        let gastoAteOntem = variaveisDoMes
            .filter { $0.data < inicioDeHoje }
            .reduce(Decimal.zero) { $0 + $1.valor }
        let gastoHoje = variaveisDoMes
            .filter { calendario.isDate($0.data, inSameDayAs: entrada.hoje) }
            .reduce(Decimal.zero) { $0 + $1.valor }

        let totalRecorrentes = entrada.recorrentesAtivas.reduce(Decimal.zero, +)
        let disponivelDoMes = rendimento
            - entrada.poupancaPlaneada
            - totalRecorrentes
            - gastoAteOntem

        let diasNoMes = calendario.range(of: .day, in: .month, for: entrada.hoje)?.count ?? 30
        let diaAtual = calendario.component(.day, from: entrada.hoje)
        let diasRestantes = diasNoMes - diaAtual + 1

        let porDia = (disponivelDoMes / Decimal(diasRestantes)).arredondadoACentimos()

        return .calculado(Dia(
            disponivelDoMes: disponivelDoMes,
            hojePodesGastar: porDia - gastoHoje,
            gastoHoje: gastoHoje,
            diasRestantes: diasRestantes
        ))
    }
}

nonisolated extension Decimal {
    /// Arredonda a 2 casas decimais (cêntimos), meio-para-cima (`.plain`).
    func arredondadoACentimos() -> Decimal {
        var original = self
        var resultado = Decimal()
        NSDecimalRound(&resultado, &original, 2, .plain)
        return resultado
    }
}
