import Foundation
import UserNotifications

/// Avisa no dia 1 de cada mês, às 10h, que o fecho do mês anterior está
/// pronto. Reagenda-se do zero a cada arranque da app — como as contas
/// fixas — para o nome do mês no texto estar sempre certo.
@MainActor
enum NotificadorDoFecho {
    private static let identificador = "fecho-do-mes"

    static func agendar(hoje: Date = .now) async {
        let centro = UNUserNotificationCenter.current()
        let autorizado = (try? await centro.requestAuthorization(options: [.alert, .sound])) ?? false
        guard autorizado else { return }

        centro.removePendingNotificationRequests(withIdentifiers: [identificador])

        let calendario = Calendar.current
        var componentes = calendario.dateComponents([.year, .month], from: hoje)
        componentes.day = 1
        componentes.hour = 10
        guard var disparo = calendario.date(from: componentes) else { return }
        if disparo <= hoje {
            guard let proximoMes = calendario.date(byAdding: .month, value: 1, to: disparo) else { return }
            disparo = proximoMes
        }

        // O mês que fecha é o anterior ao do disparo.
        guard let mesQueFechou = calendario.date(byAdding: .month, value: -1, to: disparo) else { return }
        let nomeDoMes = mesQueFechou.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade))

        let conteudo = UNMutableNotificationContent()
        conteudo.title = "O teu resumo está pronto"
        conteudo.body = "O teu \(nomeDoMes) está pronto — gastos, categorias e objetivos."
        conteudo.sound = .default

        let disparoComponentes = calendario.dateComponents([.year, .month, .day, .hour], from: disparo)
        let pedido = UNNotificationRequest(
            identifier: identificador,
            content: conteudo,
            trigger: UNCalendarNotificationTrigger(dateMatching: disparoComponentes, repeats: false)
        )
        try? await centro.add(pedido)
    }
}
