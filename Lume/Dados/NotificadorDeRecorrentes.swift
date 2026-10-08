import Foundation
import UserNotifications

/// Lembra as contas fixas na véspera, às 9 da manhã, e o fim da fidelização
/// 30 dias antes. Reagenda tudo do zero a cada alteração — simples e
/// sempre coerente.
@MainActor
enum NotificadorDeRecorrentes {
    private static let prefixo = "recorrente-"
    private static let prefixoDeFidelizacao = "fidelizacao-"

    static func agendar(_ recorrentes: [Recorrente]) async {
        let centro = UNUserNotificationCenter.current()
        let autorizado = (try? await centro.requestAuthorization(options: [.alert, .sound])) ?? false
        guard autorizado else { return }

        let pendentes = await centro.pendingNotificationRequests()
        centro.removePendingNotificationRequests(
            withIdentifiers: pendentes.map(\.identifier).filter {
                $0.hasPrefix(prefixo) || $0.hasPrefix(prefixoDeFidelizacao)
            }
        )

        let calendario = Calendar.current
        for recorrente in recorrentes where recorrente.ativa {
            let vencimento = AgendaDeRecorrentes.proximaOcorrencia(
                diaDoMes: recorrente.diaDoMes, aPartirDe: .now
            )
            if let vespera = calendario.date(byAdding: .day, value: -1, to: vencimento) {
                var componentes = calendario.dateComponents([.year, .month, .day], from: vespera)
                componentes.hour = 9
                if let disparo = calendario.date(from: componentes), disparo > .now {
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

            if let fim = recorrente.fimDaFidelizacao,
               let aviso = calendario.date(byAdding: .day, value: -30, to: fim),
               aviso > .now {
                var componentes = calendario.dateComponents([.year, .month, .day], from: aviso)
                componentes.hour = 9
                let conteudo = UNMutableNotificationContent()
                conteudo.title = "Fidelização a acabar"
                let dataPorExtenso = fim.formatted(.dateTime.day().month(.wide).locale(FormatadorDeMoeda.localidade))
                conteudo.body = "A fidelização de \(recorrente.nome) acaba a \(dataPorExtenso) — é a altura de negociar ou mudar."
                conteudo.sound = .default
                let pedido = UNNotificationRequest(
                    identifier: "\(prefixoDeFidelizacao)\(recorrente.nome)",
                    content: conteudo,
                    trigger: UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
                )
                try? await centro.add(pedido)
            }
        }
    }

    /// Chamado assim que um pagamento novo liga a uma recorrente e o valor
    /// é mais alto do que o anterior — avisa logo, sem esperar pela véspera.
    static func avisarSubida(_ recorrente: Recorrente, subida: AnaliseDeRecorrentes.Subida) async {
        let centro = UNUserNotificationCenter.current()
        guard (try? await centro.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "\(recorrente.nome) ficou mais cara"
        let percentagem = Int((subida.fracao * 100).rounded())
        conteudo.body = "Subiu \(FormatadorDeMoeda.texto(subida.diferenca)) (+\(percentagem)%), para \(FormatadorDeMoeda.texto(subida.valorDepois))."
        conteudo.sound = .default
        try? await centro.add(UNNotificationRequest(identifier: UUID().uuidString, content: conteudo, trigger: nil))
    }
}
