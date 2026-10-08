import Testing
@testable import Lume

struct CorrespondenciaDeRecorrenteTests {
    @Test("A descrição igual ao nome, sem maiúsculas nem acentos, conta como correspondência")
    func descricaoIgual() {
        let nome = CorrespondenciaDeRecorrente.nomeCorrespondente(
            descricao: "NETFLIX", loja: nil, entreNomes: ["Netflix", "EDP"]
        )
        #expect(nome == "Netflix")
    }

    @Test("A loja também conta, mesmo com a descrição diferente")
    func lojaCorresponde() {
        let nome = CorrespondenciaDeRecorrente.nomeCorrespondente(
            descricao: "Assinatura mensal", loja: "edp", entreNomes: ["Netflix", "EDP"]
        )
        #expect(nome == "EDP")
    }

    @Test("Sem nenhuma correspondência, devolve nil")
    func semCorrespondencia() {
        let nome = CorrespondenciaDeRecorrente.nomeCorrespondente(
            descricao: "Café", loja: "Pastelaria", entreNomes: ["Netflix", "EDP"]
        )
        #expect(nome == nil)
    }

    @Test("Lista vazia nunca corresponde")
    func listaVazia() {
        let nome = CorrespondenciaDeRecorrente.nomeCorrespondente(
            descricao: "Netflix", loja: nil, entreNomes: []
        )
        #expect(nome == nil)
    }
}
