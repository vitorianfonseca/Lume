import Foundation

nonisolated enum ErroDeConselho: Error, Equatable {
    case semChave
    case semResposta(String)
    case produtoNaoEncontrado
}

/// O que a Lume responde antes de uma compra. Só campos — as contas do
/// orçamento ficam no `ImpactoDeCompra`, em Swift.
nonisolated struct Conselho: Equatable {
    var produto: String
    var precoAtual: Decimal?
    var precoNormal: Decimal?
    var precoMaisBarato: Decimal?
    var lojaMaisBarata: String?
    var nivel: NivelDePreco
    var veredicto: String
    var problemas: [String]
    var alternativaNome: String?
    var alternativaPreco: Decimal?
    var fontes: [FonteDePreco]
}

/// "Estou prestes a gastar dinheiro. Estou a fazer uma boa compra?"
///
/// O Claude pesquisa a web (preços em lojas portuguesas e o que os
/// compradores dizem) e devolve campos estruturados. Duas regras que não se
/// negociam: **nunca inventar preços** — sem fonte, o campo vem vazio — e
/// **citar sempre onde viu**, para a pessoa poder confirmar.
nonisolated struct ConselheiroDeCompras {
    let chave: String
    var modelo = "claude-opus-5"

    /// O que o modelo devolve. Preços como texto (""=não encontrado), para o
    /// dinheiro ser convertido em `Decimal` por nós e nunca por vírgula
    /// flutuante.
    struct RespostaDoModelo: Decodable, Equatable {
        var produto: String
        var precoAtual: String
        var precoNormal: String
        var precoMaisBarato: String
        var lojaMaisBarata: String
        var nivel: String
        var veredicto: String
        var problemas: [String]
        var alternativaNome: String
        var alternativaPreco: String
        var fontes: [Fonte]

        struct Fonte: Decodable, Equatable {
            var nome: String
            var endereco: String
        }
    }

    private struct Envelope: Decodable {
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

    private static let esquema: [String: Any] = [
        "type": "object",
        "properties": [
            "produto": ["type": "string", "description": "Nome do produto como é conhecido, com o modelo."],
            "precoAtual": ["type": "string", "description": "Preço mais comum hoje em lojas portuguesas, só dígitos e ponto decimal. Texto vazio se não encontrares."],
            "precoNormal": ["type": "string", "description": "Preço habitual/recomendado (PVP) quando não está em promoção. Vazio se não encontrares."],
            "precoMaisBarato": ["type": "string", "description": "O preço mais baixo que encontraste agora, com IVA e sem contar portes. Vazio se não encontrares."],
            "lojaMaisBarata": ["type": "string", "description": "Nome da loja do preço mais baixo. Vazio se não encontraste preço."],
            "nivel": ["type": "string", "enum": ["bom", "razoavel", "mau"], "description": "Compara o preço que a pessoa vai pagar com o que encontraste."],
            "veredicto": ["type": "string", "description": "Uma frase curta em português de Portugal, calma e direta, com o porquê. Exemplo: 'Bom preço, mas já esteve 40 € mais barato.'"],
            "problemas": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Até 3 queixas mais repetidas por quem comprou, cada uma em menos de 12 palavras. Só o que encontrares em análises reais.",
            ],
            "alternativaNome": ["type": "string", "description": "Um produto alternativo que faça sentido considerar, ou vazio."],
            "alternativaPreco": ["type": "string", "description": "Preço da alternativa, só dígitos e ponto decimal, ou vazio."],
            "fontes": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "nome": ["type": "string"],
                        "endereco": ["type": "string"],
                    ],
                    "required": ["nome", "endereco"],
                    "additionalProperties": false,
                ],
                "description": "As páginas onde viste os preços e as análises. Pelo menos uma se houver preços.",
            ],
        ],
        "required": [
            "produto", "precoAtual", "precoNormal", "precoMaisBarato", "lojaMaisBarata",
            "nivel", "veredicto", "problemas", "alternativaNome", "alternativaPreco", "fontes",
        ],
        "additionalProperties": false,
    ]

    private static let instrucoes = """
        És o conselheiro de compras da Lume. A pessoa está numa loja ou num site, \
        prestes a pagar, e quer uma segunda opinião em segundos.

        Pesquisa na web o preço do produto em lojas que vendem para Portugal e o \
        que dizem quem já comprou. Depois responde só com os campos pedidos.

        Regras que não se negociam:
        - Nunca inventes preços nem inventes queixas. Sem fonte, o campo fica vazio.
        - Preços em euros, com IVA, sem contar portes.
        - Cita sempre as páginas onde viste os preços e as análises.
        - As queixas são as mais repetidas por compradores reais, não defeitos teóricos.
        - Escreves em português de Portugal, num tom calmo e direto. Nunca julgas \
        a pessoa nem lhe dizes o que fazer: dás-lhe os factos e ela decide.
        """

    func avaliar(_ descricao: String, precoDaPessoa: Decimal?) async throws -> Conselho {
        let pergunta: String
        if let precoDaPessoa {
            pergunta = "Produto: \(descricao). Estou prestes a pagar \(Self.texto(precoDaPessoa)) €. É boa compra?"
        } else {
            pergunta = "Produto: \(descricao). Quanto custa e vale a pena?"
        }

        let corpo: [String: Any] = [
            "model": modelo,
            "max_tokens": 4096,
            // Pesquisa web com filtragem dinâmica: o modelo filtra os
            // resultados antes de os trazer para o contexto.
            "tools": [["type": "web_search_20260209", "name": "web_search"]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": Self.esquema,
                ],
            ],
            "system": Self.instrucoes,
            "messages": [["role": "user", "content": pergunta]],
        ]

        var pedido = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        pedido.httpMethod = "POST"
        pedido.timeoutInterval = 60
        pedido.setValue("application/json", forHTTPHeaderField: "content-type")
        pedido.setValue(chave, forHTTPHeaderField: "x-api-key")
        pedido.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        let dados: Data
        let resposta: URLResponse
        do {
            (dados, resposta) = try await URLSession.shared.data(for: pedido)
        } catch {
            throw ErroDeConselho.semResposta(String(describing: error))
        }

        guard let http = resposta as? HTTPURLResponse, http.statusCode == 200 else {
            let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
            throw ErroDeConselho.semResposta("HTTP \(codigo) da API da Anthropic")
        }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: dados),
              envelope.stopReason != "refusal",
              // Com ferramentas de servidor, o texto final é o último bloco de texto.
              let json = envelope.content.last(where: { $0.type == "text" })?.text,
              let interpretada = try? JSONDecoder().decode(RespostaDoModelo.self, from: Data(json.utf8)) else {
            throw ErroDeConselho.semResposta("Resposta inesperada do Claude")
        }

        return try Self.conselho(de: interpretada)
    }

    // MARK: - Conversões determinísticas (testáveis sem rede)

    static func conselho(de resposta: RespostaDoModelo) throws -> Conselho {
        guard !resposta.produto.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ErroDeConselho.produtoNaoEncontrado
        }

        return Conselho(
            produto: resposta.produto,
            precoAtual: decimal(resposta.precoAtual),
            precoNormal: decimal(resposta.precoNormal),
            precoMaisBarato: decimal(resposta.precoMaisBarato),
            lojaMaisBarata: resposta.lojaMaisBarata.isEmpty ? nil : resposta.lojaMaisBarata,
            nivel: NivelDePreco(rawValue: resposta.nivel) ?? .razoavel,
            veredicto: resposta.veredicto,
            // Até três, e sem entradas vazias — o design mostra três linhas.
            problemas: resposta.problemas
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { $0 },
            alternativaNome: resposta.alternativaNome.isEmpty ? nil : resposta.alternativaNome,
            alternativaPreco: decimal(resposta.alternativaPreco),
            fontes: resposta.fontes
                .filter { !$0.endereco.isEmpty }
                .map { FonteDePreco(nome: $0.nome, endereco: $0.endereco) }
        )
    }

    /// Dinheiro nunca passa por vírgula flutuante: texto direto para `Decimal`.
    static func decimal(_ texto: String) -> Decimal? {
        let limpo = texto
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !limpo.isEmpty,
              let valor = Decimal(string: limpo, locale: Locale(identifier: "en_US_POSIX")),
              valor > .zero else { return nil }
        return valor
    }

    private static func texto(_ valor: Decimal) -> String {
        valor.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "pt_PT")))
    }
}
