import SwiftUI

/// Perfil → Tema: o modo (automático, claro ou escuro), a pré-visualização
/// do Resumo no tema escolhido e a galeria dos 20 temas por família.
/// Tocar numa miniatura mostra-a em grande; "Usar este tema" só aparece
/// quando a escolha é diferente do tema atual.
///
/// É empurrado pela pilha do Perfil: o voltar é o do sistema.
struct TemasView: View {
    @AppStorage(Paleta.chave) private var paletaEscolhida = Paleta.padrao.id
    @AppStorage(ModoDeAparencia.chave) private var modo = ModoDeAparencia.automatico
    @State private var selecionada = Tema.paleta

    private var eAtual: Bool { selecionada.id == paletaEscolhida }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(legenda: "Perfil", titulo: "Tema")

                VStack(alignment: .leading, spacing: 8) {
                    SeletorSegmentado(
                        opcoes: ModoDeAparencia.allCases,
                        escolhida: $modo,
                        titulo: \.nome,
                        simbolo: { $0.simbolo }
                    )
                    if Paleta.com(id: paletaEscolhida).sempreEscura {
                        Text("O tema atual é sempre escuro. Escolhe um tema claro para usar o modo claro.")
                            .font(Tema.fonte(12))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                }

                // O tema selecionado, em grande: o Resumo tal como fica.
                AmostraDeTema(paleta: selecionada, modo: modo)
                    .frame(width: 210)
                    .frame(maxWidth: .infinity)
                    .sombraDeCartao()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(selecionada.nome)
                            .font(Tema.fonte(17, .semibold))
                            .foregroundStyle(Tema.tinta)
                        if eAtual {
                            Text("Em uso")
                                .font(Tema.fonte(11, .semibold))
                                .foregroundStyle(Tema.ouro)
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(Tema.areia, in: Capsule())
                        }
                    }
                    Text(selecionada.descricao)
                        .font(Tema.fonte(13))
                        .foregroundStyle(Tema.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Só quando há algo para mudar — o estado "atual" já se lê
                // na cápsula "Em uso".
                if !eAtual {
                    BotaoLume(titulo: "Usar este tema", simbolo: "paintbrush") {
                        // A paleta muda antes de a interface se reconstruir
                        // (`LumeApp` usa `.id(paletaEscolhida)`).
                        Tema.paleta = selecionada
                        paletaEscolhida = selecionada.id
                    }
                    .transition(.opacity)
                }

                ForEach(Paleta.Grupo.allCases, id: \.self) { grupo in
                    galeria(grupo)
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Tema.fundo)
        .toolbarBackground(Tema.fundo, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Tema.douradoEscuro)
    }

    /// Uma família de temas numa fila horizontal.
    private func galeria(_ grupo: Paleta.Grupo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                TituloDeSeccao(titulo: grupo.rawValue)
                Text(grupo.descricao)
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Paleta.todas.filter { $0.grupo == grupo }) { paleta in
                        miniatura(paleta)
                    }
                }
                // Espaço para o contorno e a sombra não serem cortados.
                .padding(.horizontal, Tema.margemDoEcra)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Tema.margemDoEcra)
        }
        .padding(.top, 6)
    }

    private func miniatura(_ paleta: Paleta) -> some View {
        let escolhida = selecionada == paleta
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selecionada = paleta }
        } label: {
            VStack(spacing: 8) {
                AmostraDeTema(paleta: paleta, modo: modo)
                    .frame(width: 96)
                    .overlay {
                        RoundedRectangle(cornerRadius: AmostraDeTema.raio(para: 96), style: .continuous)
                            .strokeBorder(Tema.douradoEscuro, lineWidth: escolhida ? 2.5 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if escolhida {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Tema.superficie, Tema.douradoEscuro)
                                .padding(5)
                        }
                    }
                Text(paleta.nome)
                    .font(Tema.fonte(12, escolhida ? .semibold : .medium))
                    .foregroundStyle(escolhida ? Tema.tinta : Tema.tintaSuave)
                    .lineLimit(1)
                    .frame(width: 96)
            }
        }
        .buttonStyle(EscalaAoTocar())
        .accessibilityLabel("\(paleta.nome): \(paleta.descricao)")
        .accessibilityValue(paleta.id == paletaEscolhida ? "Em uso" : "")
        .accessibilityAddTraits(escolhida ? [.isSelected] : [])
    }
}

