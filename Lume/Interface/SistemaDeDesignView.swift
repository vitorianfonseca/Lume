import SwiftUI

/// A página do sistema de design, para o portefólio: tokens de cor, tipografia,
/// espaçamento, componentes e a regra dos ícones, todos ao vivo com o tema
/// escolhido (muda com `.id(paletaEscolhida)` como o resto da app).
///
/// Não faz parte da navegação da app — é um ecrã de referência, como as
/// folhas de comparação em `AcentoDosCartoes.swift`. Para a ver:
/// `#Preview` abaixo, ou chamar `SistemaDeDesignView()` a partir de um sítio
/// temporário (ex.: Perfil, em DEBUG) para tirar a captura de ecrã.
struct SistemaDeDesignView: View {
    @State private var opcaoDeExemplo = ExemploDeSeletor.primeira
    @State private var valorDeExemplo: Decimal = 1450

    enum ExemploDeSeletor: String, CaseIterable { case primeira = "Todos", segunda = "Despesas", terceira = "Receitas" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                cabecalho
                seccaoDeCor
                seccaoDeTipografia
                seccaoDeEspacamento
                seccaoDeBotoes
                seccaoDeEstados
                seccaoDeFormulario
                seccaoDeIcones
                seccaoDeValores
                seccaoDeCartoes
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Tema.fundo)
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 6) {
            Legenda("Sistema de design")
            Text("Lume")
                .font(Tema.fonte(34, .semibold))
                .foregroundStyle(Tema.tinta)
            Text("Tokens, componentes e a regra dos ícones — tudo o que a app partilha entre ecrãs, ao vivo com o tema \"\(Tema.paleta.nome)\".")
                .font(Tema.fonte(14))
                .foregroundStyle(Tema.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func titulo(_ texto: String) -> some View {
        Text(texto)
            .font(Tema.fonte(20, .semibold))
            .foregroundStyle(Tema.tinta)
    }

    // MARK: - Cor

    private struct Amostra: Identifiable {
        let id = UUID()
        let nome: String
        let papel: String
        let cor: Color
        var textoClaro = false
    }

    private var amostrasDeCor: [Amostra] {
        [
            .init(nome: "fundo", papel: "Fundo do ecrã", cor: Tema.fundo),
            .init(nome: "superficie", papel: "Cartões e campos", cor: Tema.superficie),
            .init(nome: "bege", papel: "Superfície de apoio (cinza-pedra)", cor: Tema.bege),
            .init(nome: "cafe", papel: "Cartões de destaque (oliva)", cor: Tema.cafe),
            .init(nome: "areia", papel: "Chips e separador selecionados", cor: Tema.areia),
            .init(nome: "douradoBotao", papel: "Ação (um só dourado)", cor: Tema.douradoBotao),
            .init(nome: "castanho / ouro", papel: "Texto de destaque", cor: Tema.castanho),
            .init(nome: "tinta", papel: "Texto principal", cor: Tema.tinta, textoClaro: true),
            .init(nome: "tintaSuave", papel: "Texto secundário", cor: Tema.tintaSuave, textoClaro: true),
            .init(nome: "placeholder", papel: "Placeholders (≥3,5:1)", cor: Tema.placeholder, textoClaro: true),
            .init(nome: "positivo", papel: "Receitas, confirmações", cor: Tema.positivo, textoClaro: true),
            .init(nome: "aviso", papel: "Perto do limite (75–99%)", cor: Tema.aviso, textoClaro: true),
            .init(nome: "negativo", papel: "Limite ultrapassado, apagar", cor: Tema.negativo, textoClaro: true),
            .init(nome: "separador", papel: "Linhas e contornos", cor: Tema.separador),
        ]
    }

    private var seccaoDeCor: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Cor")
            Text("Cada cor tem um só papel — nunca duas cores a competir pelo mesmo trabalho.")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(amostrasDeCor) { amostra in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(amostra.cor)
                            .frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Tema.separador, lineWidth: 0.5))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(amostra.nome)
                                .font(Tema.fonte(12, .semibold))
                                .foregroundStyle(Tema.tinta)
                            Text(amostra.papel)
                                .font(Tema.fonte(10))
                                .foregroundStyle(Tema.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tipografia

    private var seccaoDeTipografia: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Tipografia")
            Text("Instrument Sans. Nunca .title/.headline do sistema — sempre Tema.fonte(tamanho, peso).")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            VStack(alignment: .leading, spacing: 10) {
                linhaDeTipo("34 · Semibold", amostra: "O teu mês", tamanho: 34, peso: .semibold)
                linhaDeTipo("27 · Semibold", amostra: "Título de ecrã", tamanho: 27, peso: .semibold)
                linhaDeTipo("17 · Semibold", amostra: "Título de secção", tamanho: 17, peso: .semibold)
                linhaDeTipo("15 · Regular", amostra: "Corpo de texto", tamanho: 15, peso: .regular)
                linhaDeTipo("13 · Regular", amostra: "Texto secundário", tamanho: 13, peso: .regular)
                linhaDeTipo("11 · Medium, tracking 1.4", amostra: "LEGENDA", tamanho: 11, peso: .medium, tracking: 1.4)
            }
            .padding(16)
            .cartao()
        }
    }

    private func linhaDeTipo(_ rotulo: String, amostra: String, tamanho: CGFloat, peso: Font.Weight, tracking: CGFloat = 0) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(amostra)
                .font(Tema.fonte(tamanho, peso))
                .tracking(tracking)
                .foregroundStyle(tracking > 0 ? AnyShapeStyle(Tema.tintaSuave) : AnyShapeStyle(Tema.tinta))
            Spacer()
            Text(rotulo)
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    // MARK: - Espaçamento

    private var seccaoDeEspacamento: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Espaçamento e cantos")
            HStack(spacing: 20) {
                amostraDeRaio("Cartão", raio: Tema.Raio.cartao)
                amostraDeRaio("Campo", raio: Tema.Raio.campo)
                amostraDeRaio("Chip", raio: Tema.Raio.chip)
            }
            Text("Margem do ecrã: \(Int(Tema.margemDoEcra)) pt")
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    private func amostraDeRaio(_ nome: String, raio: CGFloat) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: raio)
                .fill(Tema.bege)
                .frame(width: 64, height: 64)
            Text("\(nome) · \(Int(raio))")
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
        }
    }

    // MARK: - Botões

    private var seccaoDeBotoes: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Botões")
            VStack(spacing: 10) {
                BotaoLume(titulo: "Criar novo objetivo", simbolo: "plus") {}
                BotaoLume(titulo: "Adicionar conta", simbolo: "plus", estilo: .secundario) {}
                BotaoLume(titulo: "Eliminar movimento", simbolo: "trash", estilo: .destrutivo) {}
                BotaoLume(titulo: "Guardar", simbolo: "checkmark") {}
                    .disabled(true)
                BotaoLume(titulo: "Limpar", estilo: .texto) {}
            }
        }
    }

    // MARK: - Estados

    private var seccaoDeEstados: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Cor de estado")
            Text("Neutro < 75% · âmbar 75–99% · vermelho ≥ 100% — nunca a mesma cor dourada para tudo.")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            VStack(spacing: 14) {
                linhaDeEstado("Subscrições", fracao: 0.33)
                linhaDeEstado("Transportes", fracao: 0.73)
                linhaDeEstado("Supermercado", fracao: 0.93)
                linhaDeEstado("Restauração", fracao: 1.12)
            }
            .padding(16)
            .cartao()
        }
    }

    private func linhaDeEstado(_ nome: String, fracao: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nome)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                CapsulaDePercentagem(fracao: fracao)
            }
            BarraDeProgresso(fracao: fracao, comEstado: true, marcador: 0.6)
        }
    }

    // MARK: - Formulário

    private var seccaoDeFormulario: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Formulário")
            SeletorSegmentado(opcoes: ExemploDeSeletor.allCases, escolhida: $opcaoDeExemplo, titulo: \.rawValue)
            VStack(spacing: 0) {
                LinhaDeFormulario(rotulo: "Categoria", simbolo: "square.grid.2x2") {
                    Text("Supermercado")
                }
                Divider().overlay(Tema.separador)
                LinhaDeFormulario(rotulo: "Valor", simbolo: "eurosign.circle", mostrarChevron: false) {
                    CampoDeEuros(valor: $valorDeExemplo)
                }
            }
            .padding(.horizontal, 16)
            .cartao()
        }
    }

    // MARK: - Ícones

    private var seccaoDeIcones: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Ícones")
            Text("Regra: 3D dourado para \"coisas\" (categorias, objetivos, poupança); linha fina para ações de interface (campos, botões, navegação).")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                VStack(spacing: 6) {
                    IconeDourado(simbolo: "cart.fill", lado: 44)
                    Text("Coisa").font(Tema.fonte(11)).foregroundStyle(Tema.tintaSuave)
                }
                VStack(spacing: 6) {
                    IconeDourado(simbolo: "shield.fill", lado: 44)
                    Text("Coisa").font(Tema.fonte(11)).foregroundStyle(Tema.tintaSuave)
                }
                VStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tema.tinta)
                        .frame(width: 44, height: 44)
                        .background(Tema.bege, in: Circle())
                    Text("Ação").font(Tema.fonte(11)).foregroundStyle(Tema.tintaSuave)
                }
                VStack(spacing: 6) {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Tema.castanho)
                        .frame(width: 44, height: 44)
                    Text("Ação").font(Tema.fonte(11)).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
    }

    // MARK: - Valores

    private var seccaoDeValores: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Valores")
            Text("Inteiro grande + cêntimos a ~48% · espaço fino nos milhares · sinal \"−\" tipográfico · algarismos tabulares.")
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ValorEmEuros(valor: 1450, tamanho: 34)
                ValorEmEuros(valor: -44.05, tamanho: 20, cor: Tema.negativo)
                ValorEmEuros(valor: 986.48, tamanho: 20)
            }
            .padding(16)
            .cartao()
        }
    }

    // MARK: - Cartões

    private var seccaoDeCartoes: some View {
        VStack(alignment: .leading, spacing: 14) {
            titulo("Cartões")
            VStack(alignment: .leading, spacing: 4) {
                Text("Cartão")
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                Text("Contorno subtil + sombra dupla — nunca background + strokeBorder à mão.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartao()

            VStack(alignment: .leading, spacing: 4) {
                Text("Cartão de destaque")
                    .font(Tema.fonte(14, .semibold))
                    .foregroundStyle(Tema.tinta)
                Text("\"Bom ritmo\", resumo do mês — cor oliva, só esta.")
                    .font(Tema.fonte(12))
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoCafe()
        }
    }
}

#Preview("Sistema de design") {
    SistemaDeDesignView()
}

#Preview("Sistema de design · Escuro") {
    SistemaDeDesignView()
        .preferredColorScheme(.dark)
}
