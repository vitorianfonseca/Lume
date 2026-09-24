import Testing
import Foundation
@testable import Lume

struct CalculadoraDoDiaTests {

    // Calendário fixo para os testes serem determinísticos em qualquer máquina.
    private let calendario: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }()

    private func data(_ ano: Int, _ mes: Int, _ dia: Int, hora: Int = 12) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: hora))!
    }

    private func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func diaCalculado(_ resultado: CalculadoraDoDia.Resultado) throws -> CalculadoraDoDia.Dia {
        guard case .calculado(let dia) = resultado else {
            throw ErroDeTeste.esperavaCalculado
        }
        return dia
    }

    private enum ErroDeTeste: Error {
        case esperavaCalculado
    }

    // MARK: - Cenários

    @Test("No dia 1, o disponível divide-se por todos os dias do mês")
    func inicioDoMes() throws {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, 1, 1),
            calendario: calendario,
            rendimentoEsperado: eur("1550"),
            poupancaPlaneada: eur("200"),
            recorrentesAtivas: [eur("650"), eur("40")]
        ))

        let dia = try diaCalculado(resultado)
        #expect(dia.disponivelDoMes == eur("660"))
        #expect(dia.diasRestantes == 31)
        // 660 / 31 = 21,2903… arredondado a cêntimos
        #expect(dia.hojePodesGastar == eur("21.29"))
    }

    @Test("No último dia do mês, resta 1 dia e o disponível é todo de hoje")
    func fimDoMes() throws {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, 1, 31),
            calendario: calendario,
            rendimentoEsperado: eur("1550"),
            poupancaPlaneada: eur("200"),
            recorrentesAtivas: [eur("690")],
            despesasDoMes: [
                .init(valor: eur("500"), data: data(2026, 1, 10)),
                .init(valor: eur("10"), data: data(2026, 1, 31)),
            ]
        ))

        let dia = try diaCalculado(resultado)
        #expect(dia.diasRestantes == 1)
        #expect(dia.disponivelDoMes == eur("160"))
        #expect(dia.gastoHoje == eur("10"))
        #expect(dia.hojePodesGastar == eur("150"))
    }

    @Test(
        "Meses de 28, 30 e 31 dias contam bem os dias restantes",
        arguments: [(2, 19), (4, 21), (1, 22)]  // (mês de 2026, dias restantes a partir do dia 10)
    )
    func duracoesDeMes(mes: Int, diasRestantesEsperados: Int) throws {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, mes, 10),
            calendario: calendario,
            rendimentoEsperado: eur("1000")
        ))

        let dia = try diaCalculado(resultado)
        #expect(dia.diasRestantes == diasRestantesEsperados)
    }

    @Test("Num dia sem gastos, o valor de hoje é a fatia diária inteira")
    func diaSemGastos() throws {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, 4, 21),
            calendario: calendario,
            rendimentoEsperado: eur("300")
        ))

        let dia = try diaCalculado(resultado)
        #expect(dia.gastoHoje == .zero)
        #expect(dia.diasRestantes == 10)
        #expect(dia.hojePodesGastar == eur("30.00"))
    }

    @Test("Gastar acima do limite dá um valor negativo, sem rebentar")
    func gastoAcimaDoLimite() throws {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, 4, 21),
            calendario: calendario,
            rendimentoEsperado: eur("300"),
            despesasDoMes: [
                .init(valor: eur("36.20"), data: data(2026, 4, 21))
            ]
        ))

        let dia = try diaCalculado(resultado)
        #expect(dia.hojePodesGastar == eur("-6.20"))
    }

    @Test("Sem rendimento definido, o resultado é explícito e não inventa números")
    func mesSemRendimento() {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, 4, 21),
            calendario: calendario,
            rendimentoEsperado: nil
        ))

        #expect(resultado == .semRendimento)
    }

    @Test("Pagamentos de recorrentes não contam duas vezes, e outros meses são ignorados")
    func recorrentesNaoContamDuasVezes() throws {
        let resultado = CalculadoraDoDia.calcular(.init(
            hoje: data(2026, 4, 15),
            calendario: calendario,
            rendimentoEsperado: eur("1450"),
            recorrentesAtivas: [eur("650")],
            despesasDoMes: [
                // A renda paga: já descontada via recorrentesAtivas, não pode repetir.
                .init(valor: eur("650"), data: data(2026, 4, 1), ehPagamentoDeRecorrente: true),
                .init(valor: eur("100"), data: data(2026, 4, 5)),
                // Despesa de março: fora do mês, ignorada.
                .init(valor: eur("999"), data: data(2026, 3, 28)),
            ]
        ))

        let dia = try diaCalculado(resultado)
        #expect(dia.disponivelDoMes == eur("700"))
        #expect(dia.diasRestantes == 16)
    }
}
