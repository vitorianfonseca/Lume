import Foundation
import UserNotifications

/// Lembra as contas fixas na véspera, às 9 da manhã.
/// Reagenda tudo do zero a cada alteração — simples e sempre coerente.
@MainActor
enum NotificadorDeRecorrentes {
    private static let prefixo = "recorrente-"

    static func agendar(_ recorrentes: [Recorrente]) async {
        let centro = UNUserNotificationCenter.current()
        let autorizado = (try? await centro.requestAuthorization(options: [.alert, .sound])) ?? false
        guard autorizado else { return }

        let pendentes = await centro.pendingNotificationRequests()
        centro.removePendingNotificationRequests(
            withIdentifiers: pendentes.map(\.identifier).filter { $0.hasPrefix(prefixo) }
        )

        let calendario = Calendar.current
        for recorrente in recorrentes where recorrente.ativa {
            let vencimento = AgendaDeRecorrentes.proximaOcorrencia(
                diaDoMes: recorrente.diaDoMes, aPartirDe: .now
            )
            guard let vespera = calendario.date(byAdding: .day, value: -1, to: vencimento) else {
                continue
            }

            var componentes = calendario.dateComponents([.year, .month, .day], from: vespera)
            componentes.hour = 9
            guard let disparo = calendario.date(from: componentes), disparo > .now else {
                continue
            }

            let conteudo = UNMutableNotificationContent()
            conteudo.title = "Conta fixa amanhã"
            conteudo.body = "\(recorrente.nome) · \(FormatadorDeMoeda.texto(recorrente.valor))"
            conteudo.sound = .default

            let pedido = UNNotificationRequest(
                identifier: "\(prefixo)\(recorrente.nome)-\(recorrente.diaDoMes)",
                content: conteudo,
                trigger: UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
            )
            try? await centro.add(pedido)
        }
    }
}
