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
                TextField(
                    "Registo",
                    text: $viewModel.textoDeRegisto,
                    prompt: Text("Gastei 12,50 no almoço…").foregroundStyle(Tema.placeholder)
                )
                    .textFieldStyle(.plain)
                    .font(Tema.fonte(16))
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
                    .font(Tema.fonte(13))
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
        gravador.mensagem ?? viewModel.mensagemDeErro
    }

    // MARK: - Botões

    private var botaoDeTalao: some View {
        PhotosPicker(selection: $fotoDeTalao, matching: .images) {
            Image(systemName: "doc.viewfinder")
                .font(Tema.fonte(15, .semibold))
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
                .font(Tema.fonte(15, .semibold))
                .foregroundStyle(gravador.aGravar ? Tema.dourado : Tema.tintaSuave)
                .frame(width: 30, height: 30)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(gravador.aGravar ? "Parar e registar o que disseste" : "Ditar despesa")
    }

    private var botaoDeEnviar: some View {
        // O botão principal da Lume em ponto pequeno: dourado de ação, e o
        // cinzento único dos desativados enquanto não há texto.
        Button(action: interpretar) {
            Image(systemName: "arrow.up")
                .font(Tema.fonte(15, .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(EstiloDeBotaoLume(estilo: .principal))
        .disabled(textoVazio)
        .accessibilityLabel("Interpretar e registar")
    }

    private func interpretar() {
        if gravador.aGravar { gravador.parar() }
        Task { await viewModel.interpretar(categorias: categorias) }
    }
}
