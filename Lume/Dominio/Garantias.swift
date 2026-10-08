import Foundation

/// A matemática das garantias: quando sugerir guardar uma, quando acaba e
/// quando está a aproximar-se do fim — sem SwiftData aqui.
nonisolated enum Garantias {
    static func deveSugerir(
        categoriaNome: String?,
        valor: Decimal,
        valorMinimo: Decimal,
        categoriasSugeridas: [String]
    ) -> Bool {
        guard valor >= valorMinimo, let categoriaNome else { return false }
        return categoriasSugeridas.contains {
            $0.compare(categoriaNome, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    static func dataFim(dataDaCompra: Date, duracaoEmMeses: Int, calendario: Calendar = .current) -> Date {
        calendario.date(byAdding: .month, value: duracaoEmMeses, to: dataDaCompra) ?? dataDaCompra
    }

    static func expirada(dataFim: Date, agora: Date = .now) -> Bool {
        dataFim < agora
    }

    /// Verdadeiro desde 30 dias antes do fim (por defeito) até ao próprio fim.
    static func aAproximarSeDoFim(
        dataFim: Date,
        agora: Date = .now,
        diasDeAviso: Int = 30,
        calendario: Calendar = .current
    ) -> Bool {
        guard !expirada(dataFim: dataFim, agora: agora) else { return false }
        guard let aviso = calendario.date(byAdding: .day, value: -diasDeAviso, to: dataFim) else { return false }
        return agora >= aviso
    }
}
