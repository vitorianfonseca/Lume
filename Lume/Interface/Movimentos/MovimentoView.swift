import SwiftUI

/// O detalhe de um movimento — o ecrã 11 do Figma: avatar ao centro,
/// valor em grande, chip da categoria e as linhas Conta/Origem/Data.
struct MovimentoView: View {
    let transacao: Transacao
    let aoEditar: () -> Void
    let aoFechar: () -> Void

    @State private var mostrarTalao = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                CabecalhoDeEcra(legenda: legendaDaData, titulo: "O movimento")

                // O cartão do movimento: avatar 54, nome 22 SemiBold,
                // valor 39 Medium e o chip da categoria.
                VStack(spacing: 12) {
                    AvatarDeIniciais(texto: titulo, lado: 54)
                    Text(titulo)
                        .font(Tema.fonte(22, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text(valorFormatado)
                        .font(Tema.fonte(39, .medium))
                        .monospacedDigit()
                        .foregroundStyle(transacao.tipo == .receita ? Tema.positivo : Tema.tinta)
                    if let categoria = transacao.categoria {
                        Text(categoria.nome)
                            .font(Tema.fonte(12, .semibold))
                            .foregroundStyle(Tema.douradoEscuro)
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Tema.areia, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    linha("Conta", simbolo: "creditcard", valor: nomeDaConta)
                    linha("Origem", simbolo: simboloDaOrigem, valor: transacao.origem.nome ?? "Manual")
                    linha("Data", simbolo: "calendar", valor: dataCompleta)
                    if let nota = transacao.nota, !nota.isEmpty {
                        Divider().overlay(Tema.separador)
                        Text("NOTA")
                            .font(Tema.fonte(10, .semibold))
                            .foregroundStyle(Tema.tintaSuave)
                            .padding(.top, 8)
                        Text(nota)
                            .font(Tema.fonte(14))
                            .foregroundStyle(Tema.tinta)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )

                if transacao.fotoDoTalao != nil {
                    Button {
                        mostrarTalao = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera")
                                .font(Tema.fonte(15))
                                .foregroundStyle(Tema.tintaFosca)
                            Text("Ver talão original")
                                .font(Tema.fonte(14, .medium))
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(Tema.fonte(13))
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        .frame(height: 55)
                    }
                }

                Button("Editar movimento") { aoEditar() }
                    .font(Tema.fonte(13, .medium))
                    .foregroundStyle(Tema.douradoEscuro)

                Button {
                    aoFechar()
                } label: {
                    Text("Voltar aos movimentos")
                        .font(Tema.fonte(15, .semibold))
                        .foregroundStyle(Color(hex: "302B24"))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                }
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
        }
    }

    private var nomeDaConta: String {
        guard let conta = transacao.conta else { return "—" }
        return conta.principal ? "Conta principal" : conta.nome
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

    private func linha(_ titulo: String, simbolo: String, valor: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: simbolo)
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tintaSuave)
                .frame(width: 16)
            Text(titulo)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(valor)
                .font(Tema.fonte(13, .medium))
                .foregroundStyle(Tema.tinta)
        }
        .frame(height: 44)
    }
}
