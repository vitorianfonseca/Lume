import Foundation
import UserNotifications

/// Avisa 30 dias antes do fim da garantia, e 2 dias antes do prazo de
/// devolução, se houver. `agendarTodas` reagenda tudo do zero (a cada
/// arranque da app); `agendar` trata só de uma garantia acabada de criar.
@MainActor
enum NotificadorDeGarantias {
    private static let prefixoDeFim = "garantia-fim-"
    private static let prefixoDeDevolucao = "garantia-devolucao-"

    static func agendarTodas(_ garantias: [Garantia]) async {
        let centro = UNUserNotificationCenter.current()
        guard (try? await centro.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let pendentes = await centro.pendingNotificationRequests()
        centro.removePendingNotificationRequests(
            withIdentifiers: pendentes.map(\.identifier).filter {
                $0.hasPrefix(prefixoDeFim) || $0.hasPrefix(prefixoDeDevolucao)
            }
        )
        for garantia in garantias where !garantia.expirada {
            await agendar(garantia, centro: centro, autorizado: true)
        }
    }

    static func agendar(_ garantia: Garantia) async {
        let centro = UNUserNotificationCenter.current()
        guard (try? await centro.requestAuthorization(options: [.alert, .sound])) == true else { return }
        await agendar(garantia, centro: centro, autorizado: true)
    }

    private static func agendar(_ garantia: Garantia, centro: UNUserNotificationCenter, autorizado: Bool) async {
        let calendario = Calendar.current

        if let aviso = calendario.date(byAdding: .day, value: -30, to: garantia.dataFim), aviso > .now {
            var componentes = calendario.dateComponents([.year, .month, .day], from: aviso)
            componentes.hour = 10
            let conteudo = UNMutableNotificationContent()
            conteudo.title = "Uma garantia a acabar"
            conteudo.body = "A garantia de \(garantia.produto) acaba dentro de 30 dias."
            conteudo.sound = .default
            try? await centro.add(UNNotificationRequest(
                identifier: "\(prefixoDeFim)\(garantia.id.uuidString)",
                content: conteudo,
                trigger: UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
            ))
        }

        if let prazo = garantia.prazoDeDevolucao,
           let aviso = calendario.date(byAdding: .day, value: -2, to: prazo), aviso > .now {
            var componentes = calendario.dateComponents([.year, .month, .day], from: aviso)
            componentes.hour = 10
            let conteudo = UNMutableNotificationContent()
            conteudo.title = "Prazo de devolução a acabar"
            conteudo.body = "Faltam 2 dias para devolveres \(garantia.produto), se precisares."
            conteudo.sound = .default
            try? await centro.add(UNNotificationRequest(
                identifier: "\(prefixoDeDevolucao)\(garantia.id.uuidString)",
                content: conteudo,
                trigger: UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
            ))
        }
    }
}
