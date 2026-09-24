import Foundation
import SwiftData
import Observation

@Observable @MainActor
final class HojeViewModel {
    var textoDeRegisto = ""
    /// Proposta à espera de confirmação no cartão. Nada é gravado sem confirmar.
    var proposta: PropostaDeTransacao?
    var aInterpretar = false
    var mensagemDeErro: String?
    /// Incrementado a cada gravação — dispara o haptic na view.
    private(set) var gravacoes = 0

    private let interpretador: any InterpretadorDeDespesas

    init(interpretador: any InterpretadorDeDespesas = FabricaDeInterpretadores.padrao()) {
        self.interpretador = interpretador
    }

    func interpretar(categorias: [Categoria]) async {
        let texto = textoDeRegisto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty, !aInterpretar else { return }

        aInterpretar = true
        mensagemDeErro = nil
        defer { aInterpretar = false }

        do {
            proposta = try await interpretador.interpretar(
                texto,
                categorias: categorias.map(\.nome),
                hoje: .now
            )
        } catch {
            mensagemDeErro = "Não encontrei um valor nessa frase. Tenta, por exemplo, \"café 1,20\"."
        }
    }

    func confirmar(
        _ proposta: PropostaDeTransacao,
        categorias: [Categoria],
        contas: [Conta],
        contexto: ModelContext
    ) {
        let transacao = Transacao(
            valor: proposta.valor,
            tipo: proposta.tipo,
            descricao: proposta.descricao,
            loja: proposta.loja,
            data: proposta.data,
            categoria: categorias.first { $0.nome == proposta.nomeDaCategoria },
            conta: contas.first,
            origem: .texto
        )
        contexto.insert(transacao)
        try? contexto.save()

        gravacoes += 1
        self.proposta = nil
        textoDeRegisto = ""
    }

    /// Ponte entre os modelos SwiftData e a calculadora pura.
    func resultadoDoDia(
        transacoes: [Transacao],
        recorrentes: [Recorrente],
        definicoes: [DefinicoesDoMes],
        hoje: Date = .now
    ) -> CalculadoraDoDia.Resultado {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: hoje)
        let mes = calendario.component(.month, from: hoje)
        let definicoesDoMes = definicoes.first { $0.ano == ano && $0.mes == mes }

        let despesas = transacoes
            .filter { $0.tipo == .despesa }
            .map {
                CalculadoraDoDia.Despesa(
                    valor: $0.valor,
                    data: $0.data,
                    ehPagamentoDeRecorrente: $0.recorrente != nil
                )
            }

        return CalculadoraDoDia.calcular(.init(
            hoje: hoje,
            calendario: calendario,
            // Rendimento a zero conta como "não definido", para o ecrã Hoje
            // convidar a preenchê-lo em vez de mostrar números sem sentido.
            rendimentoEsperado: (definicoesDoMes?.rendimentoEsperado).flatMap { $0 > .zero ? $0 : nil },
            poupancaPlaneada: definicoesDoMes?.poupancaPlaneada ?? .zero,
            recorrentesAtivas: recorrentes.filter(\.ativa).map(\.valor),
            despesasDoMes: despesas
        ))
    }
}