/// Uma miniatura do Resumo verdadeiro, com as cores de uma paleta.
///
/// Desenhada às medidas reais do ecrã (390 pt de largura, as mesmas fontes,
/// raios e margens do `HojeView`) e escalada para o espaço que tiver: o
/// cabeçalho com a marca, o cartão do mês com a cápsula "No ritmo", o anel e
/// as duas colunas, as ações rápidas, a nota do ritmo, os limites com os
/// ícones dourados e a barra de separadores.
///
/// Os componentes partilhados (`ValorEmEuros`, `BarraDeProgresso`,
/// `AnelDoMes`…) leem a paleta em uso (`Tema.paleta`, global); aqui
/// replicam-se com as mesmas medidas, mas com as cores da paleta a pré-ver.
/// Os ícones das categorias e as ilustrações não dependem da paleta e são
/// os verdadeiros.
struct AmostraDeTema: View {
    let paleta: Paleta
    var modo: ModoDeAparencia = .automatico

    @Environment(\.colorScheme) private var esquemaDoSistema

    static let largura: CGFloat = 390
    static let altura: CGFloat = 780

    /// O raio do ecrã em miniatura, proporcional à largura.
    static func raio(para largura: CGFloat) -> CGFloat { largura * 0.11 }

    /// Os temas escuros são sempre escuros; os outros seguem o modo.
    private var esquema: ColorScheme {
        paleta.sempreEscura ? .dark : (modo.esquema ?? esquemaDoSistema)
    }

    var body: some View {
        GeometryReader { geometria in
            let forma = RoundedRectangle(cornerRadius: Self.raio(para: geometria.size.width), style: .continuous)
            ResumoEmMiniatura(paleta: paleta)
                .frame(width: Self.largura, height: Self.altura, alignment: .top)
                .scaleEffect(geometria.size.width / Self.largura, anchor: .topLeading)
                .frame(width: geometria.size.width, height: geometria.size.height, alignment: .topLeading)
                .clipShape(forma)
                .overlay(forma.strokeBorder(paleta.separador, lineWidth: 1))
        }
        .aspectRatio(Self.largura / Self.altura, contentMode: .fit)
        .environment(\.colorScheme, esquema)
        .accessibilityHidden(true)
    }
}

/// O Resumo às medidas reais, pintado com uma paleta.
private struct ResumoEmMiniatura: View {
    let paleta: Paleta
    @Environment(\.colorScheme) private var esquema

