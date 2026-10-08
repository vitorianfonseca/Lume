import Foundation

/// A matemática das contas fixas: custo anual, deteção de subida de preço
/// e sugestões de novas recorrentes a partir do histórico de movimentos —
/// só números, nenhuma SwiftData aqui.
nonisolated enum AnaliseDeRecorrentes {
    static func custoAnual(_ valorMensal: Decimal) -> Decimal {
        valorMensal * 12
    }

    struct Subida: Equatable {
        var valorAntes: Decimal
        var valorDepois: Decimal
        var diferenca: Decimal
        var fracao: Double
    }

    /// Compara o pagamento mais recente com o anterior; só conta como
    /// subida a partir do limiar (por defeito +5% ou +2 €, o que for maior
    /// — uma conta de 8 € não devia alertar por 10 cêntimos).
    static func detetarSubida(
        pagamentosOrdenados: [Decimal],
        limiarPercentual: Double = 0.05,
        limiarAbsoluto: Decimal = 2
    ) -> Subida? {
        guard pagamentosOrdenados.count >= 2 else { return nil }
        let antes = pagamentosOrdenados[pagamentosOrdenados.count - 2]
        let depois = pagamentosOrdenados[pagamentosOrdenados.count - 1]
        guard antes > .zero else { return nil }
        let diferenca = depois - antes
        guard diferenca > .zero else { return nil }
        let fracao = (diferenca as NSDecimalNumber).doubleValue / (antes as NSDecimalNumber).doubleValue
        guard diferenca >= limiarAbsoluto || fracao >= limiarPercentual else { return nil }
        return Subida(valorAntes: antes, valorDepois: depois, diferenca: diferenca, fracao: fracao)
    }

    struct Sugestao: Equatable {
        var nome: String
        var valorMedio: Decimal
    }

    struct Pagamento {
        var nome: String
        var valor: Decimal
        var mes: Int
        var ano: Int
    }

    /// Comerciantes pagos em 3 meses seguidos, com valores parecidos
    /// (±10%), que ainda não são uma recorrente nem foram ignorados.
    static func sugerirNovasRecorrentes(
        pagamentos: [Pagamento],
        nomesExistentes: Set<String>,
        nomesIgnorados: Set<String>
    ) -> [Sugestao] {
        let porNome = Dictionary(grouping: pagamentos, by: \.nome)
        var sugestoes: [Sugestao] = []
        for (nome, ocorrencias) in porNome {
            guard !nomesExistentes.contains(nome), !nomesIgnorados.contains(nome) else { continue }
            let meses = Set(ocorrencias.map { $0.ano * 100 + $0.mes }).sorted()
            guard temTresSeguidos(meses) else { continue }

            let valores = ocorrencias.map(\.valor)
            let media = valores.reduce(Decimal.zero, +) / Decimal(valores.count)
            guard media > .zero else { continue }
            let dentroDaFaixa = valores.allSatisfy { valor in
                let desvio = (abs(valor - media) as NSDecimalNumber).doubleValue / (media as NSDecimalNumber).doubleValue
                return desvio <= 0.1
            }
            guard dentroDaFaixa else { continue }
            sugestoes.append(Sugestao(nome: nome, valorMedio: media))
        }
        return sugestoes.sorted { $0.nome < $1.nome }
    }

    private static func temTresSeguidos(_ mesesOrdenados: [Int]) -> Bool {
        guard mesesOrdenados.count >= 3 else { return false }
        for indice in 0...(mesesOrdenados.count - 3) {
            if consecutivo(mesesOrdenados[indice], mesesOrdenados[indice + 1]),
               consecutivo(mesesOrdenados[indice + 1], mesesOrdenados[indice + 2]) {
                return true
            }
        }
        return false
    }

    /// `ano*100+mes` consecutivo, incluindo a virada do ano (dez→jan).
    private static func consecutivo(_ anterior: Int, _ seguinte: Int) -> Bool {
        let anoA = anterior / 100, mesA = anterior % 100
        let anoB = seguinte / 100, mesB = seguinte % 100
        if anoA == anoB { return mesB == mesA + 1 }
        return anoB == anoA + 1 && mesA == 12 && mesB == 1
    }
}
