import Foundation

/// As regras do código de 4 dígitos do bloqueio — alternativa ou reserva
/// ao Face ID, para quando a cara não é reconhecida ou a pessoa prefere
/// mesmo um código.
nonisolated enum CodigoDeBloqueio {
    static let comprimento = 4

    static func valido(_ codigo: String) -> Bool {
        codigo.count == comprimento && codigo.allSatisfy(\.isNumber)
    }
}
