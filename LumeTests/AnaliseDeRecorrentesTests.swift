import Testing
import Foundation
@testable import Lume

struct AnaliseDeRecorrentesTests {
    private func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @Test("O custo anual é o valor mensal vezes 12")
    func custoAnual() {
        #expect(AnaliseDeRecorrentes.custoAnual(eur("9.99")) == eur("119.88"))
    }

    @Test("Uma subida de 8% é detetada")
    func subidaPercentual() {
        let subida = AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: [eur("37.50"), eur("40.50")])
        #expect(subida != nil)
        #expect(subida?.diferenca == eur("3"))
    }

    @Test("Uma variação de poucos cêntimos, abaixo dos dois limiares, não alerta")
    func variacaoNormal() {
        let subida = AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: [eur("45.00"), eur("45.30")])
        #expect(subida == nil)
    }

    @Test("Uma conta barata que sobe 2€ alerta mesmo sendo uma fração grande")
    func limiarAbsolutoPequenaConta() {
        let subida = AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: [eur("8.00"), eur("10.00")])
        #expect(subida != nil)
    }

    @Test("Descer de preço nunca é uma subida")
    func descidaDePreco() {
        #expect(AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: [eur("40"), eur("35")]) == nil)
    }

    @Test("Com só um pagamento não há nada para comparar")
    func umSoPagamento() {
        #expect(AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: [eur("10")]) == nil)
    }

    @Test("Três meses seguidos com valor parecido sugere uma nova recorrente")
    func sugestaoValida() {
        let pagamentos = [
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 7, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 8, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("31"), mes: 9, ano: 2026),
        ]
        let sugestoes = AnaliseDeRecorrentes.sugerirNovasRecorrentes(pagamentos: pagamentos, nomesExistentes: [], nomesIgnorados: [])
        #expect(sugestoes.count == 1)
        #expect(sugestoes.first?.nome == "Ginásio")
    }

    @Test("Meses não seguidos não sugerem nada")
    func mesesSalteados() {
        let pagamentos = [
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 1, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 3, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 5, ano: 2026),
        ]
        #expect(AnaliseDeRecorrentes.sugerirNovasRecorrentes(pagamentos: pagamentos, nomesExistentes: [], nomesIgnorados: []).isEmpty)
    }

    @Test("A virada do ano (dez, jan, fev) conta como seguida")
    func viradaDoAno() {
        let pagamentos = [
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 12, ano: 2025),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 1, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 2, ano: 2026),
        ]
        #expect(AnaliseDeRecorrentes.sugerirNovasRecorrentes(pagamentos: pagamentos, nomesExistentes: [], nomesIgnorados: []).count == 1)
    }

    @Test("Valores fora da faixa de 10% não sugerem — não é a mesma conta")
    func valoresDesiguais() {
        let pagamentos = [
            AnaliseDeRecorrentes.Pagamento(nome: "Loja", valor: eur("20"), mes: 1, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Loja", valor: eur("20"), mes: 2, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Loja", valor: eur("60"), mes: 3, ano: 2026),
        ]
        #expect(AnaliseDeRecorrentes.sugerirNovasRecorrentes(pagamentos: pagamentos, nomesExistentes: [], nomesIgnorados: []).isEmpty)
    }

    @Test("Já ser uma recorrente ou ter sido ignorada tira-a das sugestões")
    func existenteOuIgnorada() {
        let pagamentos = [
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 1, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 2, ano: 2026),
            AnaliseDeRecorrentes.Pagamento(nome: "Ginásio", valor: eur("30"), mes: 3, ano: 2026),
        ]
        #expect(AnaliseDeRecorrentes.sugerirNovasRecorrentes(pagamentos: pagamentos, nomesExistentes: ["Ginásio"], nomesIgnorados: []).isEmpty)
        #expect(AnaliseDeRecorrentes.sugerirNovasRecorrentes(pagamentos: pagamentos, nomesExistentes: [], nomesIgnorados: ["Ginásio"]).isEmpty)
    }
}
