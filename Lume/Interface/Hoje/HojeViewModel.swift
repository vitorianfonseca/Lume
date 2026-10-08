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

    /// A fotografia do talão em curso, guardada na transação ao confirmar.
    private(set) var fotoDoTalao: Data?

    /// O que o Vision leu do talão em curso (loja, data, linhas, total):
    /// o ecrã redesenha o papel do talão com esta informação.
    var leituraDoTalao: LeitorDeTalao.Leitura?

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
            var interpretada = try await interpretador.interpretar(
                texto,
                categorias: categorias.map(\.nome),
                hoje: .now
            )
            interpretada.nomeDaCategoria = Self.categoriaSugerida(
                para: interpretada,
                textoOriginal: texto,
                categoriaDoInterpretador: interpretada.nomeDaCategoria,
                categorias: categorias
            )
            proposta = interpretada
        } catch {
            mensagemDeErro = "Não encontrei um valor nessa frase. Tenta, por exemplo, \"café 1,20\"."
        }
    }

    /// Pré-visualização ao vivo ("12,50 € · Restauração") enquanto se escreve
    /// ou fala: só as regras locais, rápidas e sem rede. A proposta final
    /// continua a sair de `interpretar`, ao tocar em "Analisar".
    func preVisualizar(_ texto: String, categorias: [Categoria]) async -> PropostaDeTransacao? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty,
              var lida = try? await InterpretadorPorRegras().interpretar(limpo, categorias: categorias.map(\.nome), hoje: .now),
              lida.valor > .zero
        else { return nil }
        lida.nomeDaCategoria = Self.categoriaSugerida(
            para: lida,
            textoOriginal: limpo,
            categoriaDoInterpretador: lida.nomeDaCategoria,
            categorias: categorias
        )
        return lida
    }

    /// "Últimos registos": repete um movimento com um toque — a mesma
    /// descrição, valor e categoria, com a data de hoje, à espera de confirmação.
    func repetir(_ transacao: Transacao) {
        mensagemDeErro = nil
        origemDoRegisto = .manual
        fotoDoTalao = nil
        leituraDoTalao = nil
        var repetida = PropostaDeTransacao(de: transacao)
        repetida.data = .now
        proposta = repetida
    }

    /// Talão: o Vision lê a fotografia, as heurísticas extraem loja e total,
    /// e o cartão confirma — como sempre, nada é gravado sem confirmação.
    func interpretarTalao(_ dados: Data, categorias: [Categoria]) async {
        guard !aInterpretar else { return }

        aInterpretar = true
        mensagemDeErro = nil
        origemDoRegisto = .talao
        fotoDoTalao = dados
        leituraDoTalao = nil
        defer { aInterpretar = false }

        do {
            let leitura = try await LeitorDeTalao.ler(dados)
            leituraDoTalao = leitura
            var lida = PropostaDeTransacao(
                valor: leitura.total,
                tipo: .despesa,
                descricao: "Compras",
                loja: leitura.loja,
                nomeDaCategoria: nil,
                // A data impressa no talão, se não for do futuro.
                data: leitura.data.map { min($0, .now) } ?? .now
            )
            // O talão também tenta adivinhar a categoria pela loja.
            lida.nomeDaCategoria = Self.categoriaSugerida(
                para: lida,
                textoOriginal: leitura.loja ?? "",
                categoriaDoInterpretador: nil,
                categorias: categorias
            )
            proposta = lida
        } catch {
            mensagemDeErro = "Não consegui ler um total nesse talão. Tenta uma foto mais nítida."
        }
    }

    @discardableResult
    func confirmar(
        _ proposta: PropostaDeTransacao,
        categorias: [Categoria],
        contas: [Conta],
        contexto: ModelContext,
        conta contaEscolhida: Conta? = nil,
        recorrentes: [Recorrente] = []
    ) -> Transacao {
        let recorrenteLigada = Recorrente.correspondente(
            descricao: proposta.descricao, loja: proposta.loja, entre: recorrentes
        )
        let subida = recorrenteLigada?.subidaComNovoValor(proposta.valor)
        let transacao = Transacao(
            valor: proposta.valor,
            tipo: proposta.tipo,
            descricao: proposta.descricao,
            loja: proposta.loja,
            data: proposta.data,
            categoria: categorias.first { $0.nome == proposta.nomeDaCategoria },
            conta: contaEscolhida ?? contas.first(where: \.principal) ?? contas.first,
            recorrente: recorrenteLigada,
            origem: origemDoRegisto
        )
        if origemDoRegisto == .talao {
            transacao.fotoDoTalao = fotoDoTalao
        }
        recorrenteLigada?.ultimoPagamentoEm = proposta.data
        contexto.insert(transacao)
        try? contexto.save()
        if let recorrenteLigada, let subida {
            Task { await NotificadorDeRecorrentes.avisarSubida(recorrenteLigada, subida: subida) }
        }

        resumoDaGravacao = resumo(de: transacao)
        gravacoes += 1
        self.proposta = nil
        textoDeRegisto = ""
        origemDoRegisto = .texto
        fotoDoTalao = nil
        leituraDoTalao = nil
        return transacao
    }

    /// A categoria proposta, por esta ordem:
    /// 1. o histórico: a categoria que o utilizador já usou para a mesma
    ///    loja ou descrição (é assim que as correções dele passam a contar);
    /// 2. a escolha do interpretador (modelo de linguagem ou regras);
    /// 3. as palavras-chave, como recurso quando o modelo não escolhe.
    static func categoriaSugerida(
        para proposta: PropostaDeTransacao,
        textoOriginal: String,
        categoriaDoInterpretador: String?,
        categorias: [Categoria]
    ) -> String? {
        if let doHistorico = categoriaDoHistorico(para: proposta, categorias: categorias) {
            return doHistorico
        }
        if let categoriaDoInterpretador {
            return categoriaDoInterpretador
        }
        let pistas = [textoOriginal, proposta.descricao, proposta.loja ?? ""].joined(separator: " ")
        return InterpretadorPorRegras.sugerirCategoria(para: pistas, entre: categorias.map(\.nome))
    }

    /// A categoria mais usada em movimentos anteriores do mesmo tipo com a
    /// mesma loja ou a mesma descrição; em empate, a mais recente.
    private static func categoriaDoHistorico(
        para proposta: PropostaDeTransacao,
        categorias: [Categoria]
    ) -> String? {
        func igual(_ a: String?, _ b: String?) -> Bool {
            guard let a, let b, !a.isEmpty, !b.isEmpty else { return false }
            return a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        // Com loja, compara-se só a loja: descrições genéricas como
        // "Compras" (a dos talões) juntariam lojas que nada têm a ver.
        let genericas: Set<String> = ["compras", "despesa", "receita"]
        let porDescricao = proposta.loja == nil
            && !genericas.contains(proposta.descricao.lowercased())

        var melhor: (nome: String, usos: Int, ultima: Date)?
        for categoria in categorias {
            let semelhantes = (categoria.transacoes ?? []).filter { transacao in
                transacao.tipo == proposta.tipo
                    && (proposta.loja != nil
                        ? igual(transacao.loja, proposta.loja)
                        : porDescricao && igual(transacao.descricao, proposta.descricao))
            }
            guard let ultima = semelhantes.map(\.data).max() else { continue }
            if melhor == nil
                || semelhantes.count > melhor!.usos
                || (semelhantes.count == melhor!.usos && ultima > melhor!.ultima) {
                melhor = (categoria.nome, semelhantes.count, ultima)
            }
        }
        return melhor?.nome
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
