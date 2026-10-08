import Foundation
import Testing
@testable import Lume

struct LeitorDeTalaoTests {

    @Test("A linha 'TOTAL' manda, mesmo havendo valores maiores no talão")
    func totalExplicito() throws {
        let leitura = try LeitorDeTalao.interpretar(linhas: [
            "CONTINENTE", "Rua das Flores, Lisboa",
            "Leite 2,49", "Queijo 15,90", "IVA 23% 1,20",
            "TOTAL 12,50", "Multibanco 12,50",
        ])
        #expect(leitura.total == Decimal(string: "12.50", locale: Locale(identifier: "en_US_POSIX")))
        #expect(leitura.loja == "CONTINENTE")
    }

    @Test("Sem linha de total, vale o maior valor do talão")
    func semLinhaDeTotal() throws {
        let leitura = try LeitorDeTalao.interpretar(linhas: [
            "Pastelaria do Bairro", "Galão 1,20", "Pastel de nata 1,30", "2,50",
        ])
        #expect(leitura.total == Decimal(string: "2.50", locale: Locale(identifier: "en_US_POSIX")))
    }

    @Test("'Subtotal' não conta como total")
    func subtotalIgnorado() throws {
        let leitura = try LeitorDeTalao.interpretar(linhas: [
            "LIDL", "Subtotal 9,99", "TOTAL 11,49",
        ])
        #expect(leitura.total == Decimal(string: "11.49", locale: Locale(identifier: "en_US_POSIX")))
    }

    @Test("Milhares à portuguesa: '1.092,90' lê-se como 1092,90")
    func milharesComPonto() throws {
        let leitura = try LeitorDeTalao.interpretar(linhas: ["TOTAL 1.092,90"])
        #expect(leitura.total == Decimal(string: "1092.90", locale: Locale(identifier: "en_US_POSIX")))
    }

    @Test("Talão sem nenhum valor lança erro em vez de adivinhar")
    func semValor() {
        #expect(throws: ErroDeLeituraDeTalao.self) {
            try LeitorDeTalao.interpretar(linhas: ["CONTINENTE", "Obrigado pela visita"])
        }
    }

    @Test("Linhas de produto são lidas; totais, IVA e pagamento ficam de fora")
    func itens() throws {
        let leitura = try LeitorDeTalao.interpretar(linhas: [
            "PINGO DOCE", "Lisboa 24/09/2026",
            "Pão alentejano 1,89", "Salmão fresco 12,90",
            "Subtotal 14,79", "IVA 6% 0,84", "TOTAL 14,79", "Multibanco 14,79",
        ])
        #expect(leitura.itens.map(\.nome) == ["Pão alentejano", "Salmão fresco"])
        #expect(leitura.itens.map(\.valor) == [Decimal(string: "1.89", locale: Locale(identifier: "en_US_POSIX"))!,
                                               Decimal(string: "12.90", locale: Locale(identifier: "en_US_POSIX"))!])
    }

    @Test("A data impressa é lida em formato português ou ISO")
    func data() throws {
        let calendario = Calendar(identifier: .gregorian)
        let portuguesa = try LeitorDeTalao.interpretar(linhas: ["LIDL", "24/09/2026 18:02", "TOTAL 5,00"])
        #expect(portuguesa.data.map { calendario.dateComponents([.year, .month, .day], from: $0) }
            == DateComponents(year: 2026, month: 9, day: 24))
        let iso = try LeitorDeTalao.interpretar(linhas: ["LIDL", "2026-09-24", "TOTAL 5,00"])
        #expect(iso.data.map { calendario.component(.day, from: $0) } == 24)
        let semData = try LeitorDeTalao.interpretar(linhas: ["LIDL", "TOTAL 5,00"])
        #expect(semData.data == nil)
    }
}
