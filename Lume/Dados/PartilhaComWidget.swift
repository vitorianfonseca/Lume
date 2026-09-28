import Foundation
import WidgetKit

/// A app publica o resumo do dia no App Group; o widget só lê e desenha.
/// (O widget tem um espelho desta estrutura — mesmas chaves, sem partilhar
/// código entre targets.)
nonisolated enum PartilhaComWidget {
    static let grupo = "group.com.aurea.lume"
    static let chave = "resumoDoDia"

    struct Resumo: Codable {
        var disponivelDoMes: Decimal
        var porDia: Decimal
        var diasRestantes: Int
        var gastoDoMes: Decimal
        var rendimento: Decimal
        var atualizadoEm: Date
    }

    static func publicar(_ resumo: Resumo) {
        guard let defaults = UserDefaults(suiteName: grupo),
              let dados = try? JSONEncoder().encode(resumo) else { return }
        defaults.set(dados, forKey: chave)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
