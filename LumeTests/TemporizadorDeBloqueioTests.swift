import Testing
import Foundation
@testable import Lume

struct TemporizadorDeBloqueioTests {
    private func data(_ segundosDesdeAReferencia: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: segundosDesdeAReferencia)
    }

    @Test("Com atraso imediato, qualquer tempo em segundo plano pede autenticação")
    func imediato() {
        let ultima = data(1000)
        #expect(TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1000.5), atraso: .imediato))
        #expect(TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1060), atraso: .imediato))
    }

    @Test("Com 1 minuto de tolerância, só bloqueia depois de 60 segundos")
    func umMinuto() {
        let ultima = data(1000)
        #expect(!TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1030), atraso: .umMinuto))
        #expect(!TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1059.9), atraso: .umMinuto))
        #expect(TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1060), atraso: .umMinuto))
        #expect(TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1200), atraso: .umMinuto))
    }

    @Test("Com 5 minutos de tolerância, uma troca rápida de app não pede Face ID outra vez")
    func cincoMinutos() {
        let ultima = data(1000)
        #expect(!TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1010), atraso: .cincoMinutos))
        #expect(TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: data(1300), atraso: .cincoMinutos))
    }

    @Test("Sem nenhuma vez anterior registada (instalação nova), bloqueia sempre")
    func semHistorico() {
        let nuncaAtivo = Date(timeIntervalSinceReferenceDate: 0)
        #expect(TemporizadorDeBloqueio.deveBloquear(desde: nuncaAtivo, agora: .now, atraso: .cincoMinutos))
    }
}
