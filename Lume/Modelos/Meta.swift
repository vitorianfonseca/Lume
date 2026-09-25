import Foundation
// Objetivo de poupança do novo design: além do nome e dos valores,
// guarda uma descrição curta e um prazo opcionais.
import SwiftData

@Model
final class Meta {
    var nome: String = ""
    /// Frase curta sob o nome ("Segurança para os imprevistos").
    var descricao: String?
    var valorAlvo: Decimal = Decimal.zero
    var valorPoupado: Decimal = Decimal.zero
    var dataLimite: Date?
    var simbolo: String = "target"

    init(
        nome: String,
        descricao: String? = nil,
        valorAlvo: Decimal,
        valorPoupado: Decimal = .zero,
        dataLimite: Date? = nil,
        simbolo: String = "target"
    ) {
        self.nome = nome
        self.descricao = descricao
        self.valorAlvo = valorAlvo
        self.valorPoupado = valorPoupado
        self.dataLimite = dataLimite
        self.simbolo = simbolo
    }
}
