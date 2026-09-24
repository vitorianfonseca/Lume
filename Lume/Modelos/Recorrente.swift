import Foundation
import SwiftData

/// Conta fixa ou subscrição que se repete todos os meses (renda, EDP, Netflix…).
@Model
final class Recorrente {
    var nome: String = ""
    var valor: Decimal = Decimal.zero
    var diaDoMes: Int = 1
    var ativa: Bool = true
    var ultimoPagamentoEm: Date?

    var categoria: Categoria?

    @Relationship(deleteRule: .nullify, inverse: \Transacao.recorrente)
    var pagamentos: [Transacao]?

    init(
        nome: String,
        valor: Decimal,
        diaDoMes: Int,
        categoria: Categoria? = nil,
        ativa: Bool = true,
        ultimoPagamentoEm: Date? = nil
    ) {
        self.nome = nome
        self.valor = valor
        self.diaDoMes = diaDoMes
        self.categoria = categoria
        self.ativa = ativa
        self.ultimoPagamentoEm = ultimoPagamentoEm
    }
}
