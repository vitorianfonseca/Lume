import Foundation
import SwiftData

/// Cada vez que se reforça um objetivo, para se poder ver o percurso
/// (quando e quanto) e não só o total acumulado em `Meta.valorPoupado`.
@Model
final class ReforcoDaMeta {
    var valor: Decimal = Decimal.zero
    var data: Date = Date.now

    var meta: Meta?

    init(valor: Decimal, data: Date = .now, meta: Meta? = nil) {
        self.valor = valor
        self.data = data
        self.meta = meta
    }
}
