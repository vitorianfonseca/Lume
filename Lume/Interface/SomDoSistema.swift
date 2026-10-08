import AudioToolbox

/// Sons curtos para os poucos momentos que merecem — a Apple usa som com
/// moderação, sempre a par de um háptico, nunca sozinho. Usa IDs do
/// próprio sistema (não ficheiros nossos), para o som ficar "de fábrica"
/// em vez de inventado.
///
/// Não consigo ouvir o resultado a partir daqui — testa no simulador (tem
/// som) e diz-me se não encaixar; troca-se num instante.
nonisolated enum SomDoSistema {
    /// Guardaste algo com sucesso (um registo, uma divisão).
    case sucesso
    /// Uma ação que não se desfaz (eliminar).
    case aviso

    private var id: SystemSoundID {
        switch self {
        case .sucesso: 1407
        case .aviso: 1521
        }
    }

    func tocar() {
        AudioServicesPlaySystemSound(id)
    }
}
