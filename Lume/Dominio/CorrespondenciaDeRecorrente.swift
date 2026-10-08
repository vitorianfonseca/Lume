import Foundation

/// Liga um movimento novo a uma conta fixa já existente, quando o nome
/// bate certo com a descrição ou a loja — para o histórico de preços e o
/// custo anual terem dados reais, venha o registo de onde vier (texto,
/// voz, talão, Siri ou Apple Pay).
nonisolated enum CorrespondenciaDeRecorrente {
    static func nomeCorrespondente(descricao: String, loja: String?, entreNomes nomes: [String]) -> String? {
        func igual(_ a: String, _ b: String) -> Bool {
            let aLimpo = a.trimmingCharacters(in: .whitespacesAndNewlines)
            let bLimpo = b.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !aLimpo.isEmpty, !bLimpo.isEmpty else { return false }
            return aLimpo.compare(bLimpo, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return nomes.first { nome in
            igual(nome, descricao) || (loja.map { igual(nome, $0) } ?? false)
        }
    }
}
