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
    /// Incrementado a cada gravação — dispara o haptic e o toast na view.
    private(set) var gravacoes = 0
    /// "Guardado · Restauração a 61%" quando a categoria tem orçamento.
    private(set) var resumoDaGravacao = "Guardado"

    /// Como o registo em curso entrou (texto, voz ou talão) — gravado
    /// na transação ao confirmar.
    private(set) var origemDoRegisto = OrigemTransacao.texto

    private let interpretadorFixo: (any InterpretadorDeDespesas)?

    /// Resolvido a cada pedido, para uma chave Claude acabada de guardar
    /// contar logo, sem reiniciar a app.
    private var interpretador: any InterpretadorDeDespesas {
        interpretadorFixo ?? FabricaDeInterpretadores.padrao()
    }

    init(interpretador: (any InterpretadorDeDespesas)? = nil) {
        self.interpretadorFixo = interpretador
    }

    func interpretar(categorias: [Categoria], origem: OrigemTransacao = .texto) async {
        let texto = textoDeRegisto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty, !aInterpretar else { return }

        aInterpretar = true
        mensagemDeErro = nil
        origemDoRegisto = origem
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

    /// Talão: o Vision lê a fotografia, as heurísticas extraem loja e total,
    /// e o cartão confirma — como sempre, nada é gravado sem confirmação.
    func interpretarTalao(_ dados: Data, categorias: [Categoria]) async {
        guard !aInterpretar else { return }

        aInterpretar = true
        mensagemDeErro = nil
        origemDoRegisto = .talao
        defer { aInterpretar = false }

        do {
            let leitura = try await LeitorDeTalao.ler(dados)
            proposta = PropostaDeTransacao(
                valor: leitura.total,
                tipo: .despesa,
                descricao: "Compras",
                loja: leitura.loja,
                nomeDaCategoria: nil,
                data: .now
            )
        } catch {
            mensagemDeErro = "Não consegui ler um total nesse talão. Tenta uma foto mais nítida."
        }
    }

    func confirmar(
        _ proposta: PropostaDeTransacao,
        categorias: [Categoria],
        contas: [Conta],
        contexto: ModelContext,
        conta contaEscolhida: Conta? = nil
    ) {
        let transacao = Transacao(
            valor: proposta.valor,
            tipo: proposta.tipo,
            descricao: proposta.descricao,
            loja: proposta.loja,
            data: proposta.data,
            categoria: categorias.first { $0.nome == proposta.nomeDaCategoria },
            conta: contaEscolhida ?? contas.first(where: \.principal) ?? contas.first,
            origem: origemDoRegisto
        )
        contexto.insert(transacao)
        try? contexto.save()

        resumoDaGravacao = resumo(de: transacao)
        gravacoes += 1
        self.proposta = nil
        textoDeRegisto = ""
        origemDoRegisto = .texto
    }

    /// O momento "Guardado · Orçamento a 61%" do sistema visual.
    private func resumo(de transacao: Transacao) -> String {
        guard transacao.tipo == .despesa,
              let categoria = transacao.categoria,
              let orcamento = categoria.orcamentoMensal, orcamento > .zero
        else { return "Guardado" }

        let calendario = Calendar.current
        let gasto = (categoria.transacoes ?? [])
            .filter { $0.tipo == .despesa && calendario.isDate($0.data, equalTo: transacao.data, toGranularity: .month) }
            .reduce(Decimal.zero) { $0 + $1.valor }
        let percentagem = ((gasto / orcamento * 100) as NSDecimalNumber).intValue
        return "Guardado · \(categoria.nome) a \(percentagem)%"
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
