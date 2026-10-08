import Foundation
import SwiftData

/// Guarda os nomes de comerciantes que a pessoa disse "não, obrigado" numa
/// sugestão de nova recorrente — para a Lume nunca voltar a insistir.
@Model
final class SugestaoDeRecorrenteIgnorada {
    var nome: String = ""

    init(nome: String) {
        self.nome = nome
    }
}
