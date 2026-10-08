import Foundation

/// O cálculo do "fecho do mês" — o resumo ao estilo "wrapped" do mês
/// anterior. Só números aqui, nunca frases: as frases nascem na interface,
/// como em toda a app, para o Claude (Premium) só poder reescrever o texto
/// e nunca tocar nestas contas.
nonisolated enum FechoDoMes {
    struct Movimento: Equatable {
        var valor: Decimal
        var data: Date
        var categoriaNome: String?
        var loja: String?
    }

    struct Categoria: Equatable {
        var nome: String
        var simbolo: String
        var orcamentoMensal: Decimal?
    }

    struct Objetivo: Equatable {
        var nome: String
        var simbolo: String
        var valorAlvo: Decimal
        /// Só a soma dos reforços datados deste mês — não se reconstrói o
        /// saldo histórico no fim do mês, que a app não guarda.
        var valorReforcadoNoMes: Decimal
        /// O progresso de hoje; para meses passados, é "onde estás agora",
        /// não "onde estavas nessa altura" — dito com clareza na interface.
        var valorPoupadoAtual: Decimal
    }

    struct Entrada {
        var mes: Int
        var ano: Int
        var calendario: Calendar = .current
        /// Despesas variáveis do mês — sem contas fixas, que entram só na
        /// poupança reservada, para não inflacionar "a categoria que mais pesou".
        var movimentosDoMes: [Movimento] = []
        var movimentosDoMesAnterior: [Movimento] = []
        var categorias: [Categoria] = []
        var poupancaReservadaNoMes: Decimal = .zero
        var objetivos: [Objetivo] = []
    }

    struct CategoriaComValor: Equatable {
        var nome: String
        var simbolo: String
        var valor: Decimal
        var fracaoDoTotal: Double
    }

    struct SubidaDeCategoria: Equatable {
        var nome: String
        var simbolo: String
        var valorAgora: Decimal
        var valorAntes: Decimal
        var diferenca: Decimal
    }

    struct DiaDeGasto: Equatable {
        var data: Date
        var valor: Decimal
    }

    struct EstadoDosLimites: Equatable {
        var respeitados: Int
        var total: Int
        var categoriaMaisExcedida: String?
        var excesso: Decimal
    }

    struct Destaque: Equatable {
        var loja: String
        var vezes: Int
        var total: Decimal
    }

    struct Resultado: Equatable {
        var mes: Int
        var ano: Int
        var numeroDeMovimentos: Int
        var totalGasto: Decimal
        var totalGastoMesAnterior: Decimal?
        var categoriaPrincipal: CategoriaComValor?
        var categoriaQueMaisSubiu: SubidaDeCategoria?
        var diaMaisCaro: DiaDeGasto?
        var diaMaisPoupado: DiaDeGasto?
        var limites: EstadoDosLimites?
        var poupancaReservada: Decimal
        var objetivos: [Objetivo]
        var destaque: Destaque?

        /// Menos de 10 movimentos: versão curta, sem conclusões forçadas.
        var versaoCurta: Bool { numeroDeMovimentos < 10 }

        var diferencaVsMesAnterior: Decimal? {
            guard let anterior = totalGastoMesAnterior else { return nil }
            return totalGasto - anterior
        }

        /// Positiva = gastou mais do que no mês anterior.
        var fracaoVsMesAnterior: Double? {
            guard let anterior = totalGastoMesAnterior, anterior > .zero,
                  let diferenca = diferencaVsMesAnterior else { return nil }
            return (diferenca as NSDecimalNumber).doubleValue / (anterior as NSDecimalNumber).doubleValue
        }
    }

    static func calcular(_ entrada: Entrada) -> Resultado? {
        guard !entrada.movimentosDoMes.isEmpty else { return nil }
        let calendario = entrada.calendario

        let totalGasto = entrada.movimentosDoMes.reduce(Decimal.zero) { $0 + $1.valor }
        let totalAnterior: Decimal? = entrada.movimentosDoMesAnterior.isEmpty
            ? nil
            : entrada.movimentosDoMesAnterior.reduce(Decimal.zero) { $0 + $1.valor }

        func simbolo(da nome: String) -> String {
            entrada.categorias.first { $0.nome == nome }?.simbolo ?? "tag"
        }

        let porCategoria = Dictionary(grouping: entrada.movimentosDoMes) { $0.categoriaNome ?? "Sem categoria" }
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.valor } }
        let categoriaPrincipal: CategoriaComValor? = porCategoria
            .max { $0.value < $1.value }
            .map { nome, valor in
                let fracao = totalGasto > .zero
                    ? (valor as NSDecimalNumber).doubleValue / (totalGasto as NSDecimalNumber).doubleValue
                    : 0
                return CategoriaComValor(nome: nome, simbolo: simbolo(da: nome), valor: valor, fracaoDoTotal: fracao)
            }

        let porCategoriaAnterior = Dictionary(grouping: entrada.movimentosDoMesAnterior) { $0.categoriaNome ?? "Sem categoria" }
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.valor } }
        let categoriaQueMaisSubiu: SubidaDeCategoria? = porCategoria
            .compactMap { nome, valor -> SubidaDeCategoria? in
                let antes = porCategoriaAnterior[nome] ?? .zero
                let diferenca = valor - antes
                guard diferenca > .zero, antes > .zero else { return nil }
                return SubidaDeCategoria(nome: nome, simbolo: simbolo(da: nome), valorAgora: valor, valorAntes: antes, diferenca: diferenca)
            }
            .max { $0.diferenca < $1.diferenca }

        let porDia = Dictionary(grouping: entrada.movimentosDoMes) { calendario.startOfDay(for: $0.data) }
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.valor } }
        let diaMaisCaro = porDia.max { $0.value < $1.value }.map { DiaDeGasto(data: $0.key, valor: $0.value) }
        let diaMaisPoupado = porDia.min { $0.value < $1.value }.map { DiaDeGasto(data: $0.key, valor: $0.value) }

        let categoriasComLimite = entrada.categorias.filter { ($0.orcamentoMensal ?? .zero) > .zero }
        let limites: EstadoDosLimites? = categoriasComLimite.isEmpty ? nil : {
            var respeitados = 0
            var maiorExcesso: (nome: String, excesso: Decimal)?
            for categoria in categoriasComLimite {
                let gasto = porCategoria[categoria.nome] ?? .zero
                let orcamento = categoria.orcamentoMensal ?? .zero
                if gasto <= orcamento {
                    respeitados += 1
                } else {
                    let excesso = gasto - orcamento
                    if maiorExcesso == nil || excesso > maiorExcesso!.excesso {
                        maiorExcesso = (categoria.nome, excesso)
                    }
                }
            }
            return EstadoDosLimites(
                respeitados: respeitados,
                total: categoriasComLimite.count,
                categoriaMaisExcedida: maiorExcesso?.nome,
                excesso: maiorExcesso?.excesso ?? .zero
            )
        }()

        // O destaque curioso: o comerciante mais frequente, com 3 ou mais
        // visitas — menos do que isso não é um padrão, é acaso.
        let porLoja = Dictionary(grouping: entrada.movimentosDoMes.compactMap { movimento in
            movimento.loja.map { (loja: $0, movimento: movimento) }
        }) { $0.loja }
        let destaque: Destaque? = porLoja
            .map { loja, pares in (loja: loja, vezes: pares.count, total: pares.reduce(Decimal.zero) { $0 + $1.movimento.valor }) }
            .filter { $0.vezes >= 3 }
            .max { $0.vezes < $1.vezes }
            .map { Destaque(loja: $0.loja, vezes: $0.vezes, total: $0.total) }

        return Resultado(
            mes: entrada.mes,
            ano: entrada.ano,
            numeroDeMovimentos: entrada.movimentosDoMes.count,
            totalGasto: totalGasto,
            totalGastoMesAnterior: totalAnterior,
            categoriaPrincipal: categoriaPrincipal,
            categoriaQueMaisSubiu: categoriaQueMaisSubiu,
            diaMaisCaro: diaMaisCaro,
            diaMaisPoupado: diaMaisPoupado,
            limites: limites,
            poupancaReservada: entrada.poupancaReservadaNoMes,
            objetivos: entrada.objetivos,
            destaque: destaque
        )
    }
}
