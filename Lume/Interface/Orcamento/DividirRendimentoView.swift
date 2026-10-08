import SwiftData
import SwiftUI

/// Um valor recebido à espera de ser dividido (para abrir a folha com `.sheet(item:)`).
struct ValorParaDividir: Identifiable {
    let id = UUID()
    let valor: Decimal
}

/// Dividir o dinheiro recebido pelas categorias: quanto vai para cada uma e
/// quanto fica de poupança. Ao guardar, o valor de cada categoria passa a ser
/// o seu limite do mês e o total passa a ser o orçamento do mês.
///
/// No topo, "Dividir à minha medida" abre o questionário: a proposta da IA
/// preenche os campos, com o motivo de cada parte, para se rever antes de guardar.
struct DividirRendimentoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var definicoes: [DefinicoesDoMes]

    /// O valor recebido; editável, para se poder dividir outro montante.
    @State private var total: Decimal
    @State private var valores: [PersistentIdentifier: Decimal] = [:]
    @State private var poupanca: Decimal = .zero
    @State private var preenchido = false

    /// A proposta do questionário, com os motivos de cada parte.
    @State private var proposta: PropostaDeDivisao?
    @State private var motivos: [PersistentIdentifier: String] = [:]
    @State private var mostrarQuestionario = false

    /// Depois de guardar: o estado "concluído", com o que ficou guardado.
    @State private var guardado: DivisaoGuardada?

    private struct DivisaoGuardada {
        var total: Decimal
        var poupanca: Decimal
        var categoriasComLimite: Int
        var mes: String
    }

    init(valor: Decimal) {
        self.total = valor
    }

    private var distribuido: Decimal {
        valores.values.reduce(Decimal.zero, +) + poupanca
    }

    private var porDistribuir: Decimal { total - distribuido }

    private var tudoDistribuido: Bool { total > .zero && porDistribuir == .zero }

    var body: some View {
        Group {
            if let guardado {
                concluido(guardado)
                    .transition(.opacity)
            } else {
                divisao
                    .transition(.opacity)
            }
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $mostrarQuestionario) {
            QuestionarioDeDivisaoView(total: total) { nova in
                aplicar(nova)
            }
        }
        .onAppear {
            guard !preenchido else { return }
            preenchido = true
            distribuirComoOsLimites()
        }
    }

    private var divisao: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(
                    legenda: "Recebeste dinheiro",
                    titulo: "Dividir o dinheiro",
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                if let proposta {
                    cartaoDaProposta(proposta)
                } else {
                    aMinhaMedida
                }

                resumo
                atalhos

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        TituloDeSeccao(titulo: "Por categoria")
                        // Destrutivo e discreto: separado dos dois atalhos.
                        BotaoLume(titulo: "Limpar", estilo: .texto) {
                            withAnimation(.snappy(duration: 0.2)) {
                                valores = [:]
                                poupanca = .zero
                            }
                        }
                        .disabled(distribuido == .zero)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(categorias.enumerated()), id: \.element.persistentModelID) { indice, categoria in
                            linha(categoria, cor: Self.tom(indice))
                            Divider().overlay(Tema.separador)
                        }
                        linhaDaPoupanca
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .cartao()
                }

                Text("O valor de cada categoria passa a ser o seu limite deste mês, e o total recebido passa a ser o orçamento do mês.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        // O botão de guardar fica sempre à vista, por cima da lista.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                BotaoLume(titulo: "Guardar divisão", simbolo: "checkmark") { guardar() }
                    .disabled(!tudoDistribuido)
                if !tudoDistribuido, total > .zero {
                    Text(porDistribuir > .zero
                        ? "Distribui os \(FormatadorDeMoeda.texto(porDistribuir)) que faltam para guardar."
                        : "Tira \(FormatadorDeMoeda.texto(-porDistribuir)) para não passares do recebido.")
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Tema.fundo)
        }
    }

    // MARK: - À minha medida

    /// O convite para o questionário: o caminho mais fácil fica em cima.
    private var aMinhaMedida: some View {
        Button {
            mostrarQuestionario = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .textoDourado()
                    .frame(width: 40, height: 40)
                    .background(Tema.superficie.opacity(0.7), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dividir à minha medida")
                        .font(Tema.fonte(16, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text("Responde a 8 perguntas e a Lume propõe a divisão.")
                        .font(Tema.fonte(12))
                        .foregroundStyle(Tema.tintaSuave)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoCafe()
        }
        .buttonStyle(EscalaAoTocar())
    }

    /// Depois do questionário: a lógica da proposta e quem a fez.
    private func cartaoDaProposta(_ proposta: PropostaDeDivisao) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .textoDourado()
                Legenda(proposta.autoria)
            }
            Text(proposta.resumo)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Revê os valores antes de guardar.")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                BotaoLume(titulo: "Refazer questionário", simbolo: "arrow.counterclockwise", estilo: .texto) {
                    mostrarQuestionario = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoCafe()
    }

    // MARK: - Resumo

    private var resumo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Legenda("Recebido")
            TextField(value: $total, format: .euros, prompt: Text("0,00 €").foregroundStyle(Tema.placeholder)) {
                Text("Valor recebido")
            }
            .keyboardType(.decimalPad)
            .font(Tema.fonte(34, .semibold))
            .monospacedDigit()
            .foregroundStyle(Tema.tinta)

            BarraDaDivisao(
                fatias: categorias.enumerated().map { indice, categoria in
                    (valores[categoria.persistentModelID] ?? .zero, Self.tom(indice))
                } + [(poupanca, Self.tomDaPoupanca)],
                total: total
            )

            HStack {
                Text(porDistribuir >= .zero ? "Por distribuir" : "Distribuíste a mais")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                if tudoDistribuido {
                    Label("Tudo distribuído", systemImage: "checkmark.circle.fill")
                        .font(Tema.fonte(13, .semibold))
                        .foregroundStyle(Tema.positivo)
                } else {
                    Text(FormatadorDeMoeda.textoAbsoluto(porDistribuir))
                        .font(Tema.fonte(14, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(porDistribuir >= .zero ? Tema.tinta : Tema.negativo)
                }
            }

            if porDistribuir > .zero, distribuido > .zero {
                BotaoLume(titulo: "Pôr o resto na poupança", simbolo: "arrow.down.to.line", estilo: .texto) {
                    withAnimation(.snappy(duration: 0.2)) { poupanca += porDistribuir }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    // MARK: - Atalhos

    private var atalhos: some View {
        HStack(spacing: 10) {
            atalho("Como os limites", simbolo: "chart.bar.fill") { distribuirComoOsLimites() }
            atalho("Partes iguais", simbolo: "equal") { distribuirEmPartesIguais() }
        }
    }

    private func atalho(_ titulo: String, simbolo: String, acao: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                acao()
                proposta = nil
                motivos = [:]
            }
        } label: {
            Label(titulo, systemImage: simbolo)
                .font(Tema.fonte(13, .medium))
                .textoDourado()
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Tema.bege, in: RoundedRectangle(cornerRadius: Tema.Raio.chip))
        }
        .buttonStyle(EscalaAoTocar())
    }

    // MARK: - Linhas

    private func linha(_ categoria: Categoria, cor: Color) -> some View {
        let valor = Binding(
            get: { valores[categoria.persistentModelID] ?? .zero },
            set: { valores[categoria.persistentModelID] = $0 }
        )
        return HStack(alignment: .center, spacing: 12) {
            IconeDeCategoria(categoria: categoria, lado: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(categoria.nome)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                legendaDaLinha(
                    cor: cor,
                    percentagem: percentagem(de: valor.wrappedValue),
                    motivo: motivos[categoria.persistentModelID]
                )
            }
            Spacer(minLength: 8)
            CampoDeEuros(valor: valor)
        }
        .padding(.vertical, 10)
    }

    private var linhaDaPoupanca: some View {
        HStack(alignment: .center, spacing: 12) {
            IconeDourado(simbolo: "banknote.fill", lado: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("Poupança")
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                legendaDaLinha(
                    cor: Self.tomDaPoupanca,
                    percentagem: percentagem(de: poupanca),
                    motivo: proposta.map(\.motivoDaPoupanca)
                )
            }
            Spacer(minLength: 8)
            CampoDeEuros(valor: $poupanca)
        }
        .padding(.vertical, 10)
    }

    /// A cor da fatia, a percentagem e, com proposta, o motivo da IA.
    private func legendaDaLinha(cor: Color, percentagem: String, motivo: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(cor).frame(width: 7, height: 7)
                Text(percentagem)
                    .font(Tema.fonte(11))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
            }
            if let motivo, !motivo.isEmpty {
                Text(motivo)
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func percentagem(de valor: Decimal) -> String {
        guard total > .zero else { return "0% do recebido" }
        let fracao = (valor as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue
        return "\(Int((fracao * 100).rounded()))% do recebido"
    }

    // MARK: - Tons da barra

    /// Tons da família areia/castanho, um por categoria (repetem-se depois
    /// do oitavo), distintos entre si e com contraste contra o trilho bege.
    private static let tons: [Color] = [
        Color(claro: 0x7E5A38, escuro: 0xD9C2A3),
        Color(claro: 0xB08A5E, escuro: 0xB8976E),
        Color(claro: 0x5E4630, escuro: 0xEAD9BF),
        Color(claro: 0xC9A97E, escuro: 0x9C7A57),
        Color(claro: 0x94714C, escuro: 0xCDB08A),
        Color(claro: 0xD9BF97, escuro: 0x7E6248),
        Color(claro: 0x6E5238, escuro: 0xE0C9A6),
        Color(claro: 0xA3825C, escuro: 0xAE8E68),
    ]

    private static func tom(_ indice: Int) -> Color { tons[indice % tons.count] }

    /// A poupança no dourado das peças, para se destacar das categorias.
    private static let tomDaPoupanca = Color(claro: 0xC9A45A, escuro: 0xE3C47E)

    // MARK: - Distribuições

    /// Na proporção dos limites atuais (e da poupança planeada), em euros
    /// inteiros; o que sobra dos arredondamentos fica por distribuir. Sem
    /// limites definidos, divide em partes iguais.
    private func distribuirComoOsLimites() {
        let poupancaAtual = definicoesDoMes?.poupancaPlaneada ?? .zero
        let pesos = categorias.map { $0.orcamentoMensal ?? .zero }
        let soma = pesos.reduce(Decimal.zero, +) + poupancaAtual
        guard soma > .zero else {
            distribuirEmPartesIguais()
            return
        }
        var novos: [PersistentIdentifier: Decimal] = [:]
        for (categoria, peso) in zip(categorias, pesos) where peso > .zero {
            novos[categoria.persistentModelID] = arredondar(total * peso / soma)
        }
        valores = novos
        poupanca = arredondar(total * poupancaAtual / soma)
    }

    private func distribuirEmPartesIguais() {
        guard !categorias.isEmpty else { return }
        let parte = arredondar(total / Decimal(categorias.count))
        valores = Dictionary(uniqueKeysWithValues: categorias.map { ($0.persistentModelID, parte) })
        poupanca = .zero
    }

    /// Para baixo, ao euro: a soma nunca passa do recebido.
    private func arredondar(_ valor: Decimal) -> Decimal {
        var origem = valor
        var resultado = Decimal()
        NSDecimalRound(&resultado, &origem, 0, .down)
        return resultado
    }

    /// Preenche os campos com a proposta do questionário (pelo nome da categoria).
    private func aplicar(_ nova: PropostaDeDivisao) {
        var novosValores: [PersistentIdentifier: Decimal] = [:]
        var novosMotivos: [PersistentIdentifier: String] = [:]
        for categoria in categorias {
            guard let parte = nova.partes.first(where: { $0.categoria == categoria.nome }) else { continue }
            if parte.valor > .zero { novosValores[categoria.persistentModelID] = parte.valor }
            novosMotivos[categoria.persistentModelID] = parte.motivo
        }
        withAnimation(.snappy(duration: 0.2)) {
            valores = novosValores
            motivos = novosMotivos
            poupanca = nova.poupanca
            proposta = nova
        }
    }

    // MARK: - Guardar

    private var definicoesDoMes: DefinicoesDoMes? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }
    }

    private func guardar() {
        for categoria in categorias {
            let valor = valores[categoria.persistentModelID] ?? .zero
            categoria.orcamentoMensal = valor > .zero ? valor : nil
        }
        // Sem `@Attribute(.unique)` (CloudKit): procurar antes de inserir.
        let mes: DefinicoesDoMes
        if let existente = definicoesDoMes {
            mes = existente
        } else {
            let calendario = Calendar.current
            mes = DefinicoesDoMes(
                ano: calendario.component(.year, from: .now),
                mes: calendario.component(.month, from: .now)
            )
            contexto.insert(mes)
        }
        mes.rendimentoEsperado = total
        mes.poupancaPlaneada = poupanca
        try? contexto.save()

        SomDoSistema.sucesso.tocar()
        withAnimation(.easeOut(duration: 0.2)) {
            guardado = DivisaoGuardada(
                total: total,
                poupanca: poupanca,
                categoriasComLimite: valores.values.filter { $0 > .zero }.count,
                mes: Date.now.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).lowercased()
            )
        }
    }

    // MARK: - Concluído

    private func concluido(_ resumo: DivisaoGuardada) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(Tema.positivo)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Divisão guardada")
                    .font(Tema.fonte(27, .semibold))
                    .foregroundStyle(Tema.tinta)
                    .accessibilityAddTraits(.isHeader)
                Text("Os limites de \(resumo.mes) já seguem esta divisão.")
                    .font(Tema.fonte(14))
                    .foregroundStyle(Tema.tintaSuave)
            }

            VStack(spacing: 0) {
                linhaDoResumo("Orçamento de \(resumo.mes)", FormatadorDeMoeda.texto(resumo.total))
                Divider().overlay(Tema.separador)
                linhaDoResumo("Categorias com limite", "\(resumo.categoriasComLimite)")
                Divider().overlay(Tema.separador)
                linhaDoResumo("Poupança", FormatadorDeMoeda.texto(resumo.poupanca))
            }
            .padding(.horizontal, 16)
            .cartao()

            Spacer(minLength: 0)

            BotaoLume(titulo: "Feito") { dismiss() }
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func linhaDoResumo(_ rotulo: String, _ valor: String) -> some View {
        HStack {
            Text(rotulo)
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(valor)
                .font(Tema.fonte(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// A barra segmentada da divisão: uma fatia por categoria e uma pela
/// poupança, sobre o trilho bege (o que fica por distribuir).
private struct BarraDaDivisao: View {
    let fatias: [(valor: Decimal, cor: Color)]
    let total: Decimal

    var body: some View {
        let visiveis = fatias.filter { $0.valor > .zero }
        let soma = visiveis.reduce(Decimal.zero) { $0 + $1.valor }
        // Se se distribuiu a mais, a barra enche e as fatias encolhem na proporção.
        let base = (max(total, soma) as NSDecimalNumber).doubleValue
        GeometryReader { geometria in
            let espacos = CGFloat(max(visiveis.count - 1, 0)) * 2
            let largura = max(geometria.size.width - espacos, 0)
            HStack(spacing: 2) {
                ForEach(visiveis.indices, id: \.self) { indice in
                    let fracao = base > 0 ? (visiveis[indice].valor as NSDecimalNumber).doubleValue / base : 0
                    Rectangle()
                        .fill(visiveis[indice].cor)
                        .frame(width: largura * CGFloat(fracao))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.bege)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(height: 10)
        .animation(.snappy(duration: 0.25), value: soma)
        .accessibilityElement()
        .accessibilityLabel("Divisão do recebido")
        .accessibilityValue(base > 0 ? "\(Int(((soma as NSDecimalNumber).doubleValue / base * 100).rounded())) por cento distribuído" : "Nada distribuído")
    }
}

#Preview {
    DividirRendimentoView(valor: 1450)
        .modelContainer(ContentorDeDados.emMemoria())
}
