import Foundation
import SwiftData

@Model
final class Meta {
    var nome: String = ""
    var valorAlvo: Decimal = Decimal.zero
    var valorPoupado: Decimal = Decimal.zero
    var dataLimite: Date?
    var simbolo: String = "target"

    init(
        nome: String,
        valorAlvo: Decimal,
        valorPoupado: Decimal = .zero,
        dataLimite: Date? = nil,
        simbolo: String = "target"
    ) {
        self.nome = nome
        self.valorAlvo = valorAlvo
        self.valorPoupado = valorPoupado
        self.dataLimite = dataLimite
        self.simbolo = simbolo
    }
}
