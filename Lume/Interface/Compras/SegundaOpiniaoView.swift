import SwiftData
import SwiftUI

/// "Vale a pena?" — estou prestes a gastar dinheiro: é uma boa compra?
///
/// A pesquisa de preços é da IA; o impacto no orçamento é da app. É essa
/// soma que nenhum comparador de preços tem: 389 € não é só "bom preço",
/// são 6,5 dias do teu ritmo.
///
/// Abre-se numa folha a partir do Planear: o fechar fica no canto.
struct SegundaOpiniaoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query(sort: \Conta.nome) private var contas: [Conta]
    @Query private var transacoes: [Transacao]
    @Query(sort: \ConsultaDeCompra.consultadaEm, order: .reverse) private var consultas: [ConsultaDeCompra]

    /// O disponível e os dias vêm de quem nos abre — são as contas do Resumo.
    let disponivelDoMes: Decimal
    let diasRestantes: Int

    @State private var descricao = ""
    /// Vazio até a pessoa escrever: "0,00 €" é só o marcador.
    @State private var precoEscrito: Decimal?
    @State private var aProcurar = false
    @State private var conselho: Conselho?
    @State private var consultaGuardada: ConsultaDeCompra?
    @State private var mensagemDeErro: String?
    @State private var mostrarHistorico = false
    @State private var categoriaEscolhida: Categoria?
    /// O Keychain não avisa quando muda: relê-se ao fechar a configuração.
    @State private var temChave = InteligenciaView.temChave
    @State private var aConfigurar = false
    @FocusState private var campoFocado: Bool

    init(disponivelDoMes: Decimal, diasRestantes: Int) {
        self.disponivelDoMes = disponivelDoMes
        self.diasRestantes = diasRestantes
    }

    /// Para as pré-visualizações: abre já com um resultado.
    fileprivate init(disponivelDoMes: Decimal, diasRestantes: Int, exemplo: Conselho, preco: Decimal) {
        self.init(disponivelDoMes: disponivelDoMes, diasRestantes: diasRestantes)
        _conselho = State(initialValue: exemplo)
        _descricao = State(initialValue: exemplo.produto)
        _precoEscrito = State(initialValue: preco)
        _temChave = State(initialValue: true)
    }

    private var podePedir: Bool {
        temChave && !aProcurar && !descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CabecalhoDeEcra(
                    legenda: "Antes de pagares",
                    titulo: "Vale a pena?",
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                // A dependência vem primeiro, não depois de preencher tudo.
                if !temChave { ativarAnalise }

                entrada

                if aProcurar {
                    aPesquisar
                } else if let conselho {
                    resultado(conselho)
                } else if let mensagemDeErro {
                    erro(mensagemDeErro)
                } else {
                    comoFunciona
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .animation(.snappy(duration: 0.25), value: aProcurar)
            .animation(.snappy(duration: 0.25), value: conselho)
        }
        .background(Tema.fundo)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $mostrarHistorico) {
            HistoricoDePrecosView(produto: conselho?.produto ?? descricao, consultas: consultas)
        }
        .sheet(isPresented: $aConfigurar, onDismiss: { temChave = InteligenciaView.temChave }) {
            NavigationStack {
                InteligenciaView(aoFechar: { aConfigurar = false })
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - Ativar a análise

    /// Sem chave do Claude: o convite, em palavras simples, com o atalho
    /// direto para a configurar.
    private var ativarAnalise: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tema.ouro)
                    .frame(width: 36, height: 36)
                    .background(Tema.superficie, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ativa a análise inteligente")
                        .font(Tema.fonte(16, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text("Para saber se vale a pena, a Lume procura preços e opiniões na internet com o Claude, da Anthropic. Basta ligá-lo uma vez, com a tua chave.")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            BotaoLume(titulo: "Ativar agora", simbolo: "arrow.right", fundoPersonalizado: Tema.superficie) { aConfigurar = true }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoCafe()
    }

    // MARK: - Entrada

    private var entrada: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Legenda("O que vais comprar")
                    TextField(
                        text: $descricao,
                        prompt: Text("Ex.: auscultadores Sony").foregroundStyle(Tema.placeholder),
                        axis: .vertical
                    ) {
                        Text("O que vais comprar")
                    }
                    // O exemplo mais pequeno do que o texto real, para não
                    // se ler como um produto já escrito.
                    .font(descricao.isEmpty ? Tema.fonte(17) : Tema.fonte(21, .medium))
                    .foregroundStyle(Tema.tinta)
                    .lineLimit(1...3)
                    .focused($campoFocado)
                    .submitLabel(.search)
                    .onSubmit { pedirOpiniao() }
                }

                Divider().overlay(Tema.separador)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preço que vais pagar")
                            .font(Tema.fonte(15))
                            .foregroundStyle(Tema.tinta)
                        Text("Opcional")
                            .font(Tema.fonte(12))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    Spacer(minLength: 8)
                    TextField(value: $precoEscrito, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                        Text("Preço que vais pagar")
                    }
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Tema.fonte(15, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
                    .padding(.horizontal, 10)
                    .frame(width: 128, height: 36)
                    .background(Tema.bege, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartao()
            // Sem chave, o formulário fica em espera até ser ativado.
            .disabled(!temChave)
            .opacity(temChave ? 1 : 0.6)

            // Com um resultado à vista, a ação principal passa a ser a
            // decisão; procurar outra vez fica secundário.
            BotaoLume(
                titulo: aProcurar ? "A procurar…" : (conselho == nil ? "Ver se vale a pena" : "Procurar outra vez"),
                simbolo: "magnifyingglass",
                estilo: conselho == nil ? .principal : .secundario
            ) {
                pedirOpiniao()
            }
            .disabled(!podePedir)
        }
    }

    private var aPesquisar: some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(Tema.douradoEscuro)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text("A procurar preços e opiniões…")
                    .font(Tema.fonte(15, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("A Lume está a ver lojas e o que dizem os compradores. Demora alguns segundos.")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
        .accessibilityElement(children: .combine)
    }

    private func erro(_ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tema.aviso)
            Text(texto)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .cartao(Tema.fundoDoAviso)
        .accessibilityElement(children: .combine)
    }

    private var comoFunciona: some View {
        VStack(alignment: .leading, spacing: 12) {
            Legenda("Como funciona")
            linhaDeExplicacao(1, "A Lume procura o preço em lojas e o que dizem os compradores.")
            linhaDeExplicacao(2, "Compara com o que vais pagar e com o que já viu antes.")
            linhaDeExplicacao(3, "Mostra o que esta compra custa ao teu mês, em dias do teu ritmo.")
            if temChave {
                Text("Precisa de internet. Só a pergunta sai do teu iPhone.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cartao(Tema.bege)
    }

    private func linhaDeExplicacao(_ numero: Int, _ texto: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(numero)")
                .font(Tema.fonte(12, .semibold))
                .monospacedDigit()
                .foregroundStyle(Tema.ouro)
                .frame(width: 22, height: 22)
                .background(Tema.superficie, in: Circle())
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(texto)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Resultado

    private func resultado(_ conselho: Conselho) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            cartaoDoVeredicto(conselho)
            cartaoDoImpacto(conselho)
            if !conselho.problemas.isEmpty { cartaoDosProblemas(conselho) }
            if let nome = conselho.alternativaNome { alternativa(nome, preco: conselho.alternativaPreco) }
            acoes(conselho)
            decisao(conselho)
            if !conselho.fontes.isEmpty { fontes(conselho) }
        }
        .transition(.opacity)
    }

    /// O veredicto: produto, a cápsula do nível, o preço e a comparação.
    private func cartaoDoVeredicto(_ conselho: Conselho) -> some View {
        let estilo = estiloDoNivel(conselho.nivel)
        let preco = precoDaPessoa(conselho)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(conselho.produto)
                    .font(Tema.fonte(17, .semibold))
                    .foregroundStyle(Tema.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Label(estilo.titulo, systemImage: estilo.simbolo)
                    .font(Tema.fonte(12, .semibold))
                    .foregroundStyle(estilo.cor)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(estilo.fundo, in: Capsule())
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 2) {
                ValorEmEuros(valor: preco, tamanho: 38)
                Text(precoEscrito.map { $0 > .zero } == true ? "o preço que vais pagar" : "o preço que a Lume encontrou")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }

            let linhas = linhasDeComparacao(conselho)
            if !linhas.isEmpty {
                VStack(spacing: 0) {
                    ForEach(linhas, id: \.titulo) { linha in
                        linhaDePreco(linha)
                        if linha.titulo != linhas.last?.titulo {
                            Divider().overlay(Tema.separador)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Tema.bege, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            }

            if let barato = conselho.precoMaisBarato, preco > barato {
                Text("Pagas mais \(FormatadorDeMoeda.texto(preco - barato)) do que o mais barato encontrado.")
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.aviso)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(conselho.veredicto)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    private struct LinhaDePreco {
        let titulo: String
        let valor: Decimal
        var detalhe: String?
    }

    private func linhasDeComparacao(_ conselho: Conselho) -> [LinhaDePreco] {
        var linhas: [LinhaDePreco] = []
        if let normal = conselho.precoNormal {
            linhas.append(.init(titulo: "Preço normal", valor: normal))
        }
        if let barato = conselho.precoMaisBarato {
            linhas.append(.init(titulo: "Mais barato encontrado", valor: barato, detalhe: conselho.lojaMaisBarata))
        }
        if let visto = menorPrecoJaVisto(para: conselho.produto) {
            linhas.append(.init(titulo: "Menor preço que a Lume viu", valor: visto))
        }
        return linhas
    }

    private func linhaDePreco(_ linha: LinhaDePreco) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(linha.titulo)
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tinta)
                if let detalhe = linha.detalhe {
                    Text(detalhe)
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
            Spacer(minLength: 8)
            Text(FormatadorDeMoeda.texto(linha.valor))
                .font(Tema.fonte(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func cartaoDosProblemas(_ conselho: Conselho) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Legenda(conselho.problemas.count == 1 ? "O que os compradores apontam" : "O que os compradores mais apontam")
            ForEach(conselho.problemas, id: \.self) { problema in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tema.aviso)
                        .accessibilityHidden(true)
                    Text(problema)
                        .font(Tema.fonte(14))
                        .foregroundStyle(Tema.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cartao()
    }

    /// O cartão que só a Lume consegue mostrar — o único em destaque.
    private func cartaoDoImpacto(_ conselho: Conselho) -> some View {
        let impacto = impactoDe(conselho)
        return VStack(alignment: .leading, spacing: 12) {
            Legenda("O que isto custa ao teu mês")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(impacto.diasDoRitmo.formatted(.number.precision(.fractionLength(0...1)).locale(FormatadorDeMoeda.localidade)))
                    .font(Tema.fonte(38, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
                Text(impacto.diasDoRitmo == 1 ? "dia do teu ritmo" : "dias do teu ritmo")
                    .font(Tema.fonte(15, .medium))
                    .foregroundStyle(Tema.tinta)
            }
            .accessibilityElement(children: .combine)

            if impacto.estouraOMes {
                Text("Ficavas \(FormatadorDeMoeda.texto(-impacto.disponivelDepois)) acima do orçamento deste mês.")
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.negativo)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Antes e depois, lado a lado.
                HStack(spacing: 0) {
                    colunaDoImpacto("Por dia agora", impacto.porDiaAntes)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tema.tintaSuave)
                        .padding(.horizontal, 10)
                        .accessibilityHidden(true)
                    colunaDoImpacto("Depois da compra", impacto.porDiaDepois)
                }
                Text("Ficavas com \(FormatadorDeMoeda.texto(impacto.disponivelDepois)) até ao fim do mês.")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Tema.separador)

            // A categoria é opcional: sem ela, o impacto é só do mês.
            Menu {
                Picker("Categoria", selection: $categoriaEscolhida) {
                    Text("Sem categoria").tag(Categoria?.none)
                    ForEach(categorias) { categoria in
                        Text(categoria.nome).tag(Categoria?.some(categoria))
                    }
                }
            } label: {
                LinhaDeFormulario(rotulo: "Categoria", simbolo: "square.grid.2x2") {
                    Text(categoriaEscolhida?.nome ?? "Nenhuma")
                }
            }
            .buttonStyle(.plain)

            if let categoria = categoriaEscolhida, let sobra = impacto.sobraNaCategoria {
                Text(impacto.estouraACategoria
                    ? "Passava o limite de \(categoria.nome) em \(FormatadorDeMoeda.texto(-sobra))."
                    : "Em \(categoria.nome) sobravam \(FormatadorDeMoeda.texto(sobra)).")
                    .font(Tema.fonte(13, impacto.estouraACategoria ? .medium : .regular))
                    .foregroundStyle(impacto.estouraACategoria ? Tema.negativo : Tema.tintaSuave)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cartaoCafe()
    }

    private func colunaDoImpacto(_ titulo: String, _ valor: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
            ValorEmEuros(valor: valor, tamanho: 21)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func alternativa(_ nome: String, preco: Decimal?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tema.ouro)
                .frame(width: 36, height: 36)
                .background(Tema.bege, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Legenda("Alternativa")
                Text(preco.map { "\(nome) por \(FormatadorDeMoeda.texto($0))" } ?? nome)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cartao()
        .accessibilityElement(children: .combine)
    }

    private func acoes(_ conselho: Conselho) -> some View {
        HStack(spacing: 8) {
            if let endereco = conselho.fontes.first?.endereco, let url = URL(string: endereco) {
                Link(destination: url) {
                    etiqueta("Comparar", simbolo: "safari")
                }
                .buttonStyle(EscalaAoTocar())
            }
            Button {
                mostrarHistorico = true
            } label: {
                etiqueta("Histórico", simbolo: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(EscalaAoTocar())
            Button {
                vigiar(conselho)
            } label: {
                etiqueta(
                    consultaGuardada?.aVigiar == true ? "A vigiar" : "Avisar",
                    simbolo: consultaGuardada?.aVigiar == true ? "bell.fill" : "bell"
                )
            }
            .buttonStyle(EscalaAoTocar())
            .accessibilityHint("Avisa quando o preço descer")
        }
    }

    /// Ações de apoio no estilo secundário do `BotaoLume`, em tamanho curto.
    private func etiqueta(_ titulo: String, simbolo: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: simbolo)
                .font(.system(size: 13, weight: .semibold))
            Text(titulo)
                .font(Tema.fonte(13, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(Tema.ouro)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Tema.bege, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
    }

    private func decisao(_ conselho: Conselho) -> some View {
        VStack(spacing: 4) {
            BotaoLume(titulo: "Comprei — registar despesa", simbolo: "checkmark") { registarCompra(conselho) }
            BotaoLume(titulo: "Não vou comprar", estilo: .texto) { dispensar() }
        }
    }

    private func fontes(_ conselho: Conselho) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Legenda("Onde a Lume viu")
            ForEach(conselho.fontes, id: \.endereco) { fonte in
                if let url = URL(string: fonte.endereco) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text(fonte.nome)
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(Tema.fonte(13, .medium))
                        .foregroundStyle(Tema.ouro)
                        .frame(minHeight: 30)
                    }
                }
            }
            Text("Os preços mudam. Confirma na loja antes de pagar.")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
                .padding(.top, 2)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Contas e estado

    /// O preço que conta é o que a pessoa escreveu; sem isso, o que se encontrou.
    private func precoDaPessoa(_ conselho: Conselho) -> Decimal {
        if let precoEscrito, precoEscrito > .zero { return precoEscrito }
        return conselho.precoAtual ?? .zero
    }

    private func impactoDe(_ conselho: Conselho) -> ImpactoDeCompra.Resultado {
        let calendario = Calendar.current
        let gastoNaCategoria = categoriaEscolhida.map { categoria in
            transacoes
                .filter {
                    $0.tipo == .despesa
                        && $0.categoria?.persistentModelID == categoria.persistentModelID
                        && calendario.isDate($0.data, equalTo: .now, toGranularity: .month)
                }
                .reduce(Decimal.zero) { $0 + $1.valor }
        }

        return ImpactoDeCompra.calcular(.init(
            preco: precoDaPessoa(conselho),
            disponivelDoMes: disponivelDoMes,
            diasRestantes: diasRestantes,
            gastoNaCategoria: gastoNaCategoria,
            orcamentoDaCategoria: categoriaEscolhida?.orcamentoMensal
        ))
    }

    /// O histórico honesto: o mais baixo que nós próprios registámos.
    private func menorPrecoJaVisto(para produto: String) -> Decimal? {
        consultas
            .filter { $0.produto.localizedCaseInsensitiveCompare(produto) == .orderedSame }
            .compactMap { $0.precoMaisBarato ?? $0.precoConsultado }
            .min()
    }

    /// O nível do preço nas cores de estado da app: positivo, aviso, negativo.
    private func estiloDoNivel(_ nivel: NivelDePreco) -> (titulo: String, simbolo: String, cor: Color, fundo: Color) {
        switch nivel {
        case .bom: ("Bom preço", "checkmark.circle.fill", Tema.positivo, Tema.positivo.opacity(0.12))
        case .razoavel: ("Razoável", "equal.circle.fill", Tema.aviso, Tema.fundoDoAviso)
        case .mau: ("Caro", "exclamationmark.circle.fill", Tema.negativo, Tema.fundoNegativo)
        }
    }

    // MARK: - Ações

    private func pedirOpiniao() {
        campoFocado = false
        let pergunta = descricao.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pergunta.isEmpty, !aProcurar else { return }
        guard let chave = CofreDeChaves.ler(CofreDeChaves.contaClaude), !chave.isEmpty else {
            temChave = false
            return
        }

        aProcurar = true
        mensagemDeErro = nil
        conselho = nil
        consultaGuardada = nil
        let precoIndicado = precoEscrito.flatMap { $0 > .zero ? $0 : nil }

        Task {
            defer { aProcurar = false }
            do {
                let obtido = try await ConselheiroDeCompras(chave: chave)
                    .avaliar(pergunta, precoDaPessoa: precoIndicado)
                conselho = obtido
                if precoIndicado == nil, let encontrado = obtido.precoAtual {
                    precoEscrito = encontrado
                }
                guardar(obtido)
            } catch ErroDeConselho.produtoNaoEncontrado {
                mensagemDeErro = "Não consegui identificar esse produto. Tenta com a marca e o modelo."
            } catch {
                mensagemDeErro = "Não consegui procurar agora. Verifica a ligação e tenta outra vez."
            }
        }
    }

    /// Cada consulta fica guardada — é assim que o histórico de preços cresce.
    private func guardar(_ conselho: Conselho) {
        let consulta = ConsultaDeCompra(
            produto: conselho.produto,
            precoConsultado: precoDaPessoa(conselho),
            precoNormal: conselho.precoNormal,
            precoMaisBarato: conselho.precoMaisBarato,
            lojaMaisBarata: conselho.lojaMaisBarata,
            veredicto: conselho.veredicto,
            nivel: conselho.nivel,
            problemas: conselho.problemas,
            alternativaNome: conselho.alternativaNome,
            alternativaPreco: conselho.alternativaPreco,
            fontes: conselho.fontes
        )
        contexto.insert(consulta)
        try? contexto.save()
        consultaGuardada = consulta
    }

    private func vigiar(_ conselho: Conselho) {
        guard let consulta = consultaGuardada else { return }
        consulta.aVigiar.toggle()
        consulta.precoAlvo = consulta.aVigiar
            ? (conselho.precoMaisBarato ?? precoDaPessoa(conselho))
            : nil
        try? contexto.save()
    }

    private func registarCompra(_ conselho: Conselho) {
        let transacao = Transacao(
            valor: precoDaPessoa(conselho),
            tipo: .despesa,
            descricao: conselho.produto,
            loja: conselho.lojaMaisBarata,
            data: .now,
            categoria: categoriaEscolhida,
            conta: contas.first(where: \.principal) ?? contas.first,
            origem: .manual
        )
        contexto.insert(transacao)
        consultaGuardada?.decisao = .comprou
        try? contexto.save()
        dismiss()
    }

    private func dispensar() {
        consultaGuardada?.decisao = .dispensou
        try? contexto.save()
        dismiss()
    }
}

/// O histórico do que a Lume já viu para este produto — sem invenções.
private struct HistoricoDePrecosView: View {
    let produto: String
    let consultas: [ConsultaDeCompra]

    private var doProduto: [ConsultaDeCompra] {
        consultas.filter { $0.produto.localizedCaseInsensitiveCompare(produto) == .orderedSame }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CabecalhoDeEcra(legenda: "Vale a pena?", titulo: "Histórico de preços")

                if doProduto.isEmpty {
                    Text("Esta é a primeira vez que consultas \(produto). A partir de agora, cada consulta fica aqui e podes ver o preço a mexer-se.")
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                } else {
                    VStack(spacing: 0) {
                        ForEach(doProduto) { consulta in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(consulta.consultadaEm.formatted(
                                        .dateTime.day().month(.wide).locale(FormatadorDeMoeda.localidade)
                                    ))
                                    .font(Tema.fonte(13, .medium))
                                    .foregroundStyle(Tema.tinta)
                                    if let loja = consulta.lojaMaisBarata {
                                        Text(loja)
                                            .font(Tema.fonte(11))
                                            .foregroundStyle(Tema.tintaSuave)
                                    }
                                }
                                Spacer()
                                Text(FormatadorDeMoeda.texto(consulta.precoMaisBarato ?? consulta.precoConsultado))
                                    .font(Tema.fonte(15, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Tema.tinta)
                            }
                            .frame(height: 52)
                            Divider().overlay(Tema.separador)
                        }
                    }
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .background(Tema.fundo)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Sem chave") {
    SegundaOpiniaoView(disponivelDoMes: 357.10, diasRestantes: 6)
        .modelContainer(ContentorDeDados.emMemoria())
}

#Preview("Resultado") {
    SegundaOpiniaoView(
        disponivelDoMes: 357.10,
        diasRestantes: 6,
        exemplo: Conselho(
            produto: "Sony WH-1000XM6",
            precoAtual: 389,
            precoNormal: 449,
            precoMaisBarato: 359,
            lojaMaisBarata: "Worten",
            nivel: .razoavel,
            veredicto: "É um preço razoável: está abaixo do normal, mas já esteve a 359 € na Worten esta semana.",
            problemas: ["A almofada aquece em uso prolongado.", "O estojo é maior do que o da geração anterior."],
            alternativaNome: "Sony WH-1000XM5",
            alternativaPreco: 279,
            fontes: [FonteDePreco(nome: "worten.pt", endereco: "https://www.worten.pt"), FonteDePreco(nome: "kuantokusta.pt", endereco: "https://www.kuantokusta.pt")]
        ),
        preco: 389
    )
    .modelContainer(ContentorDeDados.emMemoria())
}
