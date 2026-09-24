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
                    .font(.footnote)
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
                .font(.caption2)
                .kerning(1.5)
                .foregroundStyle(Tema.tintaSuave)
            HStack {
                Button("Cancelar") { aoCancelar() }
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
            }
        }
    }

    private var cartao: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Descrição", text: $proposta.descricao)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Tema.tinta)

            // O sinal fica fora do campo: edita-se sempre o valor absoluto.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if proposta.tipo == .despesa {
                    Text("−")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(Tema.tinta)
                }
                TextField(
                    "Valor",
                    value: $proposta.valor,
                    format: .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
                )
                .keyboardType(.decimalPad)
                .font(.system(size: 35, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
            }

            TextField("Loja (opcional)", text: lojaBinding)
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)

            HStack(spacing: 8) {
                Menu {
                    Picker("Categoria", selection: $proposta.nomeDaCategoria) {
                        Text("Sem categoria").tag(String?.none)
                        ForEach(categorias) { categoria in
                            Label(categoria.nome, systemImage: categoria.simbolo)
                                .tag(String?.some(categoria.nome))
                        }
                    }
                } label: {
                    chip(proposta.nomeDaCategoria ?? "Sem categoria", contornoDourado: true)
                }

                Menu {
                    Picker("Tipo", selection: $proposta.tipo) {
                        Text("Despesa").tag(TipoTransacao.despesa)
                        Text("Receita").tag(TipoTransacao.receita)
                    }
                } label: {
                    chip(proposta.tipo == .despesa ? "Despesa" : "Receita")
                }

                DatePicker("", selection: $proposta.data, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                .strokeBorder(Tema.separador, lineWidth: 1)
        )
    }

    private var botaoConfirmar: some View {
        Button {
            aoConfirmar(proposta)
        } label: {
            Text(textoDeConfirmacao)
                .font(.headline)
                .foregroundStyle(Tema.fundo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Tema.tinta, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        }
    }

    /// Chips como no Figma: categoria com contorno dourado fino,
    /// os restantes em cinzento quente discreto.
    private func chip(_ texto: String, contornoDourado: Bool = false) -> some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(Tema.tinta)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                contornoDourado ? AnyShapeStyle(Tema.superficie) : AnyShapeStyle(Tema.tinta.opacity(0.06)),
                in: RoundedRectangle(cornerRadius: Tema.Raio.chip)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Raio.chip)
                    .strokeBorder(contornoDourado ? Tema.dourado.opacity(0.6) : .clear, lineWidth: 1)
            )
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
