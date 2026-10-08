import Foundation
import SwiftData

/// O veredicto da Lume sobre um preço. Sem alarmes: informação, não culpa.
nonisolated enum NivelDePreco: String, Codable, CaseIterable {
    case bom
    case razoavel
    case mau
}

/// Uma fonte consultada — o que dá confiança ao número.
nonisolated struct FonteDePreco: Codable, Hashable {
    var nome: String
    var endereco: String
}

/// Cada "segunda opinião" fica guardada. Duas razões: a pessoa pode voltar
/// atrás para decidir, e cada consulta acrescenta um ponto ao histórico de
/// preços da Lume — o histórico é o que nós próprios vimos, nunca inventado.
@Model
final class ConsultaDeCompra {
    // Defaults e opcionais em tudo, para o CloudKit sincronizar.
    var produto: String = ""
    /// O preço que a pessoa está prestes a pagar.
    var precoConsultado: Decimal = Decimal.zero
    var precoNormal: Decimal?
    var precoMaisBarato: Decimal?
    var lojaMaisBarata: String?
    var veredicto: String = ""
    var nivelRaw: String = NivelDePreco.razoavel.rawValue
    var problemas: [String] = []
    var alternativaNome: String?
    var alternativaPreco: Decimal?
    var fontes: [FonteDePreco] = []
    var consultadaEm: Date = Date.now

    /// Decisão da pessoa, quando a toma — alimenta o "já dispensaste isto".
    var decisaoRaw: String?
    /// Vigilância de preço: a Lume volta a verificar e avisa se descer.
    var aVigiar: Bool = false
    var precoAlvo: Decimal?
    /// Sem relação para a `Transacao`: o CloudKit exige inversas em todas as
    /// relações, e amarrar o movimento à consulta não vale acoplar os dois
    /// modelos. A decisão já diz o que precisamos de saber.

    var nivel: NivelDePreco {
        get { NivelDePreco(rawValue: nivelRaw) ?? .razoavel }
        set { nivelRaw = newValue.rawValue }
    }

    var decisao: DecisaoDeCompra? {
        get { decisaoRaw.flatMap(DecisaoDeCompra.init(rawValue:)) }
        set { decisaoRaw = newValue?.rawValue }
    }

    init(
        produto: String,
        precoConsultado: Decimal,
        precoNormal: Decimal? = nil,
        precoMaisBarato: Decimal? = nil,
        lojaMaisBarata: String? = nil,
        veredicto: String,
        nivel: NivelDePreco,
        problemas: [String] = [],
        alternativaNome: String? = nil,
        alternativaPreco: Decimal? = nil,
        fontes: [FonteDePreco] = [],
        consultadaEm: Date = .now
    ) {
        self.produto = produto
        self.precoConsultado = precoConsultado
        self.precoNormal = precoNormal
        self.precoMaisBarato = precoMaisBarato
        self.lojaMaisBarata = lojaMaisBarata
        self.veredicto = veredicto
        self.nivelRaw = nivel.rawValue
        self.problemas = problemas
        self.alternativaNome = alternativaNome
        self.alternativaPreco = alternativaPreco
        self.fontes = fontes
        self.consultadaEm = consultadaEm
    }
}

nonisolated enum DecisaoDeCompra: String, Codable {
    case comprou
    case dispensou
}
