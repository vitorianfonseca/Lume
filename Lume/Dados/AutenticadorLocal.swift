import Foundation
import LocalAuthentication

/// Pede Face ID, Touch ID ou o código do iPhone para desbloquear a Lume.
/// Fica isolado da UI: devolve sucesso ou uma frase em português, nunca o
/// erro técnico do sistema.
@MainActor
enum AutenticadorLocal {
    enum Resultado {
        case sucesso
        /// Mensagem vazia quando a pessoa cancelou — não é um erro a mostrar.
        case falhou(String)
    }

    static func autenticar() async -> Resultado {
        let contexto = LAContext()
        var erro: NSError?
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &erro) else {
            return .falhou("Este iPhone não tem Face ID, Touch ID nem código configurado.")
        }
        do {
            let sucesso = try await contexto.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Desbloquear a Lume"
            )
            return sucesso ? .sucesso : .falhou("Não foi possível confirmar quem és.")
        } catch let erroDeAutenticacao as LAError where erroDeAutenticacao.code == .userCancel {
            return .falhou("")
        } catch {
            return .falhou("Não foi possível confirmar quem és. Toca para tentar outra vez.")
        }
    }
}
