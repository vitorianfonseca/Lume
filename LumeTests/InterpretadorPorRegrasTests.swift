import Testing
import Foundation
@testable import Lume

struct InterpretadorPorRegrasTests {

    private let interpretador = InterpretadorPorRegras()
    private let categorias = ["Supermercado", "Restauração", "Transportes", "Casa", "Subscrições", "Saúde", "Lazer"]

    private let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }()

    // 21 de abril de 2026, ao meio-dia — referência fixa para os testes.
    private var hoje: Date {
        calendario.date(from: DateComponents(year: 2026, month: 4, day: 21, hour: 12))!
    }

    private func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @Test("'gastei 12,50 no almoço' — valor com vírgula e categoria por palavra-chave")
    func almoco() async throws {
        let proposta = try await interpretador.interpretar("gastei 12,50 no almoço", categorias: categorias, hoje: hoje)

        #expect(proposta.valor == eur("12.50"))
        #expect(proposta.tipo == .despesa)
        #expect(proposta.descricao == "Almoço")
        #expect(proposta.nomeDaCategoria == "Restauração")
        #expect(calendario.isDate(proposta.data, inSameDayAs: hoje))
    }

    @Test("'uber 8€ ontem' — data relativa resolvida em Swift, loja reconhecida")
    func uberOntem() async throws {
        let proposta = try await interpretador.interpretar("uber 8€ ontem", categorias: categorias, hoje: hoje)

        let ontem = calendario.date(byAdding: .day, value: -1, to: hoje)!
        #expect(proposta.valor == eur("8"))
        #expect(proposta.loja == "Uber")
        #expect(proposta.nomeDaCategoria == "Transportes")
        #expect(calendario.isDate(proposta.data, inSameDayAs: ontem))
    }

    @Test("'recebi o salário 1450' — reconhecido como receita")
    func salario() async throws {
        let proposta = try await interpretador.interpretar("recebi o salário 1450", categorias: categorias, hoje: hoje)

        #expect(proposta.valor == eur("1450"))
        #expect(proposta.tipo == .receita)
        #expect(proposta.descricao == "Salário")
    }

    @Test("'café 80 cêntimos' — cêntimos convertidos para euros em Swift")
    func cafeEmCentimos() async throws {
        let proposta = try await interpretador.interpretar("café 80 cêntimos", categorias: categorias, hoje: hoje)

        #expect(proposta.valor == eur("0.80"))
        #expect(proposta.nomeDaCategoria == "Restauração")
    }

    @Test("A categoria devolvida existe sempre na lista — nunca é inventada")
    func categoriaNuncaInventada() async throws {
        // Lista sem "Restauração": a palavra "almoço" não pode produzir categoria.
        let proposta = try await interpretador.interpretar("almoço 12,50", categorias: ["Casa"], hoje: hoje)

        #expect(proposta.nomeDaCategoria == nil)
    }

    @Test("Texto sem valor lança erro em vez de adivinhar")
    func textoSemValor() async {
        await #expect(throws: ErroDeInterpretacao.self) {
            _ = try await interpretador.interpretar("almocei muito bem", categorias: categorias, hoje: hoje)
        }
    }

    @Test(
        "O resolutor converte datas relativas e explícitas",
        arguments: [("hoje", 0), ("ontem", -1), ("anteontem", -2)]
    )
    func resolutorDeDatasRelativas(texto: String, deslocacao: Int) {
        let esperada = calendario.date(byAdding: .day, value: deslocacao, to: hoje)!
        let resolvida = ResolutorDeDatas.resolver(texto, emRelacaoA: hoje, calendario: calendario)

        #expect(calendario.isDate(resolvida, inSameDayAs: esperada))
    }

    @Test("O resolutor aceita datas explícitas e rejeita impossíveis")
    func resolutorDeDatasExplicitas() {
        let iso = ResolutorDeDatas.resolver("2026-04-03", emRelacaoA: hoje, calendario: calendario)
        #expect(calendario.dateComponents([.year, .month, .day], from: iso) == DateComponents(year: 2026, month: 4, day: 3))

        let portuguesa = ResolutorDeDatas.resolver("3/4", emRelacaoA: hoje, calendario: calendario)
        #expect(calendario.isDate(portuguesa, inSameDayAs: iso))

        // 31/02 não existe: volta a "hoje" em vez de inventar.
        let impossivel = ResolutorDeDatas.resolver("31/2", emRelacaoA: hoje, calendario: calendario)
        #expect(calendario.isDate(impossivel, inSameDayAs: hoje))
    }

    @Test("Talão: a loja chega para sugerir a categoria")
    func sugestaoPelaLoja() {
        #expect(InterpretadorPorRegras.sugerirCategoria(para: "PINGO DOCE", entre: categorias) == "Supermercado")
        #expect(InterpretadorPorRegras.sugerirCategoria(para: "Galp Benfica", entre: categorias) == "Transportes")
    }

    @Test("Roupa só é sugerida quando a categoria existe")
    func sugestaoDeRoupa() {
        #expect(InterpretadorPorRegras.sugerirCategoria(para: "zara casaco 49", entre: categorias + ["Roupa"]) == "Roupa")
        #expect(InterpretadorPorRegras.sugerirCategoria(para: "zara casaco 49", entre: categorias) == nil)
    }

    @Test("Sem pistas, não inventa categoria")
    func semSugestao() {
        #expect(InterpretadorPorRegras.sugerirCategoria(para: "coisa 12", entre: categorias) == nil)
    }
}
