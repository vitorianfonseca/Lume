import Foundation
import SwiftData

/// A garantia de uma compra — produto, onde e quando, e até quando vale a
/// pena guardar o talão. A foto vem do movimento, mas fica também aqui
/// (comprimida), para sobreviver mesmo que o movimento seja apagado.
@Model
final class Garantia {
    /// Estável entre sincronizações — identifica as notificações desta garantia.
    var id: UUID = UUID()
    var produto: String = ""
    var loja: String?
    var dataDaCompra: Date = Date.now
    var valor: Decimal = Decimal.zero
    var duracaoEmMeses: Int = 24
    /// Prazo da loja para devolução, se houver — opcional e separado da garantia.
    var prazoDeDevolucao: Date?
    @Attribute(.externalStorage) var fotoDoTalao: Data?
    var criadaEm: Date = Date.now

    init(
        produto: String,
        loja: String? = nil,
        dataDaCompra: Date = .now,
        valor: Decimal,
        duracaoEmMeses: Int,
        prazoDeDevolucao: Date? = nil,
        fotoDoTalao: Data? = nil
    ) {
        self.produto = produto
        self.loja = loja
        self.dataDaCompra = dataDaCompra
        self.valor = valor
        self.duracaoEmMeses = duracaoEmMeses
        self.prazoDeDevolucao = prazoDeDevolucao
        self.fotoDoTalao = fotoDoTalao
        self.criadaEm = .now
        self.id = UUID()
    }

    var dataFim: Date {
        Garantias.dataFim(dataDaCompra: dataDaCompra, duracaoEmMeses: duracaoEmMeses)
    }

    var expirada: Bool {
        Garantias.expirada(dataFim: dataFim)
    }
}
