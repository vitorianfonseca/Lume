import Foundation
import Vision

nonisolated enum ErroDeLeituraDeTalao: Error {
    case semTexto
    case semValor
}

/// Lê uma fotografia de talão com o Vision e extrai loja e total por
/// heurísticas determinísticas — nenhuma conta é feita por IA.
nonisolated enum LeitorDeTalao {
    struct Leitura: Equatable {
        var loja: String?
        var total: Decimal
        /// A data impressa no talão, se for legível.
        var data: Date?
        /// As linhas de produto com preço na mesma linha, pela ordem do talão.
        var itens: [Item] = []
    }

    struct Item: Equatable, Identifiable {
        let id: Int
        let nome: String
        let valor: Decimal
    }

    static func ler(_ dados: Data) async throws -> Leitura {
        var pedido = RecognizeTextRequest()
        pedido.recognitionLanguages = [Locale.Language(identifier: "pt-PT")]
        pedido.usesLanguageCorrection = true

        let observacoes = try await pedido.perform(on: dados)
        let linhas = observacoes.compactMap { $0.topCandidates(1).first?.string }
        guard !linhas.isEmpty else { throw ErroDeLeituraDeTalao.semTexto }
        return try interpretar(linhas: linhas)
    }

    /// Separado do Vision para ser testável com linhas de exemplo.
    static func interpretar(linhas: [String]) throws -> Leitura {
        guard let total = extrairTotal(de: linhas) else {
            throw ErroDeLeituraDeTalao.semValor
        }
        return Leitura(
            loja: extrairLoja(de: linhas),
            total: total,
            data: extrairData(de: linhas),
            itens: extrairItens(de: linhas)
        )
    }

    /// Linhas que têm valor mas não são produtos.
    private static let palavrasDeResumo = [
        "total", "iva", "troco", "multibanco", "mb ", "visa", "mastercard", "pagamento",
        "numerário", "numerario", "dinheiro", "desconto", "poupança", "saldo", "nif", "contribuinte",
        "cartão", "cartao", "valor", "entregue", "taxa", "base",
    ]

    /// "Pão alentejano 1,89" → produto com preço. Só se o nome vier na
    /// mesma linha; linhas de totais, impostos e pagamento ficam de fora.
    private static func extrairItens(de linhas: [String]) -> [Item] {
        var itens: [Item] = []
        for linha in linhas {
            let minuscula = linha.lowercased()
            guard !palavrasDeResumo.contains(where: minuscula.contains),
                  let preco = valor(em: linha), preco > 0,
                  let inicioDoPreco = linha.firstMatch(of: /\d{1,3}(?:[ .]\d{3})*[.,]\d{2}/)?.range.lowerBound
            else { continue }

            // O nome é o que vem antes do preço, sem quantidades soltas nem símbolos.
            let nome = linha[..<inicioDoPreco]
                .trimmingCharacters(in: .whitespaces.union(.punctuationCharacters).union(CharacterSet(charactersIn: "€x*")))
            guard nome.count >= 2, nome.rangeOfCharacter(from: .letters) != nil else { continue }

            itens.append(Item(id: itens.count, nome: nome, valor: preco))
            if itens.count == 12 { break }
        }
        return itens
    }

    /// "24/09/2026", "24-09-26" ou "2026-09-24".
    private static func extrairData(de linhas: [String]) -> Date? {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = .current
        for linha in linhas {
            if let m = linha.firstMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
               let data = calendario.date(from: DateComponents(year: Int(m.1), month: Int(m.2), day: Int(m.3))) {
                return data
            }
            if let m = linha.firstMatch(of: /(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{2,4})/),
               let dia = Int(m.1), let mes = Int(m.2), var ano = Int(m.3),
               (1...31).contains(dia), (1...12).contains(mes) {
                if ano < 100 { ano += 2000 }
                if let data = calendario.date(from: DateComponents(year: ano, month: mes, day: dia)),
                   calendario.component(.day, from: data) == dia {
                    return data
                }
            }
        }
        return nil
    }

    /// A linha "total" manda; sem ela, vale o maior valor do talão.
    private static func extrairTotal(de linhas: [String]) -> Decimal? {
        let linhasDeTotal = linhas.filter { linha in
            let minuscula = linha.lowercased()
            return minuscula.contains("total")
                && !minuscula.contains("subtotal")
                && !minuscula.contains("sub-total")
        }
        if let total = linhasDeTotal.compactMap(valor(em:)).max() {
            return total
        }
        return linhas.compactMap(valor(em:)).max()
    }

    /// "12,50", "1 092,90", "1.092,90" ou "12.50" — sempre com 2 decimais.
    private static func valor(em linha: String) -> Decimal? {
        guard let encontrado = linha.firstMatch(of: /(\d{1,3}(?:[ .]\d{3})*[.,]\d{2})/) else {
            return nil
        }
        var texto = String(encontrado.1).replacingOccurrences(of: " ", with: "")
        if texto.contains(",") {
            // Formato português: pontos são milhares, a vírgula é decimal.
            texto = texto
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        return Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Primeira linha do topo com cara de nome: letras, sem dígitos, curta.
    private static func extrairLoja(de linhas: [String]) -> String? {
        linhas.prefix(5)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { linha in
                linha.count >= 3 && linha.count <= 30
                    && linha.rangeOfCharacter(from: .decimalDigits) == nil
                    && linha.rangeOfCharacter(from: .letters) != nil
            }
    }
}
