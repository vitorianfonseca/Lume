import SwiftUI

/// Campo de registo por texto, sempre visível no ecrã Hoje.
/// Pílula com linha fina, como o "dock" do sistema visual.
struct RegistoRapidoView: View {
    @Bindable var viewModel: HojeViewModel
    let categorias: [Categoria]

    private var textoVazio: Bool {
        viewModel.textoDeRegisto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Gastei…", text: $viewModel.textoDeRegisto)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .submitLabel(.done)
                    .onSubmit { interpretar() }
                    .accessibilityLabel("Registar movimento por texto")

                if viewModel.aInterpretar {
                    ProgressView()
                } else {
                    // Círculo dourado polido (com reflexo) e seta em preto fosco.
                    // Sempre dourado — esbatido enquanto não há texto.
                    Button(action: interpretar) {
                        Image(systemName: "arrow.up")
                            .font(.subheadline.weight(.semibold))
                            // Preto fosco fixo: sobre o dourado, o contraste
                            // tem de se manter também no modo escuro.
                            .foregroundStyle(Color(hex: "38342E"))
                            .frame(width: 34, height: 34)
                            .background(Tema.douradoPolido, in: Circle())
                            .opacity(textoVazio ? 0.45 : 1)
                    }
                    .disabled(textoVazio)
                    .accessibilityLabel("Interpretar e registar")
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 9)
            .padding(.vertical, 9)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Raio.campo)
                    .strokeBorder(Tema.separador, lineWidth: 1)
            )
            // Sombra suave do mockup — separa a pílula do fundo branco.
            .shadow(color: .black.opacity(0.06), radius: 14, y: 4)

            if let mensagem = viewModel.mensagemDeErro {
                Text(mensagem)
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func interpretar() {
        Task { await viewModel.interpretar(categorias: categorias) }
    }
}
