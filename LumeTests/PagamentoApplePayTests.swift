import Testing
import Foundation
@testable import Lume

struct PagamentoApplePayTests {
    private func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @Test("Vírgula decimal e símbolo depois do valor")
    func virgulaDepois() throws {
        let resultado = try PagamentoApplePay.interpretarValor("12,50 €", comerciante: "Time Out Market")
        #expect(resultado.valor == eur("12.50"))
        #expect(resultado.tipo == .despesa)
    }

    @Test("Ponto decimal e símbolo antes do valor")
    func pontoAntes() throws {
        let resultado = try PagamentoApplePay.interpretarValor("€12.50", comerciante: "Apple Store")
        #expect(resultado.valor == eur("12.50"))
    }

    @Test("Espaço não separável nos milhares não impede a leitura")
    func espacoNaoSeparavel() throws {
        let resultado = try PagamentoApplePay.interpretarValor("1\u{00A0}234,56 €", comerciante: "Loja")
        #expect(resultado.valor == eur("1234.56"))
    }

    @Test("Valor negativo vira receita, nunca uma despesa negativa")
    func valorNegativo() throws {
        let resultado = try PagamentoApplePay.interpretarValor("-9,99 €", comerciante: "Zara")
        #expect(resultado.valor == eur("9.99"))
        #expect(resultado.tipo == .receita)
    }

    @Test("A palavra reembolso no comerciante também vira receita")
    func reembolsoNoComerciante() throws {
        let resultado = try PagamentoApplePay.interpretarValor("9,99 €", comerciante: "Reembolso Zara")
        #expect(resultado.tipo == .receita)
    }

    @Test("Texto sem nenhum valor lança erro em vez de adivinhar")
    func textoIlegivel() {
        #expect(throws: PagamentoApplePay.ErroDeValor.self) {
            try PagamentoApplePay.interpretarValor("qualquer coisa", comerciante: "Loja")
        }
    }

    @Test("Zero não é um pagamento válido")
    func valorZero() {
        #expect(throws: PagamentoApplePay.ErroDeValor.self) {
            try PagamentoApplePay.interpretarValor("0,00 €", comerciante: "Loja")
        }
    }

    @Test("O mesmo comerciante, valor e conta nos últimos 3 minutos é duplicado")
    func duplicadoDentroDaJanela() {
        let agora = Date.now
        let recentes = [
            PagamentoApplePay.TransacaoRecente(loja: "Pingo Doce", valor: eur("12.50"), nomeDaConta: "Revolut", data: agora.addingTimeInterval(-60))
        ]
        #expect(PagamentoApplePay.eDuplicado(comerciante: "Pingo Doce", valor: eur("12.50"), nomeDaConta: "Revolut", agora: agora, entre: recentes))
    }

    @Test("Fora da janela de 3 minutos já não é duplicado")
    func naoDuplicadoForaDaJanela() {
        let agora = Date.now
        let recentes = [
            PagamentoApplePay.TransacaoRecente(loja: "Pingo Doce", valor: eur("12.50"), nomeDaConta: "Revolut", data: agora.addingTimeInterval(-200))
        ]
        #expect(!PagamentoApplePay.eDuplicado(comerciante: "Pingo Doce", valor: eur("12.50"), nomeDaConta: "Revolut", agora: agora, entre: recentes))
    }

    @Test("Contas diferentes não contam como duplicado")
    func contaDiferenteNaoDuplica() {
        let agora = Date.now
        let recentes = [
            PagamentoApplePay.TransacaoRecente(loja: "Pingo Doce", valor: eur("12.50"), nomeDaConta: "CGD", data: agora.addingTimeInterval(-60))
        ]
        #expect(!PagamentoApplePay.eDuplicado(comerciante: "Pingo Doce", valor: eur("12.50"), nomeDaConta: "Revolut", agora: agora, entre: recentes))
    }
}
