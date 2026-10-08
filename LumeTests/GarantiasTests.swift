import Testing
import Foundation
@testable import Lume

struct GarantiasTests {
    private func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }()

    private func data(_ ano: Int, _ mes: Int, _ dia: Int) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: 12))!
    }

    @Test("Sugere com categoria na lista e valor acima do mínimo")
    func sugereCasoValido() {
        #expect(Garantias.deveSugerir(categoriaNome: "Casa", valor: eur("80"), valorMinimo: eur("50"), categoriasSugeridas: ["Casa", "Roupa"]))
    }

    @Test("Não sugere abaixo do valor mínimo")
    func naoSugereValorBaixo() {
        #expect(!Garantias.deveSugerir(categoriaNome: "Casa", valor: eur("40"), valorMinimo: eur("50"), categoriasSugeridas: ["Casa"]))
    }

    @Test("Não sugere fora da lista de categorias")
    func naoSugereCategoriaFora() {
        #expect(!Garantias.deveSugerir(categoriaNome: "Restauração", valor: eur("80"), valorMinimo: eur("50"), categoriasSugeridas: ["Casa"]))
    }

    @Test("Sem categoria, nunca sugere")
    func naoSugereSemCategoria() {
        #expect(!Garantias.deveSugerir(categoriaNome: nil, valor: eur("80"), valorMinimo: eur("50"), categoriasSugeridas: ["Casa"]))
    }

    @Test("A comparação da categoria ignora maiúsculas e acentos")
    func comparacaoTolerante() {
        #expect(Garantias.deveSugerir(categoriaNome: "ELETRODOMÉSTICOS", valor: eur("80"), valorMinimo: eur("50"), categoriasSugeridas: ["Eletrodomésticos"]))
    }

    @Test("Uma compra de há quase 3 anos, com garantia de 36 meses, ainda não expirou")
    func compraAntigaAindaValida() {
        let compra = data(2023, 11, 10)
        let fim = Garantias.dataFim(dataDaCompra: compra, duracaoEmMeses: 36, calendario: calendario)
        #expect(!Garantias.expirada(dataFim: fim, agora: data(2026, 10, 1)))
    }

    @Test("Passado o fim, está expirada")
    func expirada() {
        let fim = data(2026, 1, 1)
        #expect(Garantias.expirada(dataFim: fim, agora: data(2026, 10, 1)))
    }

    @Test("Nos últimos 30 dias antes do fim, está a aproximar-se")
    func aproximandoSe() {
        let fim = data(2026, 10, 20)
        #expect(Garantias.aAproximarSeDoFim(dataFim: fim, agora: data(2026, 10, 1), calendario: calendario))
    }

    @Test("Muito antes do fim, ainda não é motivo de aviso")
    func longeDoFim() {
        let fim = data(2027, 10, 20)
        #expect(!Garantias.aAproximarSeDoFim(dataFim: fim, agora: data(2026, 10, 1), calendario: calendario))
    }
}
