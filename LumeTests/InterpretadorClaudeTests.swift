import Foundation
import Testing
@testable import Lume

/// Testa só a parte determinística do interpretador Claude — o mapeamento
/// da resposta JSON para a proposta. A chamada de rede fica de fora.
struct InterpretadorClaudeTests {

    private let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }()

    private var hoje: Date {
        calendario.date(from: DateComponents(year: 2026, month: 9, day: 24))!
    }

    @Test("A resposta JSON do Claude vira proposta com valor Decimal e categoria validada")
    func mapeamentoCompleto() throws {
        let json = """
            {"valor": "12.50", "tipo": "despesa", "descricao": "Almoço", "loja": "Time Out Market", "categoria": "restauração", "dataRelativa": "ontem"}
            """
        let interpretada = try JSONDecoder().decode(
            InterpretadorClaude.DespesaDoClaude.self, from: Data(json.utf8)
        )
        let proposta = try InterpretadorClaude.proposta(
            de: interpretada,
            categorias: ["Supermercado", "Restauração"],
            hoje: hoje
        )

        #expect(proposta.valor == Decimal(string: "12.50", locale: Locale(identifier: "en_US_POSIX")))
        #expect(proposta.tipo == .despesa)
        #expect(proposta.loja == "Time Out Market")
        // Validação insensível a maiúsculas devolve o nome canónico da lista.
        #expect(proposta.nomeDaCategoria == "Restauração")
    }

    @Test("Campos vazios viram nil — loja e categoria são opcionais")
    func camposVazios() throws {
        let interpretada = InterpretadorClaude.DespesaDoClaude(
            valor: "3,40", tipo: "despesa", descricao: "Café",
            loja: "", categoria: "", dataRelativa: "hoje"
        )
        let proposta = try InterpretadorClaude.proposta(de: interpretada, categorias: [], hoje: hoje)

        #expect(proposta.loja == nil)
        #expect(proposta.nomeDaCategoria == nil)
        // A vírgula decimal também é aceite.
        #expect(proposta.valor == Decimal(string: "3.40", locale: Locale(identifier: "en_US_POSIX")))
    }

    @Test("Categoria fora da lista nunca é inventada")
    func categoriaForaDaLista() throws {
        let interpretada = InterpretadorClaude.DespesaDoClaude(
            valor: "10", tipo: "despesa", descricao: "Compra",
            loja: "", categoria: "Criptomoedas", dataRelativa: "hoje"
        )
        let proposta = try InterpretadorClaude.proposta(
            de: interpretada, categorias: ["Supermercado"], hoje: hoje
        )
        #expect(proposta.nomeDaCategoria == nil)
    }

    @Test("Valor inválido ou não positivo lança erro em vez de adivinhar")
    func valorInvalido() {
        let interpretada = InterpretadorClaude.DespesaDoClaude(
            valor: "zero", tipo: "despesa", descricao: "Nada",
            loja: "", categoria: "", dataRelativa: "hoje"
        )
        #expect(throws: ErroDeInterpretacao.self) {
            try InterpretadorClaude.proposta(de: interpretada, categorias: [], hoje: hoje)
        }
    }
}
