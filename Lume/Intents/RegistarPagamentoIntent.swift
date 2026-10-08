import AppIntents
import SwiftData

/// A ação que a automação "Transação" dos Atalhos chama a cada pagamento
/// Apple Pay — corre em segundo plano, sem abrir a app. Ver Perfil →
/// Registo automático para os passos de configuração.
struct RegistarPagamentoIntent: AppIntent {
    static let title: LocalizedStringResource = "Registar pagamento"
    static let description = IntentDescription(
        "Regista um pagamento Apple Pay na Lume, a partir da automação \"Transação\" dos Atalhos."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Comerciante")
    var comerciante: String

    @Parameter(title: "Valor")
    var valor: String

    @Parameter(title: "Cartão")
    var nomeDoCartao: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let contentor = ContentorDeDados.producao()
        let contexto = contentor.mainContext

        let comercianteLimpo = comerciante.trimmingCharacters(in: .whitespacesAndNewlines)
        let nomeFinal = comercianteLimpo.isEmpty ? "Apple Pay" : comercianteLimpo

        guard let interpretado = try? PagamentoApplePay.interpretarValor(valor, comerciante: nomeFinal) else {
            await NotificadorDePagamentos.avisarValorIlegivel(comerciante: nomeFinal)
            return .result()
        }

        let categorias = (try? contexto.fetch(FetchDescriptor<Categoria>())) ?? []
        let contas = (try? contexto.fetch(FetchDescriptor<Conta>())) ?? []
        let transacoesRecentes = (try? contexto.fetch(FetchDescriptor<Transacao>(
            sortBy: [SortDescriptor(\.data, order: .reverse)]
        ))) ?? []

        let conta = resolverConta(contexto: contexto, contas: contas)

        let agora = Date.now
        let recentes = transacoesRecentes.prefix(50).map {
            PagamentoApplePay.TransacaoRecente(loja: $0.loja, valor: $0.valor, nomeDaConta: $0.conta?.nome, data: $0.data)
        }
        guard !PagamentoApplePay.eDuplicado(
            comerciante: nomeFinal,
            valor: interpretado.valor,
            nomeDaConta: conta?.nome,
            agora: agora,
            entre: Array(recentes)
        ) else {
            return .result()
        }

        let proposta = PropostaDeTransacao(
            valor: interpretado.valor,
            tipo: interpretado.tipo,
            descricao: nomeFinal,
            loja: nomeFinal,
            nomeDaCategoria: nil,
            data: agora
        )
        let nomeDaCategoria = HojeViewModel.categoriaSugerida(
            para: proposta,
            textoOriginal: nomeFinal,
            categoriaDoInterpretador: nil,
            categorias: categorias
        )

        let recorrentes = (try? contexto.fetch(FetchDescriptor<Recorrente>())) ?? []
        let recorrenteLigada = Recorrente.correspondente(descricao: nomeFinal, loja: nomeFinal, entre: recorrentes)
        let subida = recorrenteLigada?.subidaComNovoValor(interpretado.valor)
        let transacao = Transacao(
            valor: interpretado.valor,
            tipo: interpretado.tipo,
            descricao: nomeFinal,
            loja: nomeFinal,
            data: agora,
            categoria: categorias.first { $0.nome == nomeDaCategoria },
            conta: conta,
            recorrente: recorrenteLigada,
            origem: .applePay
        )
        recorrenteLigada?.ultimoPagamentoEm = agora
        contexto.insert(transacao)
        try? contexto.save()
        UserDefaults.standard.set(true, forKey: "recebeuPagamentoApplePay")
        if let recorrenteLigada, let subida {
            await NotificadorDeRecorrentes.avisarSubida(recorrenteLigada, subida: subida)
        }

        await NotificadorDePagamentos.avisarRegistado(transacao)
        return .result()
    }

    /// O cartão já conhecido aponta logo para a conta certa; um cartão novo
    /// fica provisoriamente na conta principal e pede para ser associado.
    @MainActor
    private func resolverConta(contexto: ModelContext, contas: [Conta]) -> Conta? {
        let principal = contas.first(where: \.principal) ?? contas.first
        guard let nomeDoCartao = nomeDoCartao?.trimmingCharacters(in: .whitespacesAndNewlines), !nomeDoCartao.isEmpty else {
            return principal
        }

        let cartoes = (try? contexto.fetch(FetchDescriptor<CartaoDaCarteira>())) ?? []
        if let conhecido = cartoes.first(where: { $0.nomeDoCartao == nomeDoCartao }) {
            return conhecido.conta ?? principal
        }

        contexto.insert(CartaoDaCarteira(nomeDoCartao: nomeDoCartao, conta: principal))
        try? contexto.save()
        Task { await NotificadorDePagamentos.avisarCartaoDesconhecido(nomeDoCartao: nomeDoCartao) }
        return principal
    }
}
