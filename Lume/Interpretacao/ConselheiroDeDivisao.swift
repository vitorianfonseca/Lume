import Foundation
import FoundationModels

// MARK: - O que a pessoa responde

/// As respostas do questionário "Dividir à minha medida". Guardadas no
/// dispositivo para a próxima divisão começar já preenchida.
nonisolated struct RespostasDaDivisao: Codable, Equatable, Sendable {
    enum Agregado: String, Codable, CaseIterable, Sendable {
        case sozinho, casal, filhos, familia

        var titulo: String {
            switch self {
            case .sozinho: "Sozinho/a"
            case .casal: "Em casal"
            case .filhos: "Com filhos"
            case .familia: "Com a família"
            }
        }
    }

    enum Objetivo: String, Codable, CaseIterable, Sendable {
        case emergencia, meta, dividas, viver, investir

        var titulo: String {
            switch self {
            case .emergencia: "Criar um fundo de emergência"
            case .meta: "Juntar para um objetivo"
            case .dividas: "Pagar dívidas mais depressa"
            case .viver: "Viver o mês com mais folga"
            case .investir: "Começar a investir"
            }
        }
    }

    enum Estilo: String, Codable, CaseIterable, Sendable {
        case rigoroso, equilibrado, folgado

        var titulo: String {
            switch self {
            case .rigoroso: "Rigoroso"
            case .equilibrado: "Equilibrado"
            case .folgado: "Com folga"
            }
        }

        var detalhe: String {
            switch self {
            case .rigoroso: "Limites apertados, cada euro com destino."
            case .equilibrado: "Algum aperto, alguma margem."
            case .folgado: "Limites largos, menos preocupações."
            }
        }
    }

    enum Rendimento: String, Codable, CaseIterable, Sendable {
        case fixo, variavel

        var titulo: String {
            switch self {
            case .fixo: "Sempre igual"
            case .variavel: "Varia de mês para mês"
            }
        }
    }

    enum Prioridade: String, Codable, CaseIterable, Sendable {
        case essencial, normal, cortar

        var titulo: String {
            switch self {
            case .essencial: "Essencial"
            case .normal: "Normal"
            case .cortar: "Posso cortar"
            }
        }
    }

    var agregado: Agregado = .sozinho
    /// Renda ou prestação da casa, por mês.
    var habitacao: Decimal = .zero
    /// Créditos e outras dívidas, por mês.
    var dividas: Decimal = .zero
    var objetivo: Objetivo = .emergencia
    var metaEscolhida: String?
    /// Percentagem do recebido a guardar; `nil` = "o que sobrar".
    var percentagemDePoupanca: Int? = 10
    /// Pelo nome da categoria.
    var prioridades: [String: Prioridade] = [:]
    var estilo: Estilo = .equilibrado
    var rendimento: Rendimento = .fixo
    /// "Vou de férias em agosto", "o carro precisa de revisão"…
    var nota: String = ""

    static let chave = "respostasDaDivisao"

    static func guardadas() -> RespostasDaDivisao? {
        guard let dados = UserDefaults.standard.data(forKey: chave) else { return nil }
        return try? JSONDecoder().decode(RespostasDaDivisao.self, from: dados)
    }

    func guardar() {
        guard let dados = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(dados, forKey: Self.chave)
    }
}

// MARK: - O que a app já sabe

/// Os factos que a Lume tira dos dados, para a divisão não ser às cegas.
nonisolated struct ContextoDaDivisao: Sendable {
    struct CategoriaNoContexto: Sendable {
        var nome: String
        var limiteAtual: Decimal?
        /// Média gasta por mês nos últimos 3 meses completos.
        var mediaGasta: Decimal
        /// Contas fixas ativas desta categoria (renda, EDP, Netflix…).
        var fixos: Decimal
    }

    struct MetaNoContexto: Sendable {
        var nome: String
        var falta: Decimal
        var mesesAtePrazo: Int?
    }

    var total: Decimal
    var categorias: [CategoriaNoContexto]
    var metas: [MetaNoContexto]
}

// MARK: - O que a Lume propõe

