import Foundation

/// Interpretador Premium: o Claude (API da Anthropic) transforma a frase
/// em campos estruturados. Como os outros interpretadores, nunca faz contas —
/// o valor e a data chegam como texto e são convertidos em Swift determinístico.
/// Usa structured outputs (`output_config.format`), que garante JSON válido.
nonisolated struct InterpretadorClaude: InterpretadorDeDespesas {
    let chave: String
    var modelo = "claude-opus-5"

    /// O que o modelo devolve. Campos sem valor vêm como texto vazio.
    struct DespesaDoClaude: Decodable, Equatable {
        var valor: String
        var tipo: String
        var descricao: String
        var loja: String
        var categoria: String
        var dataRelativa: String
    }

    private struct Resposta: Decodable {
        struct Bloco: Decodable {
            let type: String
            let text: String?
        }

        let content: [Bloco]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    func interpretar(_ texto: String, categorias: [String], hoje: Date) async throws -> PropostaDeTransacao {
        let corpo: [String: Any] = [
            "model": modelo,
            "max_tokens": 1024,
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "valor": ["type": "string", "description": "Valor em euros, só dígitos e ponto decimal, sem símbolo. Converte cêntimos para euros: '80 cêntimos' é '0.80'."],
                            "tipo": ["type": "string", "enum": ["despesa", "receita"]],
                            "descricao": ["type": "string", "description": "Descrição curta, 1 a 3 palavras em português."],
                            "loja": ["type": "string", "description": "Nome do estabelecimento, ou texto vazio se não for mencionado."],
                            "categoria": ["type": "string", "description": "Exatamente um nome da lista das instruções, ou texto vazio se nenhum servir."],
                            "dataRelativa": ["type": "string", "description": "'hoje', 'ontem', 'anteontem', ou a data mencionada como AAAA-MM-DD. Nunca calcules datas."],
                        ],
                        "required": ["valor", "tipo", "descricao", "loja", "categoria", "dataRelativa"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "system": """
                Extrais os dados de UMA transação financeira a partir de uma frase \
                em português de Portugal. Não fazes contas: só transformas texto em campos. \
                A única conversão permitida é cêntimos para euros. \
                Categorias existentes (escolhe só destas, ou nenhuma): \
                \(categorias.joined(separator: ", ")).
                """,
            "messages": [["role": "user", "content": texto]],
        ]

        var pedido = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "content-type")
        pedido.setValue(chave, forHTTPHeaderField: "x-api-key")
        pedido.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        let dados: Data
        let resposta: URLResponse
        do {
            (dados, resposta) = try await URLSession.shared.data(for: pedido)
        } catch {
            throw ErroDeInterpretacao.falhaDoModelo(String(describing: error))
        }

        guard let http = resposta as? HTTPURLResponse, http.statusCode == 200 else {
            let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
            throw ErroDeInterpretacao.falhaDoModelo("HTTP \(codigo) da API da Anthropic")
        }

        guard let corpoDaResposta = try? JSONDecoder().decode(Resposta.self, from: dados),
              corpoDaResposta.stopReason != "refusal",
              let json = corpoDaResposta.content.first(where: { $0.type == "text" })?.text,
              let interpretada = try? JSONDecoder().decode(DespesaDoClaude.self, from: Data(json.utf8)) else {
            throw ErroDeInterpretacao.falhaDoModelo("Resposta inesperada do Claude")
        }

        return try Self.proposta(de: interpretada, categorias: categorias, hoje: hoje)
    }

    /// Conversões e validações determinísticas — testáveis sem rede,
    /// iguais às do interpretador Foundation Models.
    static func proposta(
        de interpretada: DespesaDoClaude,
        categorias: [String],
        hoje: Date
    ) throws -> PropostaDeTransacao {
        let normalizado = interpretada.valor.replacingOccurrences(of: ",", with: ".")
        guard let valor = Decimal(string: normalizado, locale: Locale(identifier: "en_US_POSIX")),
              valor > .zero else {
            throw ErroDeInterpretacao.textoSemValor
        }

        let categoriaValidada = interpretada.categoria.isEmpty ? nil : categorias.first {
            $0.compare(interpretada.categoria, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        return PropostaDeTransacao(
            valor: valor,
            tipo: TipoTransacao(rawValue: interpretada.tipo) ?? .despesa,
            descricao: interpretada.descricao,
            loja: interpretada.loja.isEmpty ? nil : interpretada.loja,
            nomeDaCategoria: categoriaValidada,
            data: ResolutorDeDatas.resolver(interpretada.dataRelativa, emRelacaoA: hoje)
        )
    }
}
