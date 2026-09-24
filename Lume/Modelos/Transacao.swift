import Foundation
import SwiftData

/// Guardado como `String` (raw value) porque o CloudKit não sincroniza enums diretamente.
/// `nonisolated`: tipo de valor puro, utilizável em qualquer contexto de concorrência.
nonisolated enum TipoTransacao: String, Codable, CaseIterable {
    case despesa
    case receita
}

/// Como a transação entrou na app. `voz` e `talao` ficam reservados para fases futuras.
nonisolated enum OrigemTransacao: String, Codable, CaseIterable {
    case manual
    case texto
    case voz
    case talao
}

@Model
final class Transacao {
    // Todas as propriedades têm valor por defeito ou são opcionais,
    // e as relações são opcionais — requisitos do CloudKit.
    var valor: Decimal = Decimal.zero
    var tipoRaw: String = TipoTransacao.despesa.rawValue
    var descricao: String = ""
    var loja: String?
    var data: Date = Date.now
    var nota: String?
    var criadaEm: Date = Date.now
    var origemRaw: String = OrigemTransacao.manual.rawValue

    var categoria: Categoria?
    var conta: Conta?

    /// Quando preenchida, esta transação é o pagamento de uma conta fixa.
    /// A calculadora usa isto para não contar o valor duas vezes.
    var recorrente: Recorrente?

    var tipo: TipoTransacao {
        get { TipoTransacao(rawValue: tipoRaw) ?? .despesa }
        set { tipoRaw = newValue.rawValue }
    }

    var origem: OrigemTransacao {
        get { OrigemTransacao(rawValue: origemRaw) ?? .manual }
        set { origemRaw = newValue.rawValue }
    }

    init(
        valor: Decimal,
        tipo: TipoTransacao = .despesa,
        descricao: String,
        loja: String? = nil,
        data: Date = .now,
        nota: String? = nil,
        categoria: Categoria? = nil,
        conta: Conta? = nil,
        recorrente: Recorrente? = nil,
        origem: OrigemTransacao = .manual
    ) {
        self.valor = valor
        self.tipoRaw = tipo.rawValue
        self.descricao = descricao
        self.loja = loja
        self.data = data
        self.nota = nota
        self.criadaEm = .now
        self.origemRaw = origem.rawValue
        self.categoria = categoria
        self.conta = conta
        self.recorrente = recorrente
    }
}
