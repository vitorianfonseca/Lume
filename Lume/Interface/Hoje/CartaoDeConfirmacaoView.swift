import SwiftUI

/// Cartão editável com os campos interpretados — o "PERCEBIDO" do Figma.
/// É a fronteira entre a IA e os dados: nada é gravado sem o utilizador
/// confirmar aqui. Também serve para editar um movimento existente
/// (título e botão próprios, mais a opção de eliminar).
struct CartaoDeConfirmacaoView: View {
    let categorias: [Categoria]
    let titulo: String
    let textoDeConfirmacao: String
    let aoConfirmar: (PropostaDeTransacao) -> Void
    let aoCancelar: () -> Void
    let aoEliminar: (() -> Void)?

    // Sem valor inicial na declaração: com o @State como macro (SDK 27),
    // o valor é atribuído uma única vez no init.
    @State private var proposta: PropostaDeTransacao

    init(
        proposta: PropostaDeTransacao,
        categorias: [Categoria],
        titulo: String = "PERCEBIDO",
        textoDeConfirmacao: String = "Confirmar",
        aoConfirmar: @escaping (PropostaDeTransacao) -> Void,
        aoCancelar: @escaping () -> Void,
        aoEliminar: (() -> Void)? = nil
    ) {
        self.categorias = categorias
        self.titulo = titulo
        self.textoDeConfirmacao = textoDeConfirmacao
        self.aoConfirmar = aoConfirmar
        self.aoCancelar = aoCancelar
        self.aoEliminar = aoEliminar
        self.proposta = proposta
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            cabecalho
            cartao
            Spacer(minLength: 0)
            botaoConfirmar
            if let aoEliminar {
                Button("Eliminar movimento", role: .destructive) { aoEliminar() }
                    .font(Tema.fonte(13))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.fundo)
        .tint(Tema.tinta)
        .environment(\.locale, FormatadorDeMoeda.localidade)
    }

    private var cabecalho: some View {
        ZStack {
            Text(titulo)
                .font(Tema.fonte(11))
                .foregroundStyle(Tema.tintaSuave)
            HStack {
                Button("Cancelar") { aoCancelar() }
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
            }
        }
    }

    private var cartao: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Descrição", text: $proposta.descricao)
                    .font(Tema.fonte(17, .semibold))
                    .foregroundStyle(Tema.tinta)
                Image(systemName: "creditcard")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.douradoEscuro)
            }

            TextField(
                "Valor",
                value: $proposta.valor,
                format: .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
            )
            .keyboardType(.decimalPad)
            .font(Tema.fonte(34, .semibold))
            .monospacedDigit()
            .foregroundStyle(Tema.tinta)

            TextField("Loja (opcional)", text: lojaBinding)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)

            Divider().overlay(Tema.separador)

            // As mesmas linhas do cartão "Percebido" do frame:
            // ícone + etiqueta à esquerda, controlo à direita.
            linha("Categoria", simbolo: "square.grid.2x2") {
                Picker("Categoria", selection: $proposta.nomeDaCategoria) {
                    Text("Sem categoria").tag(String?.none)
                    ForEach(categorias) { categoria in
                        Text(categoria.nome).tag(String?.some(categoria.nome))
                    }
                }
                .labelsHidden()
                .tint(Tema.tinta)
                .fixedSize()
            }

            linha("Tipo", simbolo: "arrow.up.arrow.down") {
                Picker("Tipo", selection: $proposta.tipo) {
                    Text("Despesa").tag(TipoTransacao.despesa)
                    Text("Receita").tag(TipoTransacao.receita)
                }
                .labelsHidden()
                .tint(Tema.tinta)
                .fixedSize()
            }

            linha("Data", simbolo: "calendar") {
                DatePicker("", selection: $proposta.data, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
    }

    private func linha(
        _ titulo: String,
        simbolo: String,
        @ViewBuilder controlo: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: simbolo)
                .font(Tema.fonte(13))
                .foregroundStyle(Tema.tintaSuave)
            Text(titulo)
                .font(Tema.fonte(15))
                .foregroundStyle(Tema.tintaSuave)
            Spacer()
            controlo()
        }
    }

    private var botaoConfirmar: some View {
        // O botão dourado claro dos frames, com o texto escuro.
        Button {
            aoConfirmar(proposta)
        } label: {
            Text(textoDeConfirmacao)
                .font(Tema.fonte(15, .semibold))
                .foregroundStyle(Color(hex: "302B24"))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        }
    }

    /// `loja` é opcional no modelo; o campo de texto trabalha com "" ↔ nil.
    private var lojaBinding: Binding<String> {
        Binding(
            get: { proposta.loja ?? "" },
            set: { proposta.loja = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    CartaoDeConfirmacaoView(
        proposta: PropostaDeTransacao(
            valor: Decimal(string: "12.50") ?? .zero,
            tipo: .despesa,
            descricao: "Almoço",
            loja: "Time Out Market",
            nomeDaCategoria: "Restauração",
            data: .now
        ),
        categorias: [],
        aoConfirmar: { _ in },
        aoCancelar: {}
    )
}
