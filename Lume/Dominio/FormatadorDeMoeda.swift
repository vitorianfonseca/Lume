import Foundation

/// Formatação monetária em EUR com convenções portuguesas ("1 092,90 €").
nonisolated enum FormatadorDeMoeda {
    static let localidade = Locale(identifier: "pt_PT")

    static func texto(_ valor: Decimal) -> String {
        valor.formatted(.currency(code: "EUR").locale(localidade))
    }

    /// Valor sempre positivo, para frases como "Hoje já passaste 6,20 €".
    static func textoAbsoluto(_ valor: Decimal) -> String {
        texto(valor < .zero ? -valor : valor)
    }
}
