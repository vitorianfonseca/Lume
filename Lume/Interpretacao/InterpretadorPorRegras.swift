import Foundation

/// Alternativa determinística ao modelo de linguagem: regex e heurísticas.
/// Garante que o registo por texto funciona sempre — no simulador,
/// sem Apple Intelligence, ou se o modelo falhar.
nonisolated struct InterpretadorPorRegras: InterpretadorDeDespesas {

    func interpretar(_ texto: String, categorias: [String], hoje: Date) async throws -> PropostaDeTransacao {
        let minusculas = texto.lowercased()

        guard let valor = Self.extrairValor(de: minusculas) else {
            throw ErroDeInterpretacao.textoSemValor
        }

        let tipo: TipoTransacao = Self.palavrasDeReceita.contains(where: minusculas.contains)
            ? .receita
            : .despesa

        // "anteontem" primeiro, porque contém "ontem".
        let palavraDeData = ["anteontem", "ontem"].first(where: minusculas.contains) ?? "hoje"
        let data = ResolutorDeDatas.resolver(palavraDeData, emRelacaoA: hoje)

        return PropostaDeTransacao(
            valor: valor,
            tipo: tipo,
            descricao: Self.extrairDescricao(de: texto, tipo: tipo),
            loja: Self.extrairLoja(de: minusculas),
            nomeDaCategoria: Self.extrairCategoria(de: minusculas, entre: categorias),
            data: data
        )
    }

    // MARK: - Valor

    private static func extrairValor(de texto: String) -> Decimal? {
        // "80 cêntimos" antes do caso geral, senão o 80 seria lido como euros.
        if let centimos = texto.firstMatch(of: /(\d+)\s*c[êe]nt/),
           let inteiro = Int(centimos.1) {
            return Decimal(inteiro) / 100
        }
        if let numero = texto.firstMatch(of: /(\d+(?:[.,]\d{1,2})?)/) {
            let normalizado = numero.1.replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalizado, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }

    // MARK: - Heurísticas de texto

    private static let palavrasDeReceita = [
        "recebi", "salário", "salario", "ordenado", "reembolso", "prémio", "premio",
    ]

    private static let palavrasIgnoradas: Set<String> = [
        "gastei", "paguei", "comprei", "recebi", "dei", "foi", "foram",
        "hoje", "ontem", "anteontem",
        "€", "eur", "euro", "euros", "cêntimos", "centimos",
        "no", "na", "nos", "nas", "em", "de", "do", "da", "o", "a", "os", "as",
        "um", "uma", "por", "com", "e", "para",
    ]

    private static func extrairDescricao(de texto: String, tipo: TipoTransacao) -> String {
        let palavras = texto
            .split(separator: " ")
            .map(String.init)
            .filter { palavra in
                let limpa = palavra.lowercased().trimmingCharacters(in: .punctuationCharacters)
                let ehNumero = limpa.firstMatch(of: /^\d+(?:[.,]\d+)?€?$/) != nil
                return !ehNumero && !palavrasIgnoradas.contains(limpa) && !limpa.isEmpty
            }

        guard !palavras.isEmpty else {
            return tipo == .receita ? "Receita" : "Despesa"
        }
        return palavras.joined(separator: " ").capitalizarPrimeiraLetra()
    }

    private static let lojasConhecidas = [
        "pingo doce": "Pingo Doce", "continente": "Continente", "lidl": "Lidl",
        "aldi": "Aldi", "auchan": "Auchan", "intermarché": "Intermarché",
        "mercadona": "Mercadona", "galp": "Galp", "bp": "BP", "prio": "Prio",
        "ikea": "IKEA", "fnac": "FNAC", "worten": "Worten", "zara": "Zara",
        "uber eats": "Uber Eats", "uber": "Uber", "bolt": "Bolt", "glovo": "Glovo",
    ]

    private static func extrairLoja(de texto: String) -> String? {
        // "uber eats" está antes de "uber" para o nome mais específico ganhar.
        lojasConhecidas.sorted { $0.key.count > $1.key.count }
            .first { texto.contains($0.key) }?
            .value
    }

    /// Palavras-chave → nome canónico de categoria. Só é devolvido um nome
    /// que exista mesmo na lista de categorias do utilizador.
    private static let palavrasPorCategoria: [(palavras: [String], categoria: String)] = [
        (["almoço", "almoco", "jantar", "café", "cafe", "bica", "galão", "pastel", "pequeno-almoço", "lanche",
          "restaurante", "pastelaria", "padaria", "pizza", "sushi", "hambúrguer", "hamburguer", "mcdonald",
          "burger", "kfc", "cerveja", "time out", "uber eats", "glovo", "bolt food"], "Restauração"),
        (["pingo doce", "continente", "lidl", "aldi", "auchan", "intermarché", "intermarche", "mercadona",
          "minipreço", "supermercado", "mercearia", "mercado", "frutaria", "talho", "compras"], "Supermercado"),
        (["uber", "bolt", "táxi", "taxi", "gasolina", "gasóleo", "combustível", "galp", "repsol",
          "passe", "navegante", "metro", "comboio", "autocarro", "carris", "portagem", "via verde",
          "estacionamento", "parque"], "Transportes"),
        (["renda", "edp", "água", "luz", "gás", "condomínio", "internet", "meo", "vodafone", "nos ",
          "ikea", "leroy", "limpeza"], "Casa"),
        (["netflix", "spotify", "hbo", "disney", "icloud", "prime video", "youtube premium",
          "chatgpt", "subscrição", "assinatura", "mensalidade"], "Subscrições"),
        (["farmácia", "farmacia", "médico", "medico", "dentista", "consulta", "hospital", "clínica",
          "clinica", "análises", "óculos", "ginásio", "ginasio"], "Saúde"),
        (["cinema", "concerto", "bilhete", "livro", "teatro", "museu", "festival", "jogo", "steam",
          "playstation", "fnac"], "Lazer"),
        (["roupa", "zara", "h&m", "primark", "bershka", "mango", "sapatos", "ténis", "tenis",
          "calças", "camisola", "casaco", "vestido"], "Roupa"),
    ]

    /// Sugere uma categoria para um texto livre (frase, loja ou descrição),
    /// só por palavras-chave. Usado também como recurso quando o modelo de
    /// linguagem não escolhe categoria, e para os talões.
    static func sugerirCategoria(para texto: String, entre categorias: [String]) -> String? {
        extrairCategoria(de: texto.lowercased(), entre: categorias)
    }

    private static func extrairCategoria(de texto: String, entre categorias: [String]) -> String? {
        // O nome exato de uma categoria do utilizador tem prioridade sobre as
        // heurísticas, mas só como palavra inteira: "casaco" não é "Casa".
        let palavras = " " + String(texto.map { $0.isLetter ? $0 : " " }) + " "
        if let direta = categorias.first(where: { palavras.contains(" \($0.lowercased()) ") }) {
            return direta
        }
        // Se a categoria da primeira palavra-chave não existir na lista do
        // utilizador, continua-se à procura nas seguintes.
        for (palavras, categoria) in palavrasPorCategoria
        where palavras.contains(where: texto.contains) {
            if let existente = categorias.first(where: {
                $0.compare(categoria, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                return existente
            }
        }
        return nil
    }
}

nonisolated private extension String {
    func capitalizarPrimeiraLetra() -> String {
        guard let primeira = first else { return self }
        return primeira.uppercased() + dropFirst()
    }
}
