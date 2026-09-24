import Foundation

/// Proposta estruturada produzida por um interpretador, pronta a editar
/// no cartão de confirmação. Nada é gravado sem o utilizador confirmar.
nonisolated struct PropostaDeTransacao: Equatable, Sendable {
    var valor: Decimal
    var tipo: TipoTransacao
    var descricao: String
    var loja: String?
    /// Nome de uma categoria existente, validado contra a lista — nunca inventado.
    var nomeDaCategoria: String?
    var data: Date
}

nonisolated enum ErroDeInterpretacao: Error {
    /// O texto não contém nenhum valor monetário reconhecível.
    case textoSemValor
    case falhaDoModelo(String)
}

/// Fronteira entre a app e qualquer motor de interpretação (Foundation Models,
/// regras, ou o Claude no Premium). O interpretador só transforma texto em
/// dados estruturados — todas as contas ficam do lado da app.
nonisolated protocol InterpretadorDeDespesas: Sendable {
    /// - Parameters:
    ///   - categorias: nomes das categorias existentes; o resultado só pode escolher destas.
    ///   - hoje: referência para resolver datas relativas ("ontem") de forma determinística.
    func interpretar(_ texto: String, categorias: [String], hoje: Date) async throws -> PropostaDeTransacao
}
