import Foundation

/// O que distingue a Lume de um comparador de preços: a pergunta não é só
/// "é bom preço?", é "posso comprar isto?". Estas contas são todas em Swift —
/// a IA pesquisa preços, a app faz as contas.
nonisolated enum ImpactoDeCompra {
    struct Entrada {
        var preco: Decimal
        /// Quanto resta do orçamento do mês, antes desta compra.
        var disponivelDoMes: Decimal
        var diasRestantes: Int
        /// Limite da categoria, se a compra encaixar numa.
        var gastoNaCategoria: Decimal?
        var orcamentoDaCategoria: Decimal?
    }

    struct Resultado: Equatable {
        /// Quantos dias do ritmo atual esta compra consome ("6,5 dias").
        var diasDoRitmo: Decimal
        var disponivelDepois: Decimal
        var porDiaAntes: Decimal
        var porDiaDepois: Decimal
        /// Passa a estar acima do orçamento do mês.
        var estouraOMes: Bool
        /// Passa o limite da categoria, quando há categoria.
        var estouraACategoria: Bool
        var sobraNaCategoria: Decimal?
    }

    static func calcular(_ entrada: Entrada) -> Resultado {
        let dias = max(entrada.diasRestantes, 1)
        let porDiaAntes = (entrada.disponivelDoMes / Decimal(dias)).arredondadoACentimos()
        let depois = entrada.disponivelDoMes - entrada.preco
        let porDiaDepois = (depois / Decimal(dias)).arredondadoACentimos()

        // "Dias do ritmo": quanto tempo do teu por-dia esta compra vale.
        // Sem ritmo definido (por-dia zero ou negativo) não há divisão a fazer.
        let diasDoRitmo: Decimal = porDiaAntes > .zero
            ? (entrada.preco / porDiaAntes).arredondadoADecima()
            : .zero

        var estouraACategoria = false
        var sobraNaCategoria: Decimal?
        if let gasto = entrada.gastoNaCategoria, let orcamento = entrada.orcamentoDaCategoria {
            let sobra = orcamento - gasto - entrada.preco
            sobraNaCategoria = sobra
            estouraACategoria = sobra < .zero
        }

        return Resultado(
            diasDoRitmo: diasDoRitmo,
            disponivelDepois: depois,
            porDiaAntes: porDiaAntes,
            porDiaDepois: porDiaDepois,
            estouraOMes: depois < .zero,
            estouraACategoria: estouraACategoria,
            sobraNaCategoria: sobraNaCategoria
        )
    }
}

nonisolated extension Decimal {
    /// Uma casa decimal, para os "6,5 dias".
    func arredondadoADecima() -> Decimal {
        var origem = self
        var resultado = Decimal.zero
        NSDecimalRound(&resultado, &origem, 1, .plain)
        return resultado
    }
}
