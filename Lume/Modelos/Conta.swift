import Foundation
import SwiftData

nonisolated enum TipoConta: String, Codable, CaseIterable {
    case aOrdem
    case poupanca
    case dinheiro

    var nome: String {
        switch self {
        case .aOrdem: "À ordem"
        case .poupanca: "Poupança"
        case .dinheiro: "Dinheiro"
        }
    }
}

@Model
final class Conta {
    var nome: String = ""
    var tipoRaw: String = TipoConta.aOrdem.rawValue
    var saldoInicial: Decimal = Decimal.zero

    @Relationship(deleteRule: .nullify, inverse: \Transacao.conta)
    var transacoes: [Transacao]?

    var tipo: TipoConta {
        get { TipoConta(rawValue: tipoRaw) ?? .aOrdem }
        set { tipoRaw = newValue.rawValue }
    }

    /// O saldo atual é sempre derivado das transações — nunca é guardado,
    /// para não existir estado que possa dessincronizar.
    var saldoAtual: Decimal {
        (transacoes ?? []).reduce(saldoInicial) { saldo, transacao in
            transacao.tipo == .receita ? saldo + transacao.valor : saldo - transacao.valor
        }
    }

    init(nome: String, tipo: TipoConta = .aOrdem, saldoInicial: Decimal = .zero) {
        self.nome = nome
        self.tipoRaw = tipo.rawValue
        self.saldoInicial = saldoInicial
    }
}
