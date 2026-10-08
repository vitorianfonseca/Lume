import SwiftData
import SwiftUI

/// Os detalhes de uma garantia: até quando vale, o que fazer se for preciso
/// acioná-la, e o talão (se houver), com zoom para ler os valores pequenos.
struct DetalheDaGarantiaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let garantia: Garantia
    @State private var eliminar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: garantia.loja ?? "Garantia",
                    titulo: garantia.produto,
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                resumo

                if garantia.expirada {
                    aviso(
                        titulo: "Garantia expirada",
                        texto: "Já não é possível acionar esta garantia pela via normal.",
                        cor: Tema.negativo,
                        fundo: Tema.fundoNegativo
                    )
                } else if Garantias.aAproximarSeDoFim(dataFim: garantia.dataFim) {
                    aviso(
                        titulo: "Preciso de acionar?",
                        texto: "Contacta a loja ou o fabricante o quanto antes, com o talão e a descrição do problema. Em Portugal tens direito a reparação, substituição, redução do preço ou devolução do dinheiro.",
                        cor: Tema.aviso,
                        fundo: Tema.fundoDoAviso
                    )
                }

                if let prazo = garantia.prazoDeDevolucao {
                    linhaDeData("Prazo de devolução da loja", prazo)
                }

                if let fotoDoTalao = garantia.fotoDoTalao, let imagem = UIImage(data: fotoDoTalao) {
                    VStack(alignment: .leading, spacing: 8) {
                        Legenda("Talão")
                        VisualizadorComZoom(imagem: imagem)
                    }
                }

                Text("Estimativa com base na duração legal mínima (\(RegrasDeGarantia.atuais.duracaoLegalEmMeses) meses) — revisto em \(RegrasDeGarantia.atuais.revistoEm). Confirma sempre as condições junto da loja; isto não é aconselhamento legal.")
                    .font(Tema.fonte(11))
                    .foregroundStyle(Tema.tintaSuave)

                BotaoLume(titulo: "Eliminar garantia", estilo: .destrutivo) { eliminar = true }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Eliminar esta garantia?",
            isPresented: $eliminar,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                contexto.delete(garantia)
                try? contexto.save()
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var resumo: some View {
        VStack(spacing: 0) {
            linhaDoResumo("Valor", FormatadorDeMoeda.texto(garantia.valor))
            Divider().overlay(Tema.separador)
            linhaDoResumo("Comprado a", garantia.dataDaCompra.formatted(.dateTime.day().month(.wide).year().locale(FormatadorDeMoeda.localidade)))
            Divider().overlay(Tema.separador)
            HStack {
                Text("Garantia até")
                    .font(Tema.fonte(14))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                SeloDeGarantia(dataFim: garantia.dataFim)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .cartao()
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

    private func linhaDeData(_ rotulo: String, _ data: Date) -> some View {
        HStack {
            Text(rotulo)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            Text(data.formatted(.dateTime.day().month(.wide).year().locale(FormatadorDeMoeda.localidade)))
                .font(Tema.fonte(13, .semibold))
                .foregroundStyle(Tema.tinta)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cartao()
    }

    private func aviso(titulo: String, texto: String, cor: Color, fundo: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(Tema.fonte(14, .semibold))
                .foregroundStyle(cor)
            Text(texto)
                .font(Tema.fonte(12))
                .foregroundStyle(Tema.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao(fundo)
    }
}

/// A fotografia do talão, com zoom (pinça) e arrasto — para ler valores
/// pequenos sem sair do ecrã.
private struct VisualizadorComZoom: View {
    let imagem: UIImage
    @State private var escala: CGFloat = 1
    @State private var escalaAnterior: CGFloat = 1
    @State private var deslocamento: CGSize = .zero
    @State private var deslocamentoAnterior: CGSize = .zero

    var body: some View {
        Image(uiImage: imagem)
            .resizable()
            .scaledToFit()
            .scaleEffect(escala)
            .offset(deslocamento)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Raio.cartao))
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { valor in
                        escala = max(1, min(escalaAnterior * valor.magnification, 4))
                    }
                    .onEnded { _ in
                        escalaAnterior = escala
                        if escala == 1 { deslocamento = .zero; deslocamentoAnterior = .zero }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { valor in
                        guard escala > 1 else { return }
                        deslocamento = CGSize(
                            width: deslocamentoAnterior.width + valor.translation.width,
                            height: deslocamentoAnterior.height + valor.translation.height
                        )
                    }
                    .onEnded { _ in deslocamentoAnterior = deslocamento }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy(duration: 0.2)) {
                    escala = 1
                    escalaAnterior = 1
                    deslocamento = .zero
                    deslocamentoAnterior = .zero
                }
            }
            .accessibilityLabel("Fotografia do talão")
            .accessibilityHint("Toque duplo para ampliar ou repor o zoom")
    }
}

#Preview {
    let garantia = Garantia(produto: "Máquina de café", loja: "Worten", dataDaCompra: .now, valor: 349, duracaoEmMeses: 24)
    return DetalheDaGarantiaView(garantia: garantia)
        .modelContainer(ContentorDeDados.emMemoria())
}
