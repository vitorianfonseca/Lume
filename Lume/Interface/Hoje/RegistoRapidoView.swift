import PhotosUI
import SwiftUI

/// Campo de registo por texto, voz ou talão, sempre visível no ecrã Hoje.
/// Pílula com linha fina, como o "dock" do sistema visual.
struct RegistoRapidoView: View {
    @Bindable var viewModel: HojeViewModel
    let categorias: [Categoria]

    @State private var gravador = GravadorDeVoz()
    @State private var fotoDeTalao: PhotosPickerItem?

    private var textoVazio: Bool {
        viewModel.textoDeRegisto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Gastei…", text: $viewModel.textoDeRegisto)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .submitLabel(.done)
                    .onSubmit { interpretar() }
                    .accessibilityLabel("Registar movimento por texto")

                if viewModel.aInterpretar {
                    ProgressView()
                } else {
                    botaoDeTalao
                    botaoDeVoz
                    botaoDeEnviar
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 9)
            .padding(.vertical, 9)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Raio.campo)
                    .strokeBorder(gravador.aGravar ? Tema.dourado : Tema.separador, lineWidth: 1)
            )
            // Sombra suave do mockup — separa a pílula do fundo branco.
            .shadow(color: .black.opacity(0.06), radius: 14, y: 4)

            if let mensagem = mensagemVisivel {
                Text(mensagem)
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                    .padding(.horizontal, 4)
            }
        }
        // A transcrição vai aparecendo no campo enquanto se fala.
        .onChange(of: gravador.transcricao) {
            guard gravador.aGravar else { return }
            viewModel.textoDeRegisto = gravador.transcricao
        }
        .onChange(of: fotoDeTalao) {
            guard let item = fotoDeTalao else { return }
            fotoDeTalao = nil
            Task {
                guard let dados = try? await item.loadTransferable(type: Data.self) else { return }
                await viewModel.interpretarTalao(dados, categorias: categorias)
            }
        }
    }

    private var mensagemVisivel: String? {
        if case .indisponivel(let motivo) = gravador.estado { return motivo }
        return viewModel.mensagemDeErro
    }

    // MARK: - Botões

    private var botaoDeTalao: some View {
        PhotosPicker(selection: $fotoDeTalao, matching: .images) {
            Image(systemName: "doc.viewfinder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tema.tintaSuave)
                .frame(width: 30, height: 30)
        }
        .accessibilityLabel("Ler um talão da fototeca")
    }

    private var botaoDeVoz: some View {
        Button {
            Task {
                await gravador.alternar()
                // Parou de gravar: interpreta o que ficou no campo.
                if !gravador.aGravar, !textoVazio {
                    await viewModel.interpretar(categorias: categorias, origem: .voz)
                }
            }
        } label: {
            Image(systemName: gravador.aGravar ? "waveform" : "mic")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gravador.aGravar ? Tema.dourado : Tema.tintaSuave)
                .frame(width: 30, height: 30)
                .contentTransition(.symbolEffect(.replace))
                // A onda "respira" enquanto grava.
                .symbolEffect(.variableColor.iterative, isActive: gravador.aGravar)
        }
        .accessibilityLabel(gravador.aGravar ? "Parar e registar o que disseste" : "Ditar despesa")
    }

    private var botaoDeEnviar: some View {
        // Círculo dourado polido (com reflexo) e seta em preto fosco.
        // Sempre dourado — esbatido enquanto não há texto.
        Button(action: interpretar) {
            Image(systemName: "arrow.up")
                .font(.subheadline.weight(.semibold))
                // Preto fosco fixo: sobre o dourado, o contraste
                // tem de se manter também no modo escuro.
                .foregroundStyle(Color(hex: "38342E"))
                .frame(width: 34, height: 34)
                .background(Tema.douradoBotao, in: Circle())
                .opacity(textoVazio ? 0.45 : 1)
        }
        .disabled(textoVazio)
        .accessibilityLabel("Interpretar e registar")
    }

    private func interpretar() {
        if gravador.aGravar { gravador.parar() }
        Task { await viewModel.interpretar(categorias: categorias) }
    }
}
