import Foundation

/// Cálculo puro da próxima ocorrência de uma conta fixa.
nonisolated enum AgendaDeRecorrentes {
    /// A próxima data (hoje incluído) em que vence uma recorrente com este dia
    /// do mês. Dias que não existem no mês (31 em fevereiro) caem no último dia.
    static func proximaOcorrencia(
        diaDoMes: Int,
        aPartirDe hoje: Date,
        calendario: Calendar = .current
    ) -> Date {
        let inicioDeHoje = calendario.startOfDay(for: hoje)
        if let esteMes = data(diaDoMes: diaDoMes, noMesDe: inicioDeHoje, calendario: calendario),
           esteMes >= inicioDeHoje {
            return esteMes
        }
        let mesSeguinte = calendario.date(byAdding: .month, value: 1, to: inicioDeHoje) ?? inicioDeHoje
        return data(diaDoMes: diaDoMes, noMesDe: mesSeguinte, calendario: calendario) ?? inicioDeHoje
    }

    private static func data(diaDoMes: Int, noMesDe referencia: Date, calendario: Calendar) -> Date? {
        var componentes = calendario.dateComponents([.year, .month], from: referencia)
        let diasNoMes = calendario.range(of: .day, in: .month, for: referencia)?.count ?? 28
        componentes.day = min(diaDoMes, diasNoMes)
        return calendario.date(from: componentes)
    }
}
