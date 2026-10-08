import Foundation
import SwiftData

/// A relação entre o nome de um cartão da Carteira (o que vem da automação
/// "Transação" dos Atalhos, ex. "Revolut Mastercard") e a conta da Lume a
/// que corresponde — para só perguntar uma vez por cartão.
@Model
final class CartaoDaCarteira {
    var nomeDoCartao: String = ""
    var conta: Conta?

    init(nomeDoCartao: String, conta: Conta? = nil) {
        self.nomeDoCartao = nomeDoCartao
        self.conta = conta
    }
}
