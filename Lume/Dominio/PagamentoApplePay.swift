import Foundation

/// A parte sem SwiftData do registo automático via Apple Pay: interpretar
/// o valor que a automação "Transação" entrega (sempre texto, às vezes
/// "12,50 €", às vezes "€12.50") e decidir se um pagamento é repetido.
nonisolated enum PagamentoApplePay {
    struct ValorInterpretado: Equatable {
        var valor: Decimal
        var tipo: TipoTransacao
    }

    enum ErroDeValor: Error {
        case ilegivel
    }

    /// Vírgula ou ponto decimal, símbolo antes ou depois, espaços normais
    /// e não separáveis — reaproveita o mesmo leitor dos campos de euros.
    /// Negativo ou com a palavra "reembolso" (no valor ou no comerciante)
    /// vira receita, nunca uma despesa negativa.
    static func interpretarValor(_ texto: String, comerciante: String) throws -> ValorInterpretado {
        guard let bruto = try? FormatoDeEuros.Estrategia().parse(texto), bruto != .zero else {
            throw ErroDeValor.ilegivel
        }
        let ehReembolso = bruto < .zero
            || texto.localizedCaseInsensitiveContains("reembolso")
            || comerciante.localizedCaseInsensitiveContains("reembolso")
        let valorAbsoluto = bruto < .zero ? -bruto : bruto
        return ValorInterpretado(valor: valorAbsoluto, tipo: ehReembolso ? .receita : .despesa)
    }

    struct TransacaoRecente: Equatable {
        var loja: String?
        var valor: Decimal
        var nomeDaConta: String?
        var data: Date
    }

    /// O mesmo comerciante, valor e conta nos últimos 3 minutos: repetir o
    /// pagamento (ou a automação disparar duas vezes) não duplica o registo.
    static func eDuplicado(
        comerciante: String,
        valor: Decimal,
        nomeDaConta: String?,
        agora: Date,
        entre recentes: [TransacaoRecente]
    ) -> Bool {
        recentes.contains {
            $0.loja == comerciante
                && $0.valor == valor
                && $0.nomeDaConta == nomeDaConta
                && agora.timeIntervalSince($0.data) < 180
        }
    }
}
