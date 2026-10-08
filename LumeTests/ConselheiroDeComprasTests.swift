import Foundation
import Testing

@testable import Lume

/// A conversão da resposta do modelo é determinística e testa-se sem rede.
/// A regra que estes testes protegem: **a Lume nunca inventa um preço**.
struct ConselheiroDeComprasTests {
    private func resposta(
        produto: String = "Sony WH-1000XM6",
        precoAtual: String = "389.00",
        precoNormal: String = "419.00",
        precoMaisBarato: String = "364.00",
        lojaMaisBarata: String = "Worten",
        nivel: String = "bom",
        veredicto: String = "Bom preço, mas já esteve 40 € mais barato.",
        problemas: [String] = ["desconfortável depois de várias horas", "microfone mediano com ruído"],
        alternativaNome: String = "Sony WH-1000XM5",
        alternativaPreco: String = "279.00",
        fontes: [ConselheiroDeCompras.RespostaDoModelo.Fonte] = [
            .init(nome: "Worten", endereco: "https://www.worten.pt/produto"),
        ]
    ) -> ConselheiroDeCompras.RespostaDoModelo {
        .init(
            produto: produto,
            precoAtual: precoAtual,
            precoNormal: precoNormal,
            precoMaisBarato: precoMaisBarato,
            lojaMaisBarata: lojaMaisBarata,
            nivel: nivel,
            veredicto: veredicto,
            problemas: problemas,
            alternativaNome: alternativaNome,
            alternativaPreco: alternativaPreco,
            fontes: fontes
        )
    }

    @Test("A resposta do modelo vira conselho com preços em Decimal")
    func mapeamentoCompleto() throws {
        let conselho = try ConselheiroDeCompras.conselho(de: resposta())

        #expect(conselho.produto == "Sony WH-1000XM6")
        #expect(conselho.precoAtual == 389)
        #expect(conselho.precoNormal == 419)
        #expect(conselho.precoMaisBarato == 364)
        #expect(conselho.lojaMaisBarata == "Worten")
        #expect(conselho.nivel == .bom)
        #expect(conselho.alternativaPreco == 279)
        #expect(conselho.fontes.count == 1)
    }

    @Test("Preços vazios ficam nil — a Lume nunca inventa um número")
    func semPrecosEncontrados() throws {
        let conselho = try ConselheiroDeCompras.conselho(de: resposta(
            precoAtual: "",
            precoNormal: "",
            precoMaisBarato: "",
            lojaMaisBarata: "",
            alternativaNome: "",
            alternativaPreco: ""
        ))

        #expect(conselho.precoAtual == nil)
        #expect(conselho.precoNormal == nil)
        #expect(conselho.precoMaisBarato == nil)
        #expect(conselho.lojaMaisBarata == nil)
        #expect(conselho.alternativaNome == nil)
        #expect(conselho.alternativaPreco == nil)
    }

    @Test("Preços com vírgula, símbolo ou espaços são lidos corretamente")
    func formatosDePreco() {
        #expect(ConselheiroDeCompras.decimal("389,90") == Decimal(string: "389.90"))
        #expect(ConselheiroDeCompras.decimal("389.90 €") == Decimal(string: "389.90"))
        #expect(ConselheiroDeCompras.decimal(" 1249.99 ") == Decimal(string: "1249.99"))
        #expect(ConselheiroDeCompras.decimal("0") == nil)
        #expect(ConselheiroDeCompras.decimal("grátis") == nil)
        #expect(ConselheiroDeCompras.decimal("") == nil)
    }

    @Test("Mostram-se no máximo três problemas, sem linhas vazias")
    func problemasLimitados() throws {
        let conselho = try ConselheiroDeCompras.conselho(de: resposta(problemas: [
            "primeiro", "  ", "segundo", "terceiro", "quarto",
        ]))

        #expect(conselho.problemas == ["primeiro", "segundo", "terceiro"])
    }

    @Test("Um nível desconhecido não rebenta: fica razoável")
    func nivelDesconhecido() throws {
        let conselho = try ConselheiroDeCompras.conselho(de: resposta(nivel: "excelentissimo"))
        #expect(conselho.nivel == .razoavel)
    }

    @Test("Sem produto identificado, o erro é explícito em vez de adivinhar")
    func semProduto() {
        #expect(throws: ErroDeConselho.produtoNaoEncontrado) {
            try ConselheiroDeCompras.conselho(de: resposta(produto: "   "))
        }
    }

    @Test("Fontes sem endereço são descartadas — sem link não há prova")
    func fontesSemEndereco() throws {
        let conselho = try ConselheiroDeCompras.conselho(de: resposta(fontes: [
            .init(nome: "Worten", endereco: "https://www.worten.pt/produto"),
            .init(nome: "Inventada", endereco: ""),
        ]))

        #expect(conselho.fontes.count == 1)
        #expect(conselho.fontes.first?.nome == "Worten")
    }
}
