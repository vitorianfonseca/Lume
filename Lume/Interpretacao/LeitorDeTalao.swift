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
        return Leitura(loja: extrairLoja(de: linhas), total: total)
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