nonisolated struct PropostaDeDivisao: Equatable, Sendable {
    struct Parte: Equatable, Sendable {
        var categoria: String
        var valor: Decimal
        var motivo: String
    }

    var partes: [Parte]
    var poupanca: Decimal
    var motivoDaPoupanca: String
    /// Duas ou três frases a explicar a lógica da divisão.
    var resumo: String
    /// Quem fez a divisão ("Claude", "No iPhone", "Regras").
    var autor: String

    /// Quem fez a proposta, em linguagem de pessoa, para o cartão do resumo.
    var autoria: String {
        switch autor {
        case "Claude": "Proposta do Claude"
        case "No iPhone": "Proposta feita no iPhone"
        case "Regras": "Proposta pelas regras da Lume"
        default: "Proposta · \(autor)"
        }
    }
}

nonisolated protocol ConselheiroDeDivisao: Sendable {
    func propor(_ respostas: RespostasDaDivisao, contexto: ContextoDaDivisao) async throws -> PropostaDeDivisao
}

nonisolated enum ErroDeDivisao: Error {
    case semResposta(String)
}

// MARK: - O pedido ao modelo (partilhado pelo Claude e pelo modelo local)

nonisolated enum PedidoDeDivisao {
    static let instrucoes = """
        És a conselheira financeira da Lume, uma app portuguesa de finanças pessoais. \
        A pessoa acabou de receber dinheiro e quer dividi-lo pelas categorias do mês \
        de acordo com a vida dela, os interesses e os objetivos que indicou.

        Como dividir:
        - Começa pelas contas fixas: cada categoria recebe pelo menos o valor das suas contas fixas.
        - Usa a média gasta como referência realista; só cortes nas categorias que a pessoa \
        disse que pode cortar, e protege as essenciais.
        - A habitação e as dívidas indicadas são compromissos: vão para a categoria que \
        melhor lhes corresponde (por exemplo "Casa"), se existir.
        - A poupança segue a percentagem pedida; se for "o que sobrar", guarda o que \
        fica depois de cobrir o mês com realismo. Se o objetivo tem prazo, tenta \
        respeitá-lo e diz se não for possível.
        - O estilo muda a margem: rigoroso = limites justos; com folga = limites largos.
        - A soma das categorias e da poupança nunca passa do total recebido.
        - Valores em euros inteiros, só dígitos.
        - Os motivos são curtos (até 12 palavras), concretos e referem os dados \
        da pessoa. Português de Portugal, tom calmo, sem julgar.
        """

    static func descricao(_ r: RespostasDaDivisao, _ c: ContextoDaDivisao) -> String {
        var linhas = ["Total recebido para dividir: \(euros(c.total)) €."]
        linhas.append("Vive: \(r.agregado.titulo.lowercased()). Rendimento: \(r.rendimento.titulo.lowercased()).")
        if r.habitacao > .zero { linhas.append("Renda ou prestação da casa: \(euros(r.habitacao)) € por mês.") }
        if r.dividas > .zero { linhas.append("Créditos e dívidas: \(euros(r.dividas)) € por mês.") }
        var objetivo = "Objetivo principal: \(r.objetivo.titulo.lowercased())"
        if r.objetivo == .meta, let meta = r.metaEscolhida { objetivo += " (\(meta))" }
        linhas.append(objetivo + ".")
        if let pct = r.percentagemDePoupanca {
            linhas.append("Quer poupar \(pct)% do que recebe.")
        } else {
            linhas.append("Quer poupar o que sobrar.")
        }
        linhas.append("Estilo: \(r.estilo.titulo.lowercased()) — \(r.estilo.detalhe)")

        linhas.append("\nCategorias (usa exatamente estes nomes):")
        for categoria in c.categorias {
            var linha = "- \(categoria.nome): média gasta \(euros(categoria.mediaGasta)) €/mês"
            if let limite = categoria.limiteAtual { linha += ", limite atual \(euros(limite)) €" }
            if categoria.fixos > .zero { linha += ", contas fixas \(euros(categoria.fixos)) €" }
            let prioridade = r.prioridades[categoria.nome] ?? .normal
            linha += ", prioridade: \(prioridade.titulo.lowercased())"
            linhas.append(linha)
        }

        if !c.metas.isEmpty {
            linhas.append("\nObjetivos de poupança:")
            for meta in c.metas {
                var linha = "- \(meta.nome): faltam \(euros(meta.falta)) €"
                if let meses = meta.mesesAtePrazo { linha += ", prazo daqui a \(meses) meses" }
                linhas.append(linha)
            }
        }

        let nota = r.nota.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nota.isEmpty { linhas.append("\nNota da pessoa: \(nota)") }
        return linhas.joined(separator: "\n")
    }

    static func euros(_ valor: Decimal) -> String {
        valor.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US_POSIX")).grouping(.never))
    }
}

