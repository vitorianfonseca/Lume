import Foundation
import SwiftData

@Model
final class Categoria {
    var nome: String = ""
    var simbolo: String = "tag"
    /// Cor em hexadecimal ("C9A45A"). A conversão para `Color` vive na camada de interface,
    /// para manter os modelos sem dependência de SwiftUI.
    var corHex: String = "8A8A85"
    var orcamentoMensal: Decimal?
    var ordem: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Transacao.categoria)
    var transacoes: [Transacao]?

    @Relationship(deleteRule: .nullify, inverse: \Recorrente.categoria)
    var recorrentes: [Recorrente]?

    init(
        nome: String,
        simbolo: String,
        corHex: String,
        orcamentoMensal: Decimal? = nil,
        ordem: Int = 0
    ) {
        self.nome = nome
        self.simbolo = simbolo
        self.corHex = corHex
        self.orcamentoMensal = orcamentoMensal
        self.ordem = ordem
    }
}
