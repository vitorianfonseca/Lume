import SwiftData
import SwiftUI

/// Logo depois de registar uma compra grande, a Lume sugere guardar a
/// garantia — já com o produto, a loja e o valor preenchidos. Um toque
/// chega para guardar; "Não precisas" fecha sem criar nada.
struct SugerirGarantiaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let transacao: Transacao

    @State private var produto: String
    @State private var loja: String
    @State private var duracaoEmMeses: Int
    @State private var temPrazoDeDevolucao = false
    @State private var prazoDeDevolucao: Date

    init(transacao: Transacao) {
        self.transacao = transacao
        _produto = State(initialValue: transacao.descricao)
        _loja = State(initialValue: transacao.loja ?? "")
        _duracaoEmMeses = State(initialValue: RegrasDeGarantia.atuais.duracaoLegalEmMeses)
        _prazoDeDevolucao = State(initialValue: Calendar.current.date(byAdding: .day, value: 14, to: transacao.data) ?? transacao.data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CabecalhoDeEcra(
                    legenda: "Compra de \(FormatadorDeMoeda.texto(transacao.valor))",
                    titulo: "Guardar a garantia?",
                    aoVoltar: { dismiss() },
                    simboloDeVoltar: "xmark"
                )

                Text("É uma compra que vale a pena lembrar — a Lume avisa antes de a garantia acabar.")
                    .font(Tema.fonte(13))
                    .foregroundStyle(Tema.tintaSuave)

                campos
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                BotaoLume(titulo: "Guardar garantia", simbolo: "checkmark") { guardar() }
                    .disabled(produto.trimmingCharacters(in: .whitespaces).isEmpty)
                BotaoLume(titulo: "Não precisas", estilo: .texto) { dismiss() }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Tema.fundo)
        }
    }

    private var campos: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Legenda("Produto")
                TextField("Produto", text: $produto)
                    .font(Tema.fonte(16, .medium))
                    .foregroundStyle(Tema.tinta)
            }
            Divider().overlay(Tema.separador)
            VStack(alignment: .leading, spacing: 6) {
                Legenda("Loja")
                TextField("Opcional", text: $loja)
                    .font(Tema.fonte(16))
                    .foregroundStyle(Tema.tinta)
            }
            Divider().overlay(Tema.separador)
            VStack(alignment: .leading, spacing: 6) {
                Legenda("Duração da garantia")
                Stepper(value: $duracaoEmMeses, in: 1...60) {
                    Text("\(duracaoEmMeses) meses")
                        .font(Tema.fonte(16))
                        .foregroundStyle(Tema.tinta)
                }
            }
            Divider().overlay(Tema.separador)
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Tem prazo de devolução", isOn: $temPrazoDeDevolucao)
                    .font(Tema.fonte(14, .medium))
                    .foregroundStyle(Tema.tinta)
                    .tint(Tema.dourado)
                if temPrazoDeDevolucao {
                    DatePicker("Até", selection: $prazoDeDevolucao, displayedComponents: .date)
                        .font(Tema.fonte(14))
                        .foregroundStyle(Tema.tinta)
                        .transition(.opacity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
        .animation(.snappy(duration: 0.2), value: temPrazoDeDevolucao)
    }

    private func guardar() {
        let produtoFinal = produto.trimmingCharacters(in: .whitespacesAndNewlines)
        let lojaFinal = loja.trimmingCharacters(in: .whitespacesAndNewlines)
        let garantia = Garantia(
            produto: produtoFinal,
            loja: lojaFinal.isEmpty ? nil : lojaFinal,
            dataDaCompra: transacao.data,
            valor: transacao.valor,
            duracaoEmMeses: duracaoEmMeses,
            prazoDeDevolucao: temPrazoDeDevolucao ? prazoDeDevolucao : nil,
            fotoDoTalao: transacao.fotoDoTalao
        )
        contexto.insert(garantia)
        try? contexto.save()
        Task { await NotificadorDeGarantias.agendar(garantia) }
        SomDoSistema.sucesso.tocar()
        dismiss()
    }
}

#Preview {
    let contentor = ContentorDeDados.emMemoria()
    let transacao = Transacao(valor: 349, tipo: .despesa, descricao: "Máquina de café", loja: "Worten")
    return SugerirGarantiaView(transacao: transacao)
        .modelContainer(contentor)
}
