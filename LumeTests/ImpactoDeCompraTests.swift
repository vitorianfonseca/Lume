import Foundation
import Testing

@testable import Lume

/// O impacto de uma compra no mês é a parte que a app faz sozinha — e é
/// a que tem de estar certa, porque é nela que a pessoa decide.
struct ImpactoDeCompraTests {
    @Test("Uma compra vale os dias do ritmo que consome")
    func diasDoRitmo() {
        // 357,10 € em 6 dias = 59,52 € por dia. Uma compra de 389 € vale 6,5 dias.
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 389,
            disponivelDoMes: Decimal(string: "357.10")!,
            diasRestantes: 6,
            gastoNaCategoria: nil,
            orcamentoDaCategoria: nil
        ))

        #expect(resultado.porDiaAntes == Decimal(string: "59.52"))
        #expect(resultado.diasDoRitmo == Decimal(string: "6.5"))
    }

    @Test("Gastar mais do que resta é dito com calma, não escondido")
    func estouraOMes() {
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 500,
            disponivelDoMes: Decimal(string: "357.10")!,
            diasRestantes: 6,
            gastoNaCategoria: nil,
            orcamentoDaCategoria: nil
        ))

        #expect(resultado.estouraOMes)
        #expect(resultado.disponivelDepois == Decimal(string: "-142.90"))
        #expect(resultado.porDiaDepois < .zero)
    }

    @Test("Uma compra que cabe no mês baixa o por-dia sem o tornar negativo")
    func cabeNoMes() {
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 60,
            disponivelDoMes: 300,
            diasRestantes: 10,
            gastoNaCategoria: nil,
            orcamentoDaCategoria: nil
        ))

        #expect(!resultado.estouraOMes)
        #expect(resultado.porDiaAntes == 30)
        #expect(resultado.porDiaDepois == 24)
        #expect(resultado.diasDoRitmo == 2)
    }

    @Test("Com categoria, diz-se o que sobra desse limite")
    func limiteDaCategoria() {
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 50,
            disponivelDoMes: 300,
            diasRestantes: 10,
            gastoNaCategoria: 128,
            orcamentoDaCategoria: 220
        ))

        #expect(!resultado.estouraACategoria)
        #expect(resultado.sobraNaCategoria == 42)
    }

    @Test("Passar o limite da categoria é detetado mesmo cabendo no mês")
    func estouraACategoria() {
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 120,
            disponivelDoMes: 300,
            diasRestantes: 10,
            gastoNaCategoria: 128,
            orcamentoDaCategoria: 220
        ))

        #expect(!resultado.estouraOMes)
        #expect(resultado.estouraACategoria)
        #expect(resultado.sobraNaCategoria == -28)
    }

    @Test("Sem ritmo (nada disponível) não há divisão por zero")
    func semRitmo() {
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 100,
            disponivelDoMes: .zero,
            diasRestantes: 5,
            gastoNaCategoria: nil,
            orcamentoDaCategoria: nil
        ))

        #expect(resultado.diasDoRitmo == .zero)
        #expect(resultado.estouraOMes)
    }

    @Test("No último dia do mês, o por-dia é tudo o que resta")
    func ultimoDia() {
        let resultado = ImpactoDeCompra.calcular(.init(
            preco: 20,
            disponivelDoMes: 80,
            diasRestantes: 1,
            gastoNaCategoria: nil,
            orcamentoDaCategoria: nil
        ))

        #expect(resultado.porDiaAntes == 80)
        #expect(resultado.porDiaDepois == 60)
    }
}
