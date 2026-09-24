import Foundation
import SwiftData

/// Rendimento esperado e poupança planeada para um mês concreto.
/// Sem `@Attribute(.unique)` (o CloudKit não o suporta), pelo que a unicidade
/// de (ano, mês) é garantida por quem cria: procurar antes de inserir.
@Model
final class DefinicoesDoMes {
    var ano: Int = 0
    var mes: Int = 0
    var rendimentoEsperado: Decimal = Decimal.zero
    var poupancaPlaneada: Decimal = Decimal.zero

    init(ano: Int, mes: Int, rendimentoEsperado: Decimal = .zero, poupancaPlaneada: Decimal = .zero) {
        self.ano = ano
        self.mes = mes
        self.rendimentoEsperado = rendimentoEsperado
        self.poupancaPlaneada = poupancaPlaneada
    }
}
