import Foundation

/// Depois de quanto tempo em segundo plano a Lume volta a pedir Face ID.
nonisolated enum AtrasoDoBloqueio: Int, CaseIterable, Identifiable, Codable {
    case imediato = 0
    case umMinuto = 60
    case cincoMinutos = 300

    var id: Int { rawValue }

    /// Frase completa, para contexto (VoiceOver, texto corrido).
    var nome: String {
        switch self {
        case .imediato: "Imediatamente"
        case .umMinuto: "Depois de 1 minuto"
        case .cincoMinutos: "Depois de 5 minutos"
        }
    }

    /// Curto, para caber no seletor segmentado — "PEDIR OUTRA VEZ" já dá o contexto.
    var nomeCurto: String {
        switch self {
        case .imediato: "Imediato"
        case .umMinuto: "1 min"
        case .cincoMinutos: "5 min"
        }
    }
}

/// Decide se a Lume deve voltar a pedir autenticação depois de ter estado
/// em segundo plano — pura, sem tocar no relógio do sistema nem em UI, para
/// se poder testar com datas fixas.
nonisolated enum TemporizadorDeBloqueio {
    static func deveBloquear(desde ultimaVezAtivo: Date, agora: Date, atraso: AtrasoDoBloqueio) -> Bool {
        agora.timeIntervalSince(ultimaVezAtivo) >= Double(atraso.rawValue)
    }
}
