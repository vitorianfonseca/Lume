import Foundation
import SwiftData

/// Conta fixa ou subscrição que se repete todos os meses (renda, EDP, Netflix…).
@Model
final class Recorrente {
    var nome: String = ""
    var valor: Decimal = Decimal.zero
    var diaDoMes: Int = 1
    var ativa: Bool = true
    var ultimoPagamentoEm: Date?
    /// Marca as que fazem sentido perguntar "ainda usas?" — não as contas
    /// fixas obrigatórias (renda, eletricidade), só subscrições de escolha.
    var eSubscricao: Bool = false
    /// Data em que acaba o período de fidelização, se houver.
    var fimDaFidelizacao: Date?
    /// Quando se perguntou "ainda usas?" pela última vez — de 3 em 3 meses.
    var ultimaPerguntaDeUso: Date?

    var categoria: Categoria?

    @Relationship(deleteRule: .nullify, inverse: \Transacao.recorrente)
    var pagamentos: [Transacao]?

    init(
        nome: String,
        valor: Decimal,
        diaDoMes: Int,
        categoria: Categoria? = nil,
        ativa: Bool = true,
        ultimoPagamentoEm: Date? = nil,
        eSubscricao: Bool = false,
        fimDaFidelizacao: Date? = nil,
        ultimaPerguntaDeUso: Date? = nil
    ) {
        self.nome = nome
        self.valor = valor
        self.diaDoMes = diaDoMes
        self.categoria = categoria
        self.ativa = ativa
        self.ultimoPagamentoEm = ultimoPagamentoEm
        self.eSubscricao = eSubscricao
        self.fimDaFidelizacao = fimDaFidelizacao
        self.ultimaPerguntaDeUso = ultimaPerguntaDeUso
    }
}

extension Recorrente {
    /// A recorrente ativa cujo nome bate com a descrição ou a loja de um
    /// movimento — para ligar o pagamento automaticamente, venha de onde vier.
    static func correspondente(descricao: String, loja: String?, entre recorrentes: [Recorrente]) -> Recorrente? {
        let ativas = recorrentes.filter(\.ativa)
        guard let nome = CorrespondenciaDeRecorrente.nomeCorrespondente(
            descricao: descricao, loja: loja, entreNomes: ativas.map(\.nome)
        ) else { return nil }
        return ativas.first { $0.nome == nome }
    }

    /// Chamado antes de inserir o novo pagamento, enquanto `pagamentos`
    /// ainda só tem os anteriores — diz se este valor é uma subida.
    func subidaComNovoValor(_ novoValor: Decimal) -> AnaliseDeRecorrentes.Subida? {
        let antigos = (pagamentos ?? []).sorted { $0.data < $1.data }.map(\.valor)
        return AnaliseDeRecorrentes.detetarSubida(pagamentosOrdenados: antigos + [novoValor])
    }
}