// MARK: - Validação determinística (testável sem modelo)

nonisolated enum AjusteDaDivisao {
    struct ParteBruta: Sendable {
        var categoria: String
        var valor: String
        var motivo: String
    }

    /// O modelo propõe; o Swift garante as regras: nomes reais, euros
    /// inteiros, contas fixas cobertas, soma ≤ total e o resto na poupança.
    static func ajustar(
        partes: [ParteBruta],
        poupanca: String,
        motivoDaPoupanca: String,
        resumo: String,
        autor: String,
        contexto: ContextoDaDivisao
    ) -> PropostaDeDivisao {
        let total = inteiro(contexto.total)
        var valores: [String: Decimal] = [:]
        var motivos: [String: String] = [:]
        for parte in partes {
            guard let nome = contexto.categorias.first(where: {
                $0.nome.compare(parte.categoria, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            })?.nome else { continue }
            valores[nome, default: .zero] += inteiro(decimal(parte.valor) ?? .zero)
            motivos[nome] = parte.motivo
        }
        // As contas fixas ficam sempre cobertas.
        for categoria in contexto.categorias where categoria.fixos > .zero {
            let minimo = arredondarParaCima(categoria.fixos)
            if (valores[categoria.nome] ?? .zero) < minimo {
                valores[categoria.nome] = minimo
                if motivos[categoria.nome]?.isEmpty ?? true { motivos[categoria.nome] = "Cobre as contas fixas." }
            }
        }

        var guardar = inteiro(decimal(poupanca) ?? .zero)
        let gastos = valores.values.reduce(Decimal.zero, +)
        if gastos > total {
            // Passou do total: reduz a parte variável de cada categoria, na proporção.
            let fixos = contexto.categorias.reduce(into: [String: Decimal]()) { $0[$1.nome] = arredondarParaCima($1.fixos) }
            let somaFixos = valores.keys.reduce(Decimal.zero) { $0 + min(fixos[$1] ?? .zero, valores[$1] ?? .zero) }
            let variavel = gastos - somaFixos
            let espaco = max(total - somaFixos, .zero)
            for (nome, valor) in valores {
                let fixo = min(fixos[nome] ?? .zero, valor)
                let extra = variavel > .zero ? inteiro((valor - fixo) * espaco / variavel) : .zero
                valores[nome] = fixo + extra
            }
            guardar = .zero
        }
        let usado = valores.values.reduce(Decimal.zero, +)
        guardar = min(guardar, max(total - usado, .zero))
        // O que sobrar dos arredondamentos ou do modelo vai para a poupança.
        let sobra = total - usado - guardar
        if sobra > .zero { guardar += sobra }

        let partesFinais = contexto.categorias.map { categoria in
            PropostaDeDivisao.Parte(
                categoria: categoria.nome,
                valor: valores[categoria.nome] ?? .zero,
                motivo: motivos[categoria.nome] ?? ""
            )
        }
        return PropostaDeDivisao(
            partes: partesFinais,
            poupanca: guardar,
            motivoDaPoupanca: motivoDaPoupanca,
            resumo: resumo,
            autor: autor
        )
    }

    static func decimal(_ texto: String) -> Decimal? {
        let limpo = texto
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let valor = Decimal(string: limpo, locale: Locale(identifier: "en_US_POSIX")), valor >= .zero else {
            return nil
        }
        return valor
    }

    static func inteiro(_ valor: Decimal) -> Decimal {
        var origem = valor
        var resultado = Decimal()
        NSDecimalRound(&resultado, &origem, 0, .down)
        return resultado
    }

    static func arredondarParaCima(_ valor: Decimal) -> Decimal {
        var origem = valor
        var resultado = Decimal()
        NSDecimalRound(&resultado, &origem, 0, .up)
        return resultado
    }
}

// MARK: - Claude

nonisolated struct DivisaoPorClaude: ConselheiroDeDivisao {
    let chave: String
    var modelo = "claude-opus-5"

    private struct Resposta: Decodable {
        struct Parte: Decodable {
            var categoria: String
            var valor: String
            var motivo: String
        }

        var partes: [Parte]
        var poupanca: String
        var motivoDaPoupanca: String
        var resumo: String
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
            "partes": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "categoria": ["type": "string", "description": "Nome exato de uma categoria da lista."],
                        "valor": ["type": "string", "description": "Euros inteiros, só dígitos."],
                        "motivo": ["type": "string", "description": "Porquê, em até 12 palavras."],
                    ],
                    "required": ["categoria", "valor", "motivo"],
                    "additionalProperties": false,
                ],
                "description": "Uma entrada por categoria da lista.",
            ],
            "poupanca": ["type": "string", "description": "Euros inteiros a guardar, só dígitos."],
            "motivoDaPoupanca": ["type": "string", "description": "Porquê, em até 12 palavras."],
            "resumo": ["type": "string", "description": "Duas ou três frases a explicar a lógica da divisão."],
        ],
        "required": ["partes", "poupanca", "motivoDaPoupanca", "resumo"],
        "additionalProperties": false,
    ]

    func propor(_ respostas: RespostasDaDivisao, contexto: ContextoDaDivisao) async throws -> PropostaDeDivisao {
        let corpo: [String: Any] = [
            "model": modelo,
            "max_tokens": 4096,
            "output_config": ["format": ["type": "json_schema", "schema": Self.esquema]],
            "system": PedidoDeDivisao.instrucoes,
            "messages": [["role": "user", "content": PedidoDeDivisao.descricao(respostas, contexto)]],
        ]

        var pedido = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        pedido.httpMethod = "POST"
        pedido.timeoutInterval = 60
        pedido.setValue("application/json", forHTTPHeaderField: "content-type")
        pedido.setValue(chave, forHTTPHeaderField: "x-api-key")
        pedido.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        guard (resposta as? HTTPURLResponse)?.statusCode == 200,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: dados),
              envelope.stopReason != "refusal",
              let json = envelope.content.last(where: { $0.type == "text" })?.text,
              let lida = try? JSONDecoder().decode(Resposta.self, from: Data(json.utf8)) else {
            throw ErroDeDivisao.semResposta("Resposta inesperada do Claude")
        }

        return AjusteDaDivisao.ajustar(
            partes: lida.partes.map { .init(categoria: $0.categoria, valor: $0.valor, motivo: $0.motivo) },
            poupanca: lida.poupanca,
            motivoDaPoupanca: lida.motivoDaPoupanca,
            resumo: lida.resumo,
            autor: "Claude",
            contexto: contexto
        )
    }
}

