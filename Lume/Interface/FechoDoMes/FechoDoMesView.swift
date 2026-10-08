import SwiftData
import SwiftUI

/// Os cartões do fecho do mês, na ordem em que aparecem. A versão curta
/// (menos de 10 movimentos) usa só os três primeiros com dados — nunca
/// força uma conclusão sobre um mês com quase nada registado.
private enum CartaoDeFecho {
    case abertura, comparacao, categoria, dias, limites, objetivos, destaque, fecho
}

/// O resumo do mês, ao estilo "wrapped": ecrã inteiro, avança a toque ou
/// slide, barra de progresso no topo como nas histórias. Os números vêm
/// sempre do `FechoDoMes` (cálculo local); esta vista só desenha frases.
struct FechoDoMesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    @Query(sort: \Transacao.data) private var todasAsTransacoes: [Transacao]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Meta.nome) private var metas: [Meta]
    @Query private var todosOsReforcos: [ReforcoDaMeta]
    @AppStorage("partilharSoPercentagens") private var partilharSoPercentagens = false

    let mes: Int
    let ano: Int

    @State private var indice = 0

    private var calendario: Calendar { Calendar.current }

    private var resultado: FechoDoMes.Resultado? {
        let (mesAnterior, anoAnterior) = mesAnterior(mes: mes, ano: ano)
        let categoriasEntrada = categorias.map {
            FechoDoMes.Categoria(nome: $0.nome, simbolo: $0.simbolo, orcamentoMensal: $0.orcamentoMensal)
        }
        let poupancaNoMes = reforcos(doMes: mes, ano: ano).reduce(Decimal.zero) { $0 + $1.valor }
        let objetivosEntrada = metas.compactMap { meta -> FechoDoMes.Objetivo? in
            let reforcoDeste = reforcos(doMes: mes, ano: ano)
                .filter { $0.meta?.persistentModelID == meta.persistentModelID }
                .reduce(Decimal.zero) { $0 + $1.valor }
            guard reforcoDeste > .zero else { return nil }
            return FechoDoMes.Objetivo(
                nome: meta.nome,
                simbolo: meta.simbolo,
                valorAlvo: meta.valorAlvo,
                valorReforcadoNoMes: reforcoDeste,
                valorPoupadoAtual: meta.valorPoupado
            )
        }

        return FechoDoMes.calcular(FechoDoMes.Entrada(
            mes: mes,
            ano: ano,
            calendario: calendario,
            movimentosDoMes: transacoes(doMes: mes, ano: ano),
            movimentosDoMesAnterior: transacoes(doMes: mesAnterior, ano: anoAnterior),
            categorias: categoriasEntrada,
            poupancaReservadaNoMes: poupancaNoMes,
            objetivos: objetivosEntrada
        ))
    }

    /// Todas as despesas do mês, contas fixas incluídas — o total tem de
    /// bater certo com o que os Movimentos mostram para o mesmo mês.
    private func transacoes(doMes mes: Int, ano: Int) -> [FechoDoMes.Movimento] {
        todasAsTransacoes
            .filter { transacao in
                transacao.tipo == .despesa
                    && calendario.component(.year, from: transacao.data) == ano
                    && calendario.component(.month, from: transacao.data) == mes
            }
            .map { FechoDoMes.Movimento(valor: $0.valor, data: $0.data, categoriaNome: $0.categoria?.nome, loja: $0.loja) }
    }

    private func reforcos(doMes mes: Int, ano: Int) -> [ReforcoDaMeta] {
        todosOsReforcos.filter {
            calendario.component(.year, from: $0.data) == ano && calendario.component(.month, from: $0.data) == mes
        }
    }

    private func mesAnterior(mes: Int, ano: Int) -> (Int, Int) {
        mes == 1 ? (12, ano - 1) : (mes - 1, ano)
    }

    private var nomeDoMes: String {
        let data = calendario.date(from: DateComponents(year: ano, month: mes, day: 1)) ?? .now
        return data.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade))
    }

    private func cartaoValido(_ tipo: CartaoDeFecho, _ resultado: FechoDoMes.Resultado) -> Bool {
        switch tipo {
        case .abertura, .fecho: true
        case .comparacao: resultado.fracaoVsMesAnterior != nil
        case .categoria: resultado.categoriaPrincipal != nil
        case .dias: resultado.diaMaisCaro != nil && resultado.diaMaisPoupado != nil
        case .limites: resultado.limites != nil
        case .objetivos: !resultado.objetivos.isEmpty
        case .destaque: resultado.destaque != nil
        }
    }

    private var cartoes: [CartaoDeFecho] {
        guard let resultado else { return [] }
        let ordem: [CartaoDeFecho] = resultado.versaoCurta
            ? [.abertura, .categoria, .fecho]
            : [.abertura, .comparacao, .categoria, .dias, .limites, .objetivos, .destaque, .fecho]
        return ordem.filter { cartaoValido($0, resultado) }
    }

    var body: some View {
        ZStack {
            Tema.fundo.ignoresSafeArea()

            if let resultado, !cartoes.isEmpty {
                VStack(spacing: 0) {
                    barraDeProgresso
                        .padding(.horizontal, Tema.margemDoEcra)
                        .padding(.top, 8)

                    ZStack {
                        ForEach(Array(cartoes.enumerated()), id: \.offset) { posicao, tipo in
                            if posicao == indice {
                                cartao(tipo, resultado)
                                    .transition(reduzirMovimento ? .opacity : .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                    .animation(reduzirMovimento ? nil : .easeInOut(duration: 0.25), value: indice)
                }
                .overlay(alignment: .topTrailing) {
                    BotaoRedondo(simbolo: "xmark", rotulo: "Fechar") { dismiss() }
                        .padding(.horizontal, Tema.margemDoEcra)
                        .padding(.top, 8)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { valor in
                            if valor.translation.width < -40 { avancar() }
                            else if valor.translation.width > 40 { recuar() }
                        }
                )
                .onTapGesture(coordinateSpace: .local) { ponto in
                    // Um terço esquerdo volta atrás; o resto avança — como
                    // nas histórias, mas sem precisar de um alvo apertado.
                    if ponto.x < 120 { recuar() } else { avancar() }
                }
            } else {
                EstadoVazio(
                    ilustracao: .graficos,
                    titulo: "Ainda sem dados neste mês",
                    texto: "O fecho aparece depois do primeiro movimento registado em \(nomeDoMes)."
                )
                .padding(.horizontal, Tema.margemDoEcra)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    BotaoRedondo(simbolo: "xmark", rotulo: "Fechar") { dismiss() }
                        .padding(.horizontal, Tema.margemDoEcra)
                        .padding(.top, 8)
                }
            }
        }
    }

    private func avancar() {
        guard indice < cartoes.count - 1 else { return }
        indice += 1
    }

    private func recuar() {
        guard indice > 0 else { return }
        indice -= 1
    }

    private var barraDeProgresso: some View {
        HStack(spacing: 4) {
            ForEach(cartoes.indices, id: \.self) { posicao in
                Capsule()
                    .fill(posicao <= indice ? Tema.dourado : Tema.bege)
                    .frame(height: 3)
            }
        }
    }

    @ViewBuilder
    private func cartao(_ tipo: CartaoDeFecho, _ resultado: FechoDoMes.Resultado) -> some View {
        switch tipo {
        case .abertura: CartaoDeAbertura(nomeDoMes: nomeDoMes, total: resultado.totalGasto)
        case .comparacao: CartaoDeComparacao(nomeDoMes: nomeDoMes, resultado: resultado)
        case .categoria: CartaoDeCategoria(resultado: resultado)
        case .dias: CartaoDeDias(resultado: resultado)
        case .limites: CartaoDeLimites(resultado: resultado)
        case .objetivos: CartaoDeObjetivos(resultado: resultado)
        case .destaque: CartaoDeDestaque(resultado: resultado)
        case .fecho: CartaoDeFechoFinal(
            nomeDoMes: nomeDoMes,
            ano: ano,
            resultado: resultado,
            partilharSoPercentagens: $partilharSoPercentagens
        )
        }
    }
}

/// O que todos os cartões partilham: centrado, com a mesma margem.
private struct FundoDoCartao<Conteudo: View>: View {
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        VStack {
            Spacer()
            conteudo()
            Spacer()
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 1. Abertura

private struct CartaoDeAbertura: View {
    let nomeDoMes: String
    let total: Decimal

    var body: some View {
        FundoDoCartao {
            VStack(spacing: 14) {
                Text("O TEU \(nomeDoMes.uppercased())")
                    .font(Tema.fonte(13, .semibold))
                    .foregroundStyle(Tema.ouro)
                ContagemAnimada(valor: total)
                Text("foi o que gastaste este mês.")
                    .font(Tema.fonte(16))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("O teu \(nomeDoMes). Gastaste \(FormatadorDeMoeda.falado(total)).")
        }
    }
}

/// Um valor a contar de zero até ao alvo — "Reduzir movimento" salta
/// direto para o valor final.
private struct ContagemAnimada: View {
    let valor: Decimal
    var tamanho: CGFloat = 46

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var valorMostrado: Decimal = 0

    var body: some View {
        ValorEmEuros(valor: valorMostrado, tamanho: tamanho)
            .accessibilityHidden(true)
            .task {
                guard !reduzirMovimento else {
                    valorMostrado = valor
                    return
                }
                let passos = 24
                for passo in 1...passos {
                    try? await Task.sleep(for: .milliseconds(18))
                    valorMostrado = (valor * Decimal(passo) / Decimal(passos)).arredondadoACentimos()
                }
                valorMostrado = valor
            }
    }
}

// MARK: - 2. Comparação com o mês anterior

private struct CartaoDeComparacao: View {
    let nomeDoMes: String
    let resultado: FechoDoMes.Resultado

    private var gastouMenos: Bool { (resultado.fracaoVsMesAnterior ?? 0) <= 0 }

    private var frase: String {
        guard let diferenca = resultado.diferencaVsMesAnterior else { return "" }
        let valorAbsoluto = FormatadorDeMoeda.textoAbsoluto(diferenca)
        return gastouMenos
            ? "Gastaste menos \(valorAbsoluto) do que no mês passado."
            : "Gastaste mais \(valorAbsoluto) do que no mês passado."
    }

    private var percentagem: Int {
        Int(((resultado.fracaoVsMesAnterior ?? 0) * 100).rounded(.towardZero).magnitude)
    }

    var body: some View {
        FundoDoCartao {
            VStack(spacing: 14) {
                Image(systemName: gastouMenos ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(gastouMenos ? AnyShapeStyle(Tema.positivo) : Tema.ouro)
                Text(frase)
                    .font(Tema.fonte(22, .semibold))
                    .foregroundStyle(Tema.tinta)
                    .multilineTextAlignment(.center)
                Text("\(percentagem)% \(gastouMenos ? "a menos" : "a mais")")
                    .font(Tema.fonte(14))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(frase) \(percentagem)% \(gastouMenos ? "a menos" : "a mais").")
        }
    }
}

// MARK: - 3. Categoria principal e a que mais subiu

private struct CartaoDeCategoria: View {
    let resultado: FechoDoMes.Resultado

    var body: some View {
        FundoDoCartao {
            VStack(spacing: 24) {
                if let principal = resultado.categoriaPrincipal {
                    VStack(spacing: 10) {
                        IconeDourado(simbolo: principal.simbolo, lado: 64)
                        Text("\(principal.nome) foi a categoria que mais pesou")
                            .font(Tema.fonte(20, .semibold))
                            .foregroundStyle(Tema.tinta)
                            .multilineTextAlignment(.center)
                        Text("\(FormatadorDeMoeda.texto(principal.valor)) · \(Int((principal.fracaoDoTotal * 100).rounded()))% do mês")
                            .font(Tema.fonte(14))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(principal.nome) foi a categoria que mais pesou: \(FormatadorDeMoeda.falado(principal.valor)), \(Int((principal.fracaoDoTotal * 100).rounded())) por cento do mês.")
                }

                if let subiu = resultado.categoriaQueMaisSubiu {
                    VStack(spacing: 6) {
                        Text("E a que mais subiu")
                            .font(Tema.fonte(12, .semibold))
                            .foregroundStyle(Tema.ouro)
                        HStack(spacing: 8) {
                            IconeDourado(simbolo: subiu.simbolo, lado: 28)
                            Text("\(subiu.nome): +\(FormatadorDeMoeda.texto(subiu.diferenca))")
                                .font(Tema.fonte(15, .medium))
                                .foregroundStyle(Tema.tinta)
                        }
                    }
                    .padding(.top, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("A categoria que mais subiu foi \(subiu.nome), mais \(FormatadorDeMoeda.falado(subiu.diferenca)) do que no mês passado.")
                }
            }
        }
    }
}

// MARK: - 4. Dias extremos

private struct CartaoDeDias: View {
    let resultado: FechoDoMes.Resultado

    private func data(_ dia: FechoDoMes.DiaDeGasto) -> String {
        dia.data.formatted(.dateTime.day().month(.wide).locale(FormatadorDeMoeda.localidade))
    }

    var body: some View {
        FundoDoCartao {
            VStack(spacing: 28) {
                if let caro = resultado.diaMaisCaro {
                    linha(titulo: "O teu dia mais caro", dia: caro, cor: Tema.negativo)
                }
                if let poupado = resultado.diaMaisPoupado {
                    linha(titulo: "O teu dia mais poupado", dia: poupado, cor: Tema.positivo)
                }
            }
        }
    }

    private func linha(titulo: String, dia: FechoDoMes.DiaDeGasto, cor: Color) -> some View {
        VStack(spacing: 6) {
            Text(titulo.uppercased())
                .font(Tema.fonte(12, .semibold))
                .foregroundStyle(Tema.tintaSuave)
            Text(data(dia))
                .font(Tema.fonte(16, .medium))
                .foregroundStyle(Tema.tinta)
            Text(FormatadorDeMoeda.texto(dia.valor))
                .font(Tema.fonte(30, .semibold))
                .monospacedDigit()
                .foregroundStyle(cor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo): \(data(dia)), \(FormatadorDeMoeda.falado(dia.valor)).")
    }
}

// MARK: - 5. Limites

private struct CartaoDeLimites: View {
    let resultado: FechoDoMes.Resultado

    var body: some View {
        FundoDoCartao {
            if let limites = resultado.limites {
                VStack(spacing: 14) {
                    Text("\(limites.respeitados) de \(limites.total)")
                        .font(Tema.fonte(44, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Tema.tinta)
                    Text("limites respeitados este mês")
                        .font(Tema.fonte(16))
                        .foregroundStyle(Tema.tintaSuave)
                    if let categoria = limites.categoriaMaisExcedida {
                        Text("Passaste o de \(categoria) em \(FormatadorDeMoeda.texto(limites.excesso)) — sem drama, é só para saberes.")
                            .font(Tema.fonte(13))
                            .foregroundStyle(Tema.tintaSuave)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Respeitaste \(limites.respeitados) de \(limites.total) limites este mês."
                        + (limites.categoriaMaisExcedida.map { " Passaste o de \($0) em \(FormatadorDeMoeda.falado(limites.excesso))." } ?? "")
                )
            }
        }
    }
}

// MARK: - 6. Objetivos, com moedas a cair

private struct CartaoDeObjetivos: View {
    let resultado: FechoDoMes.Resultado
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var moedasCaidas = false

    private var totalReforcado: Decimal {
        resultado.objetivos.reduce(.zero) { $0 + $1.valorReforcadoNoMes }
    }

    var body: some View {
        FundoDoCartao {
            VStack(spacing: 18) {
                ZStack {
                    Image(Ilustracao.Tipo.frasco.imagem)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 96, height: 116)
                    if !reduzirMovimento {
                        ForEach(0..<5, id: \.self) { indice in
                            Circle()
                                .fill(Tema.ouroDasMoedas)
                                .frame(width: 12, height: 12)
                                .offset(x: CGFloat(indice - 2) * 10, y: moedasCaidas ? 20 : -90)
                                .opacity(moedasCaidas ? 1 : 0)
                        }
                    }
                }
                .frame(height: 140)
                .accessibilityHidden(true)
                .onAppear {
                    withAnimation(.interpolatingSpring(stiffness: 70, damping: 9).delay(0.1)) {
                        moedasCaidas = true
                    }
                }

                Text("Reservaste \(FormatadorDeMoeda.texto(totalReforcado)) para os teus objetivos")
                    .font(Tema.fonte(18, .semibold))
                    .foregroundStyle(Tema.tinta)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    ForEach(resultado.objetivos, id: \.nome) { objetivo in
                        let fracao = objetivo.valorAlvo > .zero
                            ? min(1, (objetivo.valorPoupadoAtual as NSDecimalNumber).doubleValue / (objetivo.valorAlvo as NSDecimalNumber).doubleValue)
                            : 0
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(objetivo.nome)
                                    .font(Tema.fonte(13, .medium))
                                    .foregroundStyle(Tema.tinta)
                                Spacer()
                                Text("\(Int((fracao * 100).rounded()))% hoje")
                                    .font(Tema.fonte(12))
                                    .foregroundStyle(Tema.tintaSuave)
                            }
                            BarraDeProgresso(fracao: fracao, altura: 5)
                        }
                    }
                }
                .frame(maxWidth: 280)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - 7. Destaque curioso

private struct CartaoDeDestaque: View {
    let resultado: FechoDoMes.Resultado

    var body: some View {
        FundoDoCartao {
            if let destaque = resultado.destaque {
                VStack(spacing: 14) {
                    Text("✨")
                        .font(.system(size: 40))
                    Text("Foste \(destaque.vezes) vezes a \(destaque.loja)")
                        .font(Tema.fonte(22, .semibold))
                        .foregroundStyle(Tema.tinta)
                        .multilineTextAlignment(.center)
                    Text(FormatadorDeMoeda.texto(destaque.total))
                        .font(Tema.fonte(16))
                        .foregroundStyle(Tema.tintaSuave)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Foste \(destaque.vezes) vezes a \(destaque.loja), um total de \(FormatadorDeMoeda.falado(destaque.total)).")
            }
        }
    }
}

// MARK: - 8. Fecho e partilha

private struct CartaoDeFechoFinal: View {
    let nomeDoMes: String
    let ano: Int
    let resultado: FechoDoMes.Resultado
    @Binding var partilharSoPercentagens: Bool

    @State private var imagemPartilhavel: Image?

    var body: some View {
        FundoDoCartao {
            VStack(spacing: 20) {
                ImagemDoResumo(nomeDoMes: nomeDoMes, resultado: resultado, soPercentagens: partilharSoPercentagens)
                    .frame(width: 220, height: 391)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

                Toggle("Partilhar só percentagens", isOn: $partilharSoPercentagens)
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                    .tint(Tema.dourado)
                    .frame(maxWidth: 260)

                if let imagemPartilhavel {
                    ShareLink(
                        item: imagemPartilhavel,
                        preview: SharePreview("O teu \(nomeDoMes)", image: imagemPartilhavel)
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Partilhar")
                        }
                        .font(Tema.fonte(15, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(EstiloDeBotaoLume(estilo: .principal))
                    .frame(maxWidth: 260)
                }
            }
            .task(id: partilharSoPercentagens) {
                imagemPartilhavel = renderizar()
            }
        }
    }

    /// 360×640 pt a escala 3 = 1080×1920 px — nítido em qualquer ecrã.
    private func renderizar() -> Image? {
        let vista = ImagemDoResumo(nomeDoMes: nomeDoMes, resultado: resultado, soPercentagens: partilharSoPercentagens)
            .frame(width: 360, height: 640)
        let renderizador = ImageRenderer(content: vista)
        renderizador.scale = 3
        guard let imagem = renderizador.uiImage else { return nil }
        return Image(uiImage: imagem)
    }
}

/// A imagem 9:16 para partilhar — resumo bonito, com ou sem valores
/// absolutos, conforme "Partilhar só percentagens".
private struct ImagemDoResumo: View {
    let nomeDoMes: String
    let resultado: FechoDoMes.Resultado
    let soPercentagens: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("SimboloLume")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 34)
            VStack(spacing: 8) {
                Text("O TEU \(nomeDoMes.uppercased())")
                    .font(Tema.fonte(13, .semibold))
                    .foregroundStyle(Tema.ouro)
                if soPercentagens, let fracao = resultado.fracaoVsMesAnterior {
                    Text("\(Int((fracao * 100).rounded().magnitude))%")
                        .font(Tema.fonte(52, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text(fracao <= 0 ? "a menos do que no mês passado" : "a mais do que no mês passado")
                        .font(Tema.fonte(14))
                        .foregroundStyle(Tema.tintaSuave)
                } else {
                    ValorEmEuros(valor: resultado.totalGasto, tamanho: 44)
                    Text("gastos este mês")
                        .font(Tema.fonte(14))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
            if let principal = resultado.categoriaPrincipal {
                HStack(spacing: 8) {
                    IconeDourado(simbolo: principal.simbolo, lado: 24)
                    Text(soPercentagens
                        ? "\(principal.nome) · \(Int((principal.fracaoDoTotal * 100).rounded()))%"
                        : "\(principal.nome) · \(FormatadorDeMoeda.texto(principal.valor))")
                        .font(Tema.fonte(13, .medium))
                        .foregroundStyle(Tema.tinta)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Tema.bege, in: Capsule())
            }
            Spacer()
            Text("Lume")
                .font(Tema.fonte(12, .semibold))
                .foregroundStyle(Tema.tintaSuave)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.fundo)
    }
}

#Preview("Fecho — completo") {
    FechoDoMesView(mes: 9, ano: 2026)
        .modelContainer(ContentorDeDados.emMemoria())
}
