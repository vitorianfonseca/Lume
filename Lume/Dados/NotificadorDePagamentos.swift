import Foundation
import SwiftData
import UserNotifications

/// As notificações do registo automático via Apple Pay: confirma o que
/// ficou guardado, avisa quando não há como ler o valor, e permite anular
/// sem abrir a app.
@MainActor
enum NotificadorDePagamentos {
    static let categoriaDePagamento = "pagamento-applePay"
    private static let acaoDeAnular = "anular-pagamento"
    private static let acaoDeMudarCategoria = "mudar-categoria"

    /// Chamado uma vez no arranque da app — regista as ações que aparecem
    /// ao premir continuamente a notificação.
    static func registarCategorias() {
        let anular = UNNotificationAction(
            identifier: acaoDeAnular,
            title: "Anular",
            options: [.destructive]
        )
        let mudarCategoria = UNNotificationAction(
            identifier: acaoDeMudarCategoria,
            title: "Mudar categoria",
            options: [.foreground]
        )
        let categoria = UNNotificationCategory(
            identifier: categoriaDePagamento,
            actions: [mudarCategoria, anular],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([categoria])
    }

    static func avisarRegistado(_ transacao: Transacao) async {
        guard (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "Registado"
        let categoria = transacao.categoria.map { " · \($0.nome)" } ?? ""
        let sinal = transacao.tipo == .receita ? "+" : "−"
        conteudo.body = "\(transacao.loja ?? transacao.descricao) \(sinal)\(FormatadorDeMoeda.texto(transacao.valor))\(categoria)"
        conteudo.sound = .default
        conteudo.categoryIdentifier = categoriaDePagamento
        conteudo.userInfo = [
            "loja": transacao.loja ?? transacao.descricao,
            "valor": NSDecimalNumber(decimal: transacao.valor).stringValue,
        ]
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: conteudo, trigger: nil)
        )
    }

    static func avisarValorIlegivel(comerciante: String) async {
        guard (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "Não consegui ler o valor"
        conteudo.body = "\(comerciante) · toca para registar à mão."
        conteudo.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: conteudo, trigger: nil)
        )
    }

    static func avisarCartaoDesconhecido(nomeDoCartao: String) async {
        guard (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "Novo cartão"
        conteudo.body = "Associa \"\(nomeDoCartao)\" a uma conta em Perfil → Registo automático."
        conteudo.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: conteudo, trigger: nil)
        )
    }
}

/// Trata os toques nas ações da notificação — "Anular" apaga o movimento
/// que acabou de ser criado; "Mudar categoria" só abre a app nos Movimentos,
/// que é onde se edita (sem extensão própria, não há escolha dentro da notificação).
@MainActor
final class GestorDeNotificacoes: NSObject, UNUserNotificationCenterDelegate {
    static let partilhado = GestorDeNotificacoes()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.categoryIdentifier == NotificadorDePagamentos.categoriaDePagamento,
              response.actionIdentifier == "anular-pagamento",
              let loja = response.notification.request.content.userInfo["loja"] as? String,
              let valorTexto = response.notification.request.content.userInfo["valor"] as? String,
              let valor = Decimal(string: valorTexto, locale: Locale(identifier: "en_US_POSIX"))
        else { return }

        let contentor = ContentorDeDados.producao()
        let contexto = contentor.mainContext
        guard let transacoes = try? contexto.fetch(FetchDescriptor<Transacao>(
            sortBy: [SortDescriptor(\.data, order: .reverse)]
        )) else { return }

        // A mais recente com a mesma loja e valor, vinda do Apple Pay.
        guard let alvo = transacoes.first(where: {
            $0.origem == .applePay && $0.loja == loja && $0.valor == valor
        }) else { return }
        contexto.delete(alvo)
        try? contexto.save()
    }
}
