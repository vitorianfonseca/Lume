import Foundation
import FoundationModels

/// O que o modelo devolve: só texto estruturado. Valores, datas e validação
/// de categorias são resolvidos em Swift determinístico.
@Generable(description: "Uma transação extraída de uma frase em português")
nonisolated struct DespesaInterpretada {
    @Guide(description: "Valor em euros, só dígitos e ponto decimal, sem símbolo. Converte cêntimos para euros: '80 cêntimos' é '0.80'.")
    var valor: String

    @Guide(description: "'despesa' se saiu dinheiro, 'receita' se entrou.")
    var tipo: String

    @Guide(description: "Descrição curta, 1 a 3 palavras em português.")
    var descricao: String

    @Guide(description: "Nome do estabelecimento, se for mencionado.")
    var loja: String?

    @Guide(description: "Escolhe exatamente um nome da lista de categorias das instruções; omite se nenhum servir.")
    var categoria: String?

    @Guide(description: "'hoje', 'ontem', 'anteontem', ou a data mencionada como AAAA-MM-DD. Nunca calcules datas.")
    var dataRelativa: String
}

nonisolated struct InterpretadorFoundationModels: InterpretadorDeDespesas {

    func interpretar(_ texto: String, categorias: [String], hoje: Date) async throws -> PropostaDeTransacao {
        let sessao = LanguageModelSession(instructions: """
            Extrais os dados de UMA transação financeira a partir de uma frase \
            em português de Portugal. Não fazes contas: só transformas texto em campos. \
            A única conversão permitida é cêntimos para euros. \
            Categorias existentes (escolhe só destas, ou nenhuma): \
            \(categorias.joined(separator: ", ")).
            """)

        let interpretada: DespesaInterpretada
        do {
            interpretada = try await sessao.respond(to: texto, generating: DespesaInterpretada.self).content
        } catch {
            throw ErroDeInterpretacao.falhaDoModelo(String(describing: error))
        }

        // Daqui para baixo é tudo Swift determinístico: conversão do valor,
        // resolução da data e validação da categoria contra a lista real.
        let normalizado = interpretada.valor.replacingOccurrences(of: ",", with: ".")
        guard let valor = Decimal(string: normalizado, locale: Locale(identifier: "en_US_POSIX")),
              valor > .zero else {
            throw ErroDeInterpretacao.textoSemValor
        }

        let categoriaValidada = interpretada.categoria.flatMap { nome in
            categorias.first { $0.compare(nome, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }

        return PropostaDeTransacao(
            valor: valor,
            tipo: TipoTransacao(rawValue: interpretada.tipo) ?? .despesa,
            descricao: interpretada.descricao,
            loja: interpretada.loja,
            nomeDaCategoria: categoriaValidada,
            data: ResolutorDeDatas.resolver(interpretada.dataRelativa, emRelacaoA: hoje)
        )
    }
}

/// Tenta o interpretador principal e, se ele falhar, recorre à alternativa.
/// A app nunca fica sem registo por texto.
nonisolated struct InterpretadorComRecurso: InterpretadorDeDespesas {
    let principal: any InterpretadorDeDespesas
    let alternativa: any InterpretadorDeDespesas

    func interpretar(_ texto: String, categorias: [String], hoje: Date) async throws -> PropostaDeTransacao {
        do {
            return try await principal.interpretar(texto, categorias: categorias, hoje: hoje)
        } catch {
            return try await alternativa.interpretar(texto, categorias: categorias, hoje: hoje)
        }
    }
}

nonisolated enum FabricaDeInterpretadores {
    /// Foundation Models quando o dispositivo o suporta, senão regras.
    /// No Premium, o Claude entra aqui como mais uma implementação.
    static func padrao() -> any InterpretadorDeDespesas {
        switch SystemLanguageModel.default.availability {
        case .available:
            InterpretadorComRecurso(
                principal: InterpretadorFoundationModels(),
                alternativa: InterpretadorPorRegras()
            )
        case .unavailable:
            InterpretadorPorRegras()
        }
    }
}
