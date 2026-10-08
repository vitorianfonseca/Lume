import SwiftUI

/// O detalhe de um movimento — o ecrã 11 do Figma: ícone da categoria ao
/// centro, valor em grande e as linhas Categoria/Conta/Data/Origem no mesmo
/// padrão do editor.
struct MovimentoView: View {
    let transacao: Transacao
    let aoEditar: () -> Void
    let aoFechar: () -> Void

    @State private var mostrarTalao = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Cabeçalho padrão dos ecrãs secundários, com fechar
                // (o detalhe abre numa folha).
                CabecalhoDeEcra(
                    legenda: legendaDaData,
                    titulo: "O movimento",
                    aoVoltar: aoFechar,
                    simboloDeVoltar: "xmark"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                // O cartão do movimento: o ícone 3D da categoria, o nome e o
                // valor com euros grandes e cêntimos pequenos.
                VStack(spacing: 12) {
                    IconeDeCategoria(categoria: transacao.categoria, textoAlternativo: titulo, lado: 54)
                    Text(titulo)
                        .font(Tema.fonte(22, .semibold))
                        .foregroundStyle(Tema.tinta)
                        .multilineTextAlignment(.center)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        if transacao.tipo == .receita {
                            Text("+")
                                .font(Tema.fonte(39, .medium))
                                .foregroundStyle(Tema.positivo)
                        }
                        ValorEmEuros(
                            valor: transacao.tipo == .receita ? transacao.valor : -transacao.valor,
                            tamanho: 39,
                            peso: .medium,
                            cor: transacao.tipo == .receita ? Tema.positivo : Tema.tinta
                        )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(valorFormatado)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .cartao()

                // O mesmo padrão de linha do editor, aqui só de leitura.
                VStack(alignment: .leading, spacing: 0) {
                    LinhaDeFormulario(rotulo: "Categoria", simbolo: "square.grid.2x2", mostrarChevron: false) {
                        Text(transacao.categoria?.nome ?? "Sem categoria")
                            .foregroundStyle(transacao.categoria == nil ? Tema.tintaSuave : Tema.tinta)
                    }
                    divisor
                    LinhaDeFormulario(rotulo: "Conta", simbolo: "creditcard", mostrarChevron: false) {
                        Text(nomeDaConta)
                    }
                    divisor
                    LinhaDeFormulario(rotulo: "Data", simbolo: "calendar", mostrarChevron: false) {
                        Text(dataCompleta)
                            .monospacedDigit()
                    }
                    divisor
                    LinhaDeFormulario(rotulo: "Registado por", simbolo: simboloDaOrigem, mostrarChevron: false) {
                        Text(transacao.origem.nome ?? "Manual")
                    }
                    if let nota = transacao.nota, !nota.isEmpty {
                        divisor
                        VStack(alignment: .leading, spacing: 6) {
                            Legenda("Nota")
                            Text(nota)
                                .font(Tema.fonte(14))
                                .foregroundStyle(Tema.tinta)
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartao()

                if transacao.fotoDoTalao != nil {
                    Button {
                        mostrarTalao = true
                    } label: {
                        LinhaDeFormulario(rotulo: "Ver talão original", simbolo: "camera", mostrarChevron: false) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tema.placeholder)
                        }
                        .padding(.horizontal, 18)
                        .cartao()
                    }
                    .buttonStyle(EscalaAoTocar())
                }

                BotaoLume(titulo: "Editar movimento", simbolo: "pencil", estilo: .secundario) { aoEditar() }
                    .padding(.top, 4)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .sheet(isPresented: $mostrarTalao) {
            if let dados = transacao.fotoDoTalao, let imagem = UIImage(data: dados) {
                ScrollView {
                    Image(uiImage: imagem)
                        .resizable()
                        .scaledToFit()
                        .padding(Tema.margemDoEcra)
                }
                .background(Tema.fundo)
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var titulo: String { transacao.loja ?? transacao.descricao }

    /// O ícone da linha Origem acompanha o modo de registo.
    private var simboloDaOrigem: String {
        switch transacao.origem {
        case .talao: "camera"
        case .voz: "mic"
        case .texto: "text.alignleft"
        case .manual: "hand.tap"
        case .applePay: "wallet.pass.fill"
        }
    }

    private var nomeDaConta: String {
        // O nome real ("Revolut"), como no subtítulo das linhas da lista.
        transacao.conta?.nome ?? "—"
    }

    private var legendaDaData: String {
        let dia = transacao.data.formatted(
            .dateTime.day().month(.wide).locale(FormatadorDeMoeda.localidade)
        )
        let hora = transacao.data.formatted(
            .dateTime.hour().minute().locale(FormatadorDeMoeda.localidade)
        )
        return "\(dia) · \(hora)".uppercased()
    }

    private var dataCompleta: String {
        let dia = transacao.data.formatted(
            .dateTime.day().month(.abbreviated).locale(FormatadorDeMoeda.localidade)
        )
        let hora = transacao.data.formatted(
            .dateTime.hour().minute().locale(FormatadorDeMoeda.localidade)
        )
        return "\(dia), \(hora)"
    }

    private var valorFormatado: String {
        let texto = FormatadorDeMoeda.texto(transacao.valor)
        return transacao.tipo == .receita ? "+\(texto)" : "−\(texto)"
    }

    private var divisor: some View {
        Divider().overlay(Tema.separador)
    }
}