// MARK: - Modelo no iPhone

@Generable(description: "Quanto vai para uma categoria")
nonisolated struct ParteGerada {
    @Guide(description: "Nome exato de uma categoria da lista.")
    var categoria: String
    @Guide(description: "Euros inteiros, só dígitos.")
    var valor: String
    @Guide(description: "Porquê, em até 12 palavras, em português de Portugal.")
    var motivo: String
}

@Generable(description: "A divisão do dinheiro recebido pelas categorias e pela poupança")
nonisolated struct DivisaoGerada {
    @Guide(description: "Uma entrada por categoria da lista.")
    var partes: [ParteGerada]
    @Guide(description: "Euros inteiros a guardar, só dígitos.")
    var poupanca: String
    @Guide(description: "Porquê, em até 12 palavras.")
    var motivoDaPoupanca: String
    @Guide(description: "Duas ou três frases a explicar a lógica da divisão.")
    var resumo: String
}

nonisolated struct DivisaoNoDispositivo: ConselheiroDeDivisao {
    func propor(_ respostas: RespostasDaDivisao, contexto: ContextoDaDivisao) async throws -> PropostaDeDivisao {
        let sessao = LanguageModelSession(instructions: PedidoDeDivisao.instrucoes)
        let gerada = try await sessao.respond(
            to: PedidoDeDivisao.descricao(respostas, contexto),
            generating: DivisaoGerada.self
        ).content
        return AjusteDaDivisao.ajustar(
            partes: gerada.partes.map { .init(categoria: $0.categoria, valor: $0.valor, motivo: $0.motivo) },
            poupanca: gerada.poupanca,
            motivoDaPoupanca: gerada.motivoDaPoupanca,
            resumo: gerada.resumo,
            autor: "No iPhone",
            contexto: contexto
        )
    }
}

// MARK: - Regras (rede de segurança, sem modelo)

