import AppIntents
import SwiftData

/// "Regista 3 euros no café no Lume" — a Siri e a app Atalhos entregam a
/// frase, o interpretador por regras faz as contas e a despesa fica
/// guardada, tal como no separador Registar. Sem rede, sem IA remota.
struct RegistarDespesaIntent: AppIntent {
    static let title: LocalizedStringResource = "Registar despesa"
    static let description = IntentDescription(
        "Regista uma despesa escrita numa frase, como \"café 1,20\" ou \"gastei 12,50 no almoço\"."
    )
    static let openAppWhenRun = false

    @Parameter(title: "O que gastaste?", requestValueDialog: "O que gastaste?")
    var frase: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let contentor = ContentorDeDados.producao()
        let contexto = contentor.mainContext

        let categorias = try contexto.fetch(FetchDescriptor<Categoria>())
        let contas = try contexto.fetch(FetchDescriptor<Conta>())

        let proposta: PropostaDeTransacao
        do {
            proposta = try await InterpretadorPorRegras().interpretar(
                frase,
                categorias: categorias.map(\.nome),
                hoje: .now
            )
        } catch {
            return .result(dialog: "Não encontrei um valor nessa frase. Tenta, por exemplo, \"café 1,20\".")
        }

        let transacao = Transacao(
            valor: proposta.valor,
            tipo: proposta.tipo,
            descricao: proposta.descricao,
            loja: proposta.loja,
            data: proposta.data,
            categoria: categorias.first { $0.nome == proposta.nomeDaCategoria },
            conta: contas.first(where: \.principal) ?? contas.first,
            origem: .texto
        )
        contexto.insert(transacao)
        try contexto.save()

        let valor = FormatadorDeMoeda.texto(proposta.valor)
        let categoria = proposta.nomeDaCategoria.map { " em \($0)" } ?? ""
        return .result(dialog: "Guardado: \(valor)\(categoria).")
    }
}

/// As frases que a Siri reconhece sem configurar nada.
struct AtalhosDaLume: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegistarDespesaIntent(),
            phrases: [
                "Regista uma despesa no \(.applicationName)",
                "Registar despesa no \(.applicationName)",
                "Apontar um gasto no \(.applicationName)",
            ],
            shortTitle: "Registar despesa",
            systemImageName: "plus.square.fill"
        )
    }
}