    /// O texto de destaque da paleta (`Tema.ouro`, mas para esta paleta).
    private var ouro: Color { paleta.acentoDourado ? Tema.castanho : paleta.douradoEscuro }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cabecalho
            cartaoDoMes
                .environment(\.colorScheme, paleta.cartaoPrincipalEscuro ? .dark : esquema)
            acoesRapidas
            notaDoRitmo
            limites
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .padding(.top, 62)
        .frame(width: AmostraDeTema.largura, height: AmostraDeTema.altura, alignment: .top)
        .background(paleta.fundo)
        .overlay(alignment: .bottom) { barraDeSeparadores.padding(.bottom, 24) }
    }

    // MARK: Cabeçalho (`CabecalhoDeEcra` com a marca)

    private var cabecalho: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("QUARTA-FEIRA, 30 SETEMBRO")
                    .font(Tema.fonte(11, .medium))
                    .tracking(1.4)
                    .foregroundStyle(paleta.tintaSuave)
                Text("O teu mês")
                    .font(Tema.fonte(27, .semibold))
                    .foregroundStyle(paleta.tinta)
            }
            Spacer()
            Image("SimboloLume")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 39.2)
        }
    }

    // MARK: Cartão do mês

    private var cartaoDoMes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SETEMBRO 2026")
                    .font(Tema.fonte(11, .semibold))
                    .tracking(1.4)
                    .foregroundStyle(ouro)
                Spacer()
                // A cápsula do ritmo, como no Resumo.
                Text("No ritmo")
                    .font(Tema.fonte(11, .semibold))
                    .foregroundStyle(paleta.positivo)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(paleta.positivo.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    valor("35", ",42 €", tamanho: 46)
                    Text("podes gastar por dia · faltam 6 dias")
                        .font(Tema.fonte(12))
                        .foregroundStyle(paleta.tintaSuave)
                }
                Spacer(minLength: 0)
                anel(fracao: 0.72, lado: 70)
            }

            paleta.separador.frame(height: 1).padding(.vertical, 2)

            HStack(spacing: 0) {
                coluna("Ainda disponível", "203", ",54 €")
                paleta.separador.frame(width: 1, height: 38)
                coluna("Já gastaste", "1 059", ",76 €")
                    .padding(.leading, 16)
            }

            paleta.separador.frame(height: 1).padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ritmo do mês")
                    Spacer()
                    Text("Dia 30 de 30 · orçamento 1 263 €")
                        .monospacedDigit()
                }
                .font(Tema.fonte(11))
                .foregroundStyle(paleta.tintaSuave)
                linhaDoRitmo.frame(height: 44)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CartaoDaPaleta(paleta: paleta))
    }

    /// `ValorEmEuros`: a parte inteira grande, "‚42 €" menor e suave.
    private func valor(_ inteiro: String, _ resto: String, tamanho: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(inteiro)
                .font(Tema.fonte(tamanho, .semibold))
                .foregroundStyle(paleta.tinta)
            Text(resto)
                .font(Tema.fonte(tamanho * 0.48, .medium))
                .foregroundStyle(paleta.tintaSuave)
        }
        .monospacedDigit()
        .lineLimit(1)
    }

    private func coluna(_ titulo: String, _ inteiro: String, _ resto: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(Tema.fonte(11))
                .foregroundStyle(paleta.tintaSuave)
            valor(inteiro, resto, tamanho: 21)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `AnelDoMes`, com o trilho da paleta.
    private func anel(fracao: Double, lado: CGFloat) -> some View {
        ZStack {
            Circle().stroke(paleta.bege, lineWidth: lado * 0.11)
            Circle()
                .trim(from: 0, to: fracao)
                .stroke(
                    AngularGradient(colors: [Tema.acento.corDe, Tema.acento.corAte, Tema.acento.corDe], center: .center),
                    style: StrokeStyle(lineWidth: lado * 0.11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(fracao * 100))%")
                    .font(Tema.fonte(lado * 0.24, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(paleta.tinta)
                Text("usado")
                    .font(Tema.fonte(lado * 0.13))
                    .foregroundStyle(paleta.tintaSuave)
            }
        }
        .frame(width: lado, height: lado)
    }

    /// O gráfico do ritmo: a linha ideal tracejada e o gasto acumulado.
    private var linhaDoRitmo: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let pontos: [CGFloat] = [0, 0.05, 0.12, 0.2, 0.26, 0.31, 0.4, 0.47, 0.52, 0.6, 0.66, 0.72]
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(paleta.tintaSuave.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                Path { p in
                    for (i, y) in pontos.enumerated() {
                        let ponto = CGPoint(x: w * CGFloat(i) / CGFloat(pontos.count - 1), y: h * (1 - y))
                        i == 0 ? p.move(to: ponto) : p.addLine(to: ponto)
                    }
                }
                .stroke(Tema.douradoDaBarra, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: Ações rápidas, nota e limites

    private var acoesRapidas: some View {
        HStack(spacing: 8) {
            acao("Escrever", simbolo: nil)
            acao("Falar", simbolo: "mic")
            acao("Talão", simbolo: "camera")
        }
    }

    private func acao(_ titulo: String, simbolo: String?) -> some View {
        HStack(spacing: 8) {
            Group {
                if let simbolo {
                    Image(systemName: simbolo).font(Tema.fonte(14))
                } else {
                    IconeDeTexto(tamanho: 14)
                }
            }
            .foregroundStyle(ouro)
            Text(titulo)
                .font(Tema.fonte(13, .medium))
                .foregroundStyle(paleta.tinta)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .modifier(CartaoDaPaleta(paleta: paleta, raio: 16))
    }

    /// A nota do ritmo vive no cartão de destaque (o mesmo em todos os temas).
    private var notaDoRitmo: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Bom ritmo este mês")
                    .font(Tema.fonte(16, .semibold))
                Text("Estás a gastar abaixo do ritmo ideal. O que sobrar pode ir para um objetivo.")
                    .font(Tema.fonte(13))
                    .opacity(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(paleta.tinta)
            Spacer(minLength: 0)
            Image(Ilustracao.Tipo.frasco.imagem)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 70, height: 84)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(Tema.cafe, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .environment(\.colorScheme, Tema.acento.cartaoEscuro ? .dark : esquema)
    }

    private var limites: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Os teus limites")
                    .font(Tema.fonte(17, .semibold))
                    .foregroundStyle(paleta.tinta)
                Spacer()
                Text("Ver todos")
                    .font(Tema.fonte(12, .medium))
                    .foregroundStyle(ouro)
            }
            limite("Supermercado", simbolo: "cart.fill", gasto: "276", orcamento: "300", fracao: 0.92)
            limite("Restauração", simbolo: "fork.knife", gasto: "84", orcamento: "140", fracao: 0.6)
        }
    }

    /// Um limite como no Resumo: ícone dourado verdadeiro, nome, valores,
    /// cápsula de percentagem (âmbar a partir de 75%) e barra.
    private func limite(_ nome: String, simbolo: String, gasto: String, orcamento: String, fracao: Double) -> some View {
        let cor = Tema.corDoLimite(fracao)
        return HStack(spacing: 12) {
            IconeDourado(simbolo: simbolo, lado: 38)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(nome)
                        .font(Tema.fonte(14, .semibold))
                        .foregroundStyle(paleta.tinta)
                    Spacer(minLength: 4)
                    Text("\(gasto) / \(orcamento) €")
                        .font(Tema.fonte(12))
                        .monospacedDigit()
                        .foregroundStyle(paleta.tintaSuave)
                    Text("\(Int(fracao * 100))%")
                        .font(Tema.fonte(11, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(cor ?? paleta.tintaSuave)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(cor == nil ? paleta.bege : Tema.fundoDoAviso, in: Capsule())
                }
                // `BarraDeProgresso(comEstado: true)`.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5).fill(paleta.bege)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(cor.map(AnyShapeStyle.init) ?? Tema.douradoDaBarra)
                            .frame(width: g.size.width * fracao)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(14)
        .modifier(CartaoDaPaleta(paleta: paleta, raio: 20))
    }

    // MARK: Barra de separadores

    private var barraDeSeparadores: some View {
        HStack(spacing: 0) {
            separador("Resumo", simbolo: "house", ativo: true)
            separador("Movimentos", simbolo: "list.bullet")
            VStack(spacing: 3) {
                Image("BotaoRegistar")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 28)
                    .frame(height: 28)
                Text("Registar")
                    .font(Tema.fonte(10, .medium))
                    .foregroundStyle(paleta.tintaSuave)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            separador("Planear", simbolo: "creditcard")
            separador("Perfil", simbolo: "person")
        }
        .padding(5)
        .frame(height: 64)
        .modifier(CartaoDaPaleta(paleta: paleta, raio: 32))
        .padding(.horizontal, 20)
    }

    private func separador(_ titulo: String, simbolo: String, ativo: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: simbolo)
                .font(.system(size: 17, weight: .medium))
                .frame(height: 28)
            Text(titulo)
                .font(Tema.fonte(10, ativo ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ativo ? ouro : paleta.tintaSuave)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if ativo {
                Capsule().fill(paleta.areia).padding(.vertical, 3).padding(.horizontal, 2)
            }
        }
    }
}

/// `EstiloDeCartao` com as cores da paleta a pré-ver: fundo, contorno
/// subtil e a sombra dos cartões.
private struct CartaoDaPaleta: ViewModifier {
    let paleta: Paleta
    var raio: CGFloat = Tema.Raio.cartao
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: raio)
                .fill(paleta.superficie)
                .overlay {
                    RoundedRectangle(cornerRadius: raio)
                        .strokeBorder(
                            esquema == .dark ? Color.white.opacity(0.07) : paleta.separador.opacity(0.7),
                            lineWidth: esquema == .dark ? 0.8 : 0.5
                        )
                }
                .shadow(color: .black.opacity(esquema == .dark ? 0.4 : 0.06), radius: 10, y: 5)
        }
    }
}

#Preview("Temas") {
    NavigationStack {
        TemasView()
    }
}

#Preview("Todos lado a lado") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
        ForEach(Paleta.todas) { paleta in
            VStack(spacing: 4) {
                AmostraDeTema(paleta: paleta)
                Text(paleta.nome).font(Tema.fonte(9, .semibold))
            }
        }
    }
    .padding(10)
}