/// Sem IA disponível, divide com as mesmas regras de forma explícita:
/// contas fixas primeiro, poupança pela resposta, e o resto pela média
/// gasta ajustada às prioridades e ao estilo.
nonisolated struct DivisaoPorRegras: ConselheiroDeDivisao {
    func propor(_ respostas: RespostasDaDivisao, contexto: ContextoDaDivisao) async throws -> PropostaDeDivisao {
        let total = AjusteDaDivisao.inteiro(contexto.total)
        let percentagem = respostas.percentagemDePoupanca ?? 0
        let poupanca = AjusteDaDivisao.inteiro(total * Decimal(percentagem) / 100)
        let margem: Decimal = switch respostas.estilo {
        case .rigoroso: 0.95
        case .equilibrado: 1.05
        case .folgado: 1.15
        }

        var partes: [AjusteDaDivisao.ParteBruta] = []
        for categoria in contexto.categorias {
            let prioridade = respostas.prioridades[categoria.nome] ?? .normal
            let fator: Decimal = switch prioridade {
            case .essencial: 1.1
            case .normal: 1
            case .cortar: 0.7
            }
            var base = max(categoria.mediaGasta, categoria.limiteAtual ?? .zero)
            if categoria.nome.localizedCaseInsensitiveContains("casa") || categoria.nome.localizedCaseInsensitiveContains("habita") {
                base = max(base, respostas.habitacao + respostas.dividas)
            }
            let valor = max(base * fator * margem, categoria.fixos)
            let motivo: String = switch prioridade {
            case .essencial: "Essencial para ti: com margem sobre a média."
            case .cortar: "Disseste que podes cortar: abaixo da média."
            case .normal: categoria.fixos > .zero ? "Cobre as contas fixas e a média." : "Perto do que costumas gastar."
            }
            partes.append(.init(categoria: categoria.nome, valor: AjusteDaDivisao.euros(valor), motivo: motivo))
        }

        return AjusteDaDivisao.ajustar(
            partes: escalar(partes, para: total - poupanca),
            poupanca: AjusteDaDivisao.euros(poupanca),
            motivoDaPoupanca: respostas.percentagemDePoupanca.map { "\($0)% do recebido, como pediste." } ?? "O que sobra depois do mês.",
            resumo: "Contas fixas primeiro, depois a poupança que escolheste, e o resto pela tua média de gastos ajustada às prioridades (\(respostas.estilo.titulo.lowercased())).",
            autor: "Regras",
            contexto: contexto
        )
    }

    /// Se as categorias pedem mais do que o espaço que há, reduz na proporção.
    private func escalar(_ partes: [AjusteDaDivisao.ParteBruta], para espaco: Decimal) -> [AjusteDaDivisao.ParteBruta] {
        let soma = partes.reduce(Decimal.zero) { $0 + (AjusteDaDivisao.decimal($1.valor) ?? .zero) }
        guard soma > espaco, soma > .zero else { return partes }
        return partes.map { parte in
            var nova = parte
            nova.valor = AjusteDaDivisao.euros((AjusteDaDivisao.decimal(parte.valor) ?? .zero) * espaco / soma)
            return nova
        }
    }
}

extension AjusteDaDivisao {
    nonisolated static func euros(_ valor: Decimal) -> String { PedidoDeDivisao.euros(inteiro(valor)) }
}

// MARK: - Escolha do conselheiro

/// Claude quando há chave, o modelo do iPhone quando existe, e as regras
/// sempre como rede de segurança: a divisão nunca fica por fazer.
nonisolated struct DivisaoComRecurso: ConselheiroDeDivisao {
    let cadeia: [any ConselheiroDeDivisao]

    func propor(_ respostas: RespostasDaDivisao, contexto: ContextoDaDivisao) async throws -> PropostaDeDivisao {
        var ultimoErro: Error = ErroDeDivisao.semResposta("Sem conselheiros")
        for conselheiro in cadeia {
            do {
                return try await conselheiro.propor(respostas, contexto: contexto)
            } catch {
                ultimoErro = error
            }
        }
        throw ultimoErro
    }

    static func padrao() -> DivisaoComRecurso {
        var cadeia: [any ConselheiroDeDivisao] = []
        if let chave = CofreDeChaves.ler(CofreDeChaves.contaClaude), !chave.isEmpty {
            cadeia.append(DivisaoPorClaude(chave: chave))
        }
        if case .available = SystemLanguageModel.default.availability {
            cadeia.append(DivisaoNoDispositivo())
        }
        cadeia.append(DivisaoPorRegras())
        return DivisaoComRecurso(cadeia: cadeia)
    }
}
