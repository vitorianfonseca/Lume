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
            VStack(spacing: 20) {
                CabecalhoDeEcra(legenda: legendaDaData, titulo: "O movimento")

                VStack(spacing: 12) {
                    AvatarDeIniciais(texto: titulo, lado: 56)
                    Text(titulo)
                        .font(Tema.fonte(17, .semibold))
                        .foregroundStyle(Tema.tinta)
                    Text(valorFormatado)
                        .font(Tema.fonte(34, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(transacao.tipo == .receita ? Tema.positivo : Tema.tinta)
                    if let categoria = transacao.categoria {
                        Text(categoria.nome)
                            .font(Tema.fonte(12, .medium))
                            .foregroundStyle(Tema.douradoEscuro)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Tema.areia, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    linha("Conta", simbolo: "creditcard", valor: nomeDaConta)
                    linha("Origem", simbolo: "sparkles", valor: transacao.origem.nome ?? "Manual")
                    linha("Data", simbolo: "calendar", valor: dataCompleta)
                }
                .padding(18)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )

                if let nota = transacao.nota, !nota.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTA")
                            .font(Tema.fonte(11))
                            .foregroundStyle(Tema.tintaSuave)
                        Text(nota)
                            .font(Tema.fonte(15))
                            .foregroundStyle(Tema.tinta)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if transacao.fotoDoTalao != nil {
                    Button {
                        mostrarTalao = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.viewfinder")
                                .font(Tema.fonte(13))
                                .foregroundStyle(Tema.douradoEscuro)
                            Text("Ver talão original")
                                .font(Tema.fonte(15))
                                .foregroundStyle(Tema.tinta)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(Tema.fonte(12))
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        .padding(.vertical, 12)
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
        HStack(spacing: 10) {
            Image(systemName: simbolo)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            Text(titulo)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(valor)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tinta)
        }
    }
}
