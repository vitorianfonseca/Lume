import Testing
import Foundation
@testable import Lume

struct FechoDoMesTests {
    private let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }()

    private func data(_ ano: Int, _ mes: Int, _ dia: Int) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: 12))!
    }

    private func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @Test("Sem movimentos, não há fecho — não se força um resumo vazio")
    func semMovimentos() {
        let resultado = FechoDoMes.calcular(FechoDoMes.Entrada(mes: 9, ano: 2026, calendario: calendario))
        #expect(resultado == nil)
    }

    @Test("O total gasto bate certo com a soma dos movimentos, ao cêntimo")
    func totalBateCerto() throws {
        let movimentos = [
            FechoDoMes.Movimento(valor: eur("12.50"), data: data(2026, 9, 2), categoriaNome: "Restauração", loja: "Café A"),
            FechoDoMes.Movimento(valor: eur("45.30"), data: data(2026, 9, 10), categoriaNome: "Supermercado", loja: "Pingo Doce"),
            FechoDoMes.Movimento(valor: eur("8.19"), data: data(2026, 9, 15), categoriaNome: "Restauração", loja: "Café A"),
        ]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: movimentos
        )))
        #expect(resultado.totalGasto == eur("65.99"))
        #expect(resultado.numeroDeMovimentos == 3)
    }

    @Test("A comparação com o mês anterior é a diferença exata, em euros e fração")
    func comparacaoComMesAnterior() throws {
        let agora = [FechoDoMes.Movimento(valor: eur("300"), data: data(2026, 9, 5), categoriaNome: nil, loja: nil)]
        let antes = [FechoDoMes.Movimento(valor: eur("400"), data: data(2026, 8, 5), categoriaNome: nil, loja: nil)]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: agora, movimentosDoMesAnterior: antes
        )))
        #expect(resultado.diferencaVsMesAnterior == eur("-100"))
        #expect(resultado.fracaoVsMesAnterior == -0.25)
    }

    @Test("Sem mês anterior, a comparação fica em branco em vez de inventar 0%")
    func semMesAnterior() throws {
        let agora = [FechoDoMes.Movimento(valor: eur("50"), data: data(2026, 9, 5), categoriaNome: nil, loja: nil)]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: agora
        )))
        #expect(resultado.totalGastoMesAnterior == nil)
        #expect(resultado.fracaoVsMesAnterior == nil)
    }

    @Test("A categoria principal é a que soma mais, com a fração certa do total")
    func categoriaPrincipal() throws {
        let movimentos = [
            FechoDoMes.Movimento(valor: eur("80"), data: data(2026, 9, 2), categoriaNome: "Casa", loja: nil),
            FechoDoMes.Movimento(valor: eur("20"), data: data(2026, 9, 3), categoriaNome: "Lazer", loja: nil),
        ]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: movimentos
        )))
        #expect(resultado.categoriaPrincipal?.nome == "Casa")
        #expect(resultado.categoriaPrincipal?.valor == eur("80"))
        #expect(resultado.categoriaPrincipal?.fracaoDoTotal == 0.8)
    }

    @Test("A categoria que mais subiu só conta quando já havia gasto antes, e é a maior diferença")
    func categoriaQueMaisSubiu() throws {
        let agora = [
            FechoDoMes.Movimento(valor: eur("100"), data: data(2026, 9, 2), categoriaNome: "Casa", loja: nil),
            FechoDoMes.Movimento(valor: eur("30"), data: data(2026, 9, 3), categoriaNome: "Viagens", loja: nil),
        ]
        let antes = [
            FechoDoMes.Movimento(valor: eur("70"), data: data(2026, 8, 2), categoriaNome: "Casa", loja: nil),
        ]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: agora, movimentosDoMesAnterior: antes
        )))
        // "Viagens" subiu de 0, mas 0 não conta como categoria que "subiu" — era nova.
        #expect(resultado.categoriaQueMaisSubiu?.nome == "Casa")
        #expect(resultado.categoriaQueMaisSubiu?.diferenca == eur("30"))
    }

    @Test("O dia mais caro e o mais poupado são o máximo e o mínimo por dia")
    func diasExtremos() throws {
        let movimentos = [
            FechoDoMes.Movimento(valor: eur("10"), data: data(2026, 9, 2), categoriaNome: nil, loja: nil),
            FechoDoMes.Movimento(valor: eur("90"), data: data(2026, 9, 10), categoriaNome: nil, loja: nil),
            FechoDoMes.Movimento(valor: eur("5"), data: data(2026, 9, 20), categoriaNome: nil, loja: nil),
        ]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: movimentos
        )))
        #expect(resultado.diaMaisCaro?.valor == eur("90"))
        #expect(resultado.diaMaisPoupado?.valor == eur("5"))
    }

    @Test("Os limites contam os respeitados e identificam o maior excesso")
    func limites() throws {
        let movimentos = [
            FechoDoMes.Movimento(valor: eur("50"), data: data(2026, 9, 2), categoriaNome: "Casa", loja: nil),
            FechoDoMes.Movimento(valor: eur("200"), data: data(2026, 9, 3), categoriaNome: "Lazer", loja: nil),
        ]
        let categorias = [
            FechoDoMes.Categoria(nome: "Casa", simbolo: "house.fill", orcamentoMensal: eur("100")),
            FechoDoMes.Categoria(nome: "Lazer", simbolo: "ticket.fill", orcamentoMensal: eur("150")),
        ]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: movimentos, categorias: categorias
        )))
        #expect(resultado.limites?.respeitados == 1)
        #expect(resultado.limites?.total == 2)
        #expect(resultado.limites?.categoriaMaisExcedida == "Lazer")
        #expect(resultado.limites?.excesso == eur("50"))
    }

    @Test("Sem nenhuma categoria com limite definido, não há cartão de limites")
    func semLimitesDefinidos() throws {
        let movimentos = [FechoDoMes.Movimento(valor: eur("10"), data: data(2026, 9, 2), categoriaNome: "Casa", loja: nil)]
        let resultado = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: movimentos
        )))
        #expect(resultado.limites == nil)
    }

    @Test("O destaque só aparece com 3 ou mais visitas ao mesmo comerciante")
    func destaqueCurioso() throws {
        let duasVezes = [
            FechoDoMes.Movimento(valor: eur("1.2"), data: data(2026, 9, 1), categoriaNome: nil, loja: "Café A"),
            FechoDoMes.Movimento(valor: eur("1.2"), data: data(2026, 9, 2), categoriaNome: nil, loja: "Café A"),
        ]
        let semDestaque = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: duasVezes
        )))
        #expect(semDestaque.destaque == nil)

        let tresVezes = duasVezes + [
            FechoDoMes.Movimento(valor: eur("1.2"), data: data(2026, 9, 3), categoriaNome: nil, loja: "Café A"),
        ]
        let comDestaque = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: tresVezes
        )))
        #expect(comDestaque.destaque?.loja == "Café A")
        #expect(comDestaque.destaque?.vezes == 3)
        #expect(comDestaque.destaque?.total == eur("3.6"))
    }

    @Test("Menos de 10 movimentos é a versão curta; 10 ou mais é a versão completa")
    func versaoCurta() throws {
        let nove = (1...9).map {
            FechoDoMes.Movimento(valor: eur("1"), data: data(2026, 9, $0), categoriaNome: nil, loja: nil)
        }
        let comNove = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: nove
        )))
        #expect(comNove.versaoCurta)

        let dez = nove + [FechoDoMes.Movimento(valor: eur("1"), data: data(2026, 9, 10), categoriaNome: nil, loja: nil)]
        let comDez = try semNil(FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: 9, ano: 2026, calendario: calendario, movimentosDoMes: dez
        )))
        #expect(!comDez.versaoCurta)
    }

    private enum ErroDeTeste: Error { case esperavaResultado }

    private func semNil(_ resultado: FechoDoMes.Resultado?) throws -> FechoDoMes.Resultado {
        guard let resultado else { throw ErroDeTeste.esperavaResultado }
        return resultado
    }
}
