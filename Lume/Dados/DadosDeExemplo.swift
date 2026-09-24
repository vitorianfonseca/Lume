import Foundation
import SwiftData

/// Dados realistas em Portugal para Previews, testes e para o simulador
/// em desenvolvimento. Nunca é chamado no contentor de produção em Release.
@MainActor
enum DadosDeExemplo {
    /// Semeia apenas na primeira execução — usado em DEBUG para o simulador
    /// não abrir despido. A marca em UserDefaults evita que os dados renasçam
    /// depois de um "Repor a app".
    static func semearSeVazio(em contexto: ModelContext) {
        let chave = "dadosDeExemploSemeados"
        guard !UserDefaults.standard.bool(forKey: chave) else { return }
        defer { UserDefaults.standard.set(true, forKey: chave) }

        let categorias = (try? contexto.fetchCount(FetchDescriptor<Categoria>())) ?? 0
        guard categorias == 0 else { return }
        semear(em: contexto)
    }

    static func semear(em contexto: ModelContext) {
        // MARK: Categorias
        // Orçamentos calibrados para o rendimento de exemplo: o Supermercado
        // anda nos 90% (barra dourada), os restantes com folga (barra cinzenta).

        let supermercado = Categoria(nome: "Supermercado", simbolo: "cart.fill", corHex: "7B8B6F", orcamentoMensal: eur("160"), ordem: 0)
        let restauracao = Categoria(nome: "Restauração", simbolo: "fork.knife", corHex: "B0713C", orcamentoMensal: eur("90"), ordem: 1)
        let transportes = Categoria(nome: "Transportes", simbolo: "tram.fill", corHex: "5B7B94", orcamentoMensal: eur("120"), ordem: 2)
        let casa = Categoria(nome: "Casa", simbolo: "house.fill", corHex: "8A8A85", ordem: 3)
        let subscricoes = Categoria(nome: "Subscrições", simbolo: "play.rectangle.fill", corHex: "6E5B94", orcamentoMensal: eur("40"), ordem: 4)
        let saude = Categoria(nome: "Saúde", simbolo: "cross.case.fill", corHex: "94525B", ordem: 5)
        let lazer = Categoria(nome: "Lazer", simbolo: "ticket.fill", corHex: "C9A45A", orcamentoMensal: eur("60"), ordem: 6)
        let roupa = Categoria(nome: "Roupa", simbolo: "tshirt.fill", corHex: "9A7B94", ordem: 7)

        // MARK: Contas

        let revolut = Conta(nome: "Revolut", tipo: .aOrdem, saldoInicial: eur("342.18"), principal: true)
        let cgd = Conta(nome: "CGD", tipo: .aOrdem, saldoInicial: eur("1580.00"))
        let dinheiro = Conta(nome: "Dinheiro", tipo: .dinheiro, saldoInicial: eur("35.00"))

        // MARK: Recorrentes

        let renda = Recorrente(nome: "Renda", valor: eur("650"), diaDoMes: 1, categoria: casa)
        let edp = Recorrente(nome: "EDP", valor: eur("48.30"), diaDoMes: 8, categoria: casa)
        let navegante = Recorrente(nome: "Passe Navegante", valor: eur("40"), diaDoMes: 1, categoria: transportes)
        let netflix = Recorrente(nome: "Netflix", valor: eur("12.99"), diaDoMes: 15, categoria: subscricoes)
        let spotify = Recorrente(nome: "Spotify", valor: eur("11.99"), diaDoMes: 20, categoria: subscricoes)

        // MARK: Transações — mês corrente

        let mesCorrente = [
            // Hoje
            Transacao(valor: eur("0.80"), descricao: "Café", loja: "Pastelaria do bairro", data: .now, categoria: restauracao, conta: dinheiro, origem: .texto),
            Transacao(valor: eur("12.50"), descricao: "Almoço", loja: "Time Out Market", data: .now, categoria: restauracao, conta: revolut, origem: .texto),
            // Últimos dias
            Transacao(valor: eur("23.41"), descricao: "Compras", loja: "Pingo Doce", data: diasAtras(1), categoria: supermercado, conta: revolut, origem: .texto),
            Transacao(valor: eur("8.00"), descricao: "Uber", data: diasAtras(1), categoria: transportes, conta: revolut, origem: .texto),
            Transacao(valor: eur("3.20"), descricao: "Pastel de nata e galão", data: diasAtras(2), categoria: restauracao, conta: dinheiro, origem: .texto),
            Transacao(valor: eur("54.12"), descricao: "Compras da semana", loja: "Continente", data: diasAtras(3), categoria: supermercado, conta: cgd, origem: .manual),
            Transacao(valor: eur("18.90"), descricao: "Farmácia", data: diasAtras(4), categoria: saude, conta: revolut, origem: .manual),
            Transacao(valor: eur("40.00"), descricao: "Gasolina", loja: "Galp", data: diasAtras(5), categoria: transportes, conta: cgd, origem: .manual),
            Transacao(valor: eur("31.75"), descricao: "Compras", loja: "Lidl", data: diasAtras(7), categoria: supermercado, conta: revolut, origem: .texto),
            Transacao(valor: eur("14.20"), descricao: "Brunch", data: diasAtras(8), categoria: restauracao, conta: revolut, origem: .texto),
            Transacao(valor: eur("12.40"), descricao: "Mercearia do bairro", data: diasAtras(9), categoria: supermercado, conta: dinheiro, origem: .manual),
            Transacao(valor: eur("15.50"), descricao: "Cinema", data: diasAtras(10), categoria: lazer, conta: revolut, origem: .texto),
            Transacao(valor: eur("26.90"), descricao: "Compras", loja: "Auchan", data: diasAtras(11), categoria: supermercado, conta: cgd, origem: .manual),
            Transacao(valor: eur("21.90"), descricao: "Jantar com amigos", data: diasAtras(13), categoria: restauracao, conta: revolut, origem: .texto),
            Transacao(valor: eur("12.90"), descricao: "Livro", loja: "Bertrand", data: diasAtras(16), categoria: lazer, conta: revolut, origem: .manual),
            // Contas fixas pagas — ligadas às recorrentes para não contarem duas vezes
            Transacao(valor: eur("650"), descricao: "Renda", data: nesteMes(dia: 1), categoria: casa, conta: cgd, recorrente: renda, origem: .manual),
            Transacao(valor: eur("40"), descricao: "Passe Navegante", data: nesteMes(dia: 1), categoria: transportes, conta: cgd, recorrente: navegante, origem: .manual),
            Transacao(valor: eur("48.30"), descricao: "EDP", data: nesteMes(dia: 8), categoria: casa, conta: cgd, recorrente: edp, origem: .manual),
            Transacao(valor: eur("12.99"), descricao: "Netflix", data: nesteMes(dia: 15), categoria: subscricoes, conta: revolut, recorrente: netflix, origem: .manual),
            Transacao(valor: eur("11.99"), descricao: "Spotify", data: nesteMes(dia: 20), categoria: subscricoes, conta: revolut, recorrente: spotify, origem: .manual),
            // Receita
            Transacao(valor: eur("1450"), tipo: .receita, descricao: "Salário", data: nesteMes(dia: 1), conta: cgd, origem: .manual),
        ]

        // MARK: Transações — mês passado

        let mesPassado = [
            Transacao(valor: eur("1450"), tipo: .receita, descricao: "Salário", data: mesesAtras(1, dia: 1), conta: cgd, origem: .manual),
            Transacao(valor: eur("120"), tipo: .receita, descricao: "Explicações", data: mesesAtras(1, dia: 14), conta: revolut, origem: .manual),
            Transacao(valor: eur("650"), descricao: "Renda", data: mesesAtras(1, dia: 1), categoria: casa, conta: cgd, recorrente: renda, origem: .manual),
            Transacao(valor: eur("40"), descricao: "Passe Navegante", data: mesesAtras(1, dia: 1), categoria: transportes, conta: cgd, recorrente: navegante, origem: .manual),
            Transacao(valor: eur("47.10"), descricao: "EDP", data: mesesAtras(1, dia: 8), categoria: casa, conta: cgd, recorrente: edp, origem: .manual),
            Transacao(valor: eur("12.99"), descricao: "Netflix", data: mesesAtras(1, dia: 15), categoria: subscricoes, conta: revolut, recorrente: netflix, origem: .manual),
            Transacao(valor: eur("11.99"), descricao: "Spotify", data: mesesAtras(1, dia: 20), categoria: subscricoes, conta: revolut, recorrente: spotify, origem: .manual),
            Transacao(valor: eur("28.65"), descricao: "Compras", loja: "Pingo Doce", data: mesesAtras(1, dia: 2), categoria: supermercado, conta: revolut, origem: .texto),
            Transacao(valor: eur("41.20"), descricao: "Gasolina", loja: "Galp", data: mesesAtras(1, dia: 5), categoria: transportes, conta: cgd, origem: .manual),
            Transacao(valor: eur("61.20"), descricao: "Compras da semana", loja: "Continente", data: mesesAtras(1, dia: 6), categoria: supermercado, conta: cgd, origem: .manual),
            Transacao(valor: eur("46.80"), descricao: "Jantar de aniversário", data: mesesAtras(1, dia: 9), categoria: restauracao, conta: revolut, origem: .texto),
            Transacao(valor: eur("39.99"), descricao: "Camisola", loja: "Zara", data: mesesAtras(1, dia: 11), categoria: roupa, conta: revolut, origem: .manual),
            Transacao(valor: eur("24.18"), descricao: "Compras", loja: "Lidl", data: mesesAtras(1, dia: 13), categoria: supermercado, conta: revolut, origem: .texto),
            Transacao(valor: eur("29.99"), descricao: "Jogo de tabuleiro", loja: "Fnac", data: mesesAtras(1, dia: 17), categoria: lazer, conta: revolut, origem: .manual),
            Transacao(valor: eur("9.60"), descricao: "Farmácia", data: mesesAtras(1, dia: 19), categoria: saude, conta: dinheiro, origem: .manual),
            Transacao(valor: eur("4.60"), descricao: "Café com a Marta", data: mesesAtras(1, dia: 24), categoria: restauracao, conta: dinheiro, origem: .texto),
            Transacao(valor: eur("6.50"), descricao: "Uber", data: mesesAtras(1, dia: 26), categoria: transportes, conta: revolut, origem: .texto),
            Transacao(valor: eur("5.35"), descricao: "Padaria", data: mesesAtras(1, dia: 28), categoria: restauracao, conta: dinheiro, origem: .manual),
        ]

        // MARK: Transações — há dois meses

        let doisMesesAtras = [
            Transacao(valor: eur("1450"), tipo: .receita, descricao: "Salário", data: mesesAtras(2, dia: 1), conta: cgd, origem: .manual),
            Transacao(valor: eur("650"), descricao: "Renda", data: mesesAtras(2, dia: 1), categoria: casa, conta: cgd, recorrente: renda, origem: .manual),
            Transacao(valor: eur("40"), descricao: "Passe Navegante", data: mesesAtras(2, dia: 1), categoria: transportes, conta: cgd, recorrente: navegante, origem: .manual),
            Transacao(valor: eur("52.75"), descricao: "EDP", data: mesesAtras(2, dia: 8), categoria: casa, conta: cgd, recorrente: edp, origem: .manual),
            Transacao(valor: eur("58.43"), descricao: "Compras da semana", loja: "Continente", data: mesesAtras(2, dia: 4), categoria: supermercado, conta: cgd, origem: .manual),
            Transacao(valor: eur("24.90"), descricao: "Comboio Lisboa–Porto", loja: "CP", data: mesesAtras(2, dia: 10), categoria: transportes, conta: revolut, origem: .manual),
            Transacao(valor: eur("89.90"), descricao: "Estante", loja: "IKEA", data: mesesAtras(2, dia: 12), categoria: casa, conta: cgd, origem: .manual),
            Transacao(valor: eur("33.20"), descricao: "Jantar no Porto", data: mesesAtras(2, dia: 18), categoria: restauracao, conta: revolut, origem: .texto),
            Transacao(valor: eur("27.99"), descricao: "T-shirts", loja: "H&M", data: mesesAtras(2, dia: 22), categoria: roupa, conta: revolut, origem: .manual),
            Transacao(valor: eur("59.99"), descricao: "Auscultadores", loja: "Worten", data: mesesAtras(2, dia: 25), categoria: lazer, conta: revolut, origem: .manual),
        ]

        // MARK: Metas e definições do mês

        let metas = [
            Meta(nome: "Fundo de emergência", valorAlvo: eur("3000"), valorPoupado: eur("850"), simbolo: "shield.fill"),
            Meta(nome: "Viagem aos Açores", valorAlvo: eur("900"), valorPoupado: eur("240"), simbolo: "airplane"),
        ]

        let hoje = Calendar.current.dateComponents([.year, .month], from: .now)
        let definicoes = DefinicoesDoMes(
            ano: hoje.year ?? 2026,
            mes: hoje.month ?? 1,
            rendimentoEsperado: eur("1450"),
            poupancaPlaneada: eur("200")
        )

        for categoria in [supermercado, restauracao, transportes, casa, subscricoes, saude, lazer, roupa] {
            contexto.insert(categoria)
        }
        for conta in [revolut, cgd, dinheiro] {
            contexto.insert(conta)
        }
        for recorrente in [renda, edp, navegante, netflix, spotify] {
            contexto.insert(recorrente)
        }
        (mesCorrente + mesPassado + doisMesesAtras).forEach { contexto.insert($0) }
        metas.forEach { contexto.insert($0) }
        contexto.insert(definicoes)

        try? contexto.save()
    }

    // MARK: - Auxiliares

    /// Constrói `Decimal` a partir de texto para evitar o arredondamento binário
    /// que existiria ao passar por `Double` (ex.: `Decimal(0.80)`).
    private static func eur(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }

    private static func diasAtras(_ dias: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -dias, to: .now) ?? .now
    }

    private static func nesteMes(dia: Int) -> Date {
        var componentes = Calendar.current.dateComponents([.year, .month], from: .now)
        componentes.day = dia
        return Calendar.current.date(from: componentes) ?? .now
    }

    private static func mesesAtras(_ meses: Int, dia: Int) -> Date {
        let calendario = Calendar.current
        let base = calendario.date(byAdding: .month, value: -meses, to: .now) ?? .now
        var componentes = calendario.dateComponents([.year, .month], from: base)
        componentes.day = dia
        return calendario.date(from: componentes) ?? base
    }
}
