import Testing
@testable import Lume

struct CodigoDeBloqueioTests {
    @Test("Quatro dígitos é válido")
    func quatroDigitos() {
        #expect(CodigoDeBloqueio.valido("1234"))
    }

    @Test("Com letras não é válido")
    func comLetras() {
        #expect(!CodigoDeBloqueio.valido("12a4"))
    }

    @Test("Com mais ou menos de 4 dígitos não é válido")
    func comprimentoErrado() {
        #expect(!CodigoDeBloqueio.valido("123"))
        #expect(!CodigoDeBloqueio.valido("12345"))
    }

    @Test("Vazio não é válido")
    func vazio() {
        #expect(!CodigoDeBloqueio.valido(""))
    }
}
