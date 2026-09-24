import Foundation

/// Converte datas relativas ("hoje", "ontem") ou explícitas em `Date`.
/// É sempre código Swift a resolver datas — nunca o modelo de linguagem.
nonisolated enum ResolutorDeDatas {
    static func resolver(
        _ texto: String,
        emRelacaoA hoje: Date,
        calendario: Calendar = .current
    ) -> Date {
        let limpo = texto.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch limpo {
        case "", "hoje":
            return hoje
        case "ontem":
            return recuar(1, desde: hoje, calendario: calendario)
        case "anteontem":
            return recuar(2, desde: hoje, calendario: calendario)
        default:
            break
        }

        // "AAAA-MM-DD" (o formato pedido ao modelo para datas explícitas)
        if let correspondencia = limpo.firstMatch(of: /^(\d{4})-(\d{1,2})-(\d{1,2})$/) {
            return data(
                ano: Int(correspondencia.1),
                mes: Int(correspondencia.2),
                dia: Int(correspondencia.3),
                calendario: calendario
            ) ?? hoje
        }

        // "DD/MM" ou "DD/MM/AAAA", como se escreve em Portugal
        if let correspondencia = limpo.firstMatch(of: /^(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?$/) {
            let ano = correspondencia.3.flatMap { Int($0) }
                ?? calendario.component(.year, from: hoje)
            return data(
                ano: ano,
                mes: Int(correspondencia.2),
                dia: Int(correspondencia.1),
                calendario: calendario
            ) ?? hoje
        }

        return hoje
    }

    private static func recuar(_ dias: Int, desde data: Date, calendario: Calendar) -> Date {
        calendario.date(byAdding: .day, value: -dias, to: data) ?? data
    }

    private static func data(ano: Int?, mes: Int?, dia: Int?, calendario: Calendar) -> Date? {
        // Meio-dia para o dia não mudar com fusos horários ou hora de verão.
        let componentes = DateComponents(year: ano, month: mes, day: dia, hour: 12)
        guard let data = calendario.date(from: componentes),
              calendario.component(.day, from: data) == dia else {
            return nil  // rejeita datas impossíveis (ex.: 31/02)
        }
        return data
    }
}
