import Foundation

/// As regras das garantias vêm de um ficheiro à parte, não do código —
/// o prazo legal muda com a lei, e isto é só uma estimativa para a Lume
/// lembrar, nunca aconselhamento com força de lei.
nonisolated struct RegrasDeGarantia: Decodable {
    let duracaoLegalEmMeses: Int
    let valorMinimoPorDefeito: Decimal
    let categoriasSugeridas: [String]
    let revistoEm: String
    let fonte: String

    private enum ChavesDeCodigo: String, CodingKey {
        case duracaoLegalEmMeses, valorMinimoPorDefeito, categoriasSugeridas, revistoEm, fonte
    }

    init(from decoder: Decoder) throws {
        let valores = try decoder.container(keyedBy: ChavesDeCodigo.self)
        duracaoLegalEmMeses = try valores.decode(Int.self, forKey: .duracaoLegalEmMeses)
        let valorTexto = try valores.decode(String.self, forKey: .valorMinimoPorDefeito)
        valorMinimoPorDefeito = Decimal(string: valorTexto, locale: Locale(identifier: "en_US_POSIX")) ?? 50
        categoriasSugeridas = try valores.decode([String].self, forKey: .categoriasSugeridas)
        revistoEm = try valores.decode(String.self, forKey: .revistoEm)
        fonte = try valores.decode(String.self, forKey: .fonte)
    }

    init(duracaoLegalEmMeses: Int, valorMinimoPorDefeito: Decimal, categoriasSugeridas: [String], revistoEm: String, fonte: String) {
        self.duracaoLegalEmMeses = duracaoLegalEmMeses
        self.valorMinimoPorDefeito = valorMinimoPorDefeito
        self.categoriasSugeridas = categoriasSugeridas
        self.revistoEm = revistoEm
        self.fonte = fonte
    }

    /// Mesmo que falte o ficheiro (não devia), a app nunca bloqueia por isto.
    private static let reserva = RegrasDeGarantia(
        duracaoLegalEmMeses: 24,
        valorMinimoPorDefeito: 50,
        categoriasSugeridas: ["Casa", "Roupa"],
        revistoEm: "—",
        fonte: "Ficheiro de regras não encontrado — a confirmar."
    )

    static let atuais: RegrasDeGarantia = {
        guard let url = Bundle.main.url(forResource: "RegrasDeGarantia", withExtension: "json"),
              let dados = try? Data(contentsOf: url),
              let regras = try? JSONDecoder().decode(RegrasDeGarantia.self, from: dados)
        else { return reserva }
        return regras
    }()
}
