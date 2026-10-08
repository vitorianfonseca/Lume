import SwiftUI

/// Cobre todo o conteúdo quando a Lume está em segundo plano ou bloqueada:
/// nunca os números — é para isto que serve, por isso nunca aparece com
/// animação de entrada (uma transição podia deixar passar um fotograma do
/// que está por baixo). Sair, sim, pode ter uma transição suave: nesse
/// momento já está tudo confirmado. O mesmo tom de marca das boas-vindas.
struct BloqueioView: View {
    /// `true` enquanto se espera a resposta do Face ID — evita mostrar o
    /// botão "Desbloquear" por cima do pedido do sistema, e explica o
    /// pequeno atraso do próprio Face ID com uma palavra, não um vazio.
    let aAutenticar: Bool
    /// Preenchida só depois de uma tentativa falhada (sem código definido).
    let erro: String?
    /// Verdadeiro quando se deve mostrar o teclado do código em vez do
    /// botão do Face ID — por preferência, ou porque o Face ID falhou e
    /// há um código definido como reserva.
    let mostrarTeclado: Bool
    let autenticar: () -> Void
    let verificarCodigo: (String) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Ilustracao(tipo: .cadeado, escala: 1.3)
                    .shadow(color: Tema.dourado.opacity(0.3), radius: 22, y: 10)
                    .accessibilityHidden(true)

                Legenda("Privacidade")

                Text("A tua Lume,\nsó tua.")
                    .font(Tema.fonte(28, .semibold))
                    .foregroundStyle(Tema.tinta)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            VStack(spacing: 14) {
                if mostrarTeclado {
                    TecladoDeCodigo(titulo: "Introduz o código", aoCompletar: verificarCodigo)
                } else if aAutenticar {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("A confirmar…")
                            .font(Tema.fonte(12))
                            .foregroundStyle(Tema.tintaSuave)
                    }
                } else {
                    if let erro, !erro.isEmpty {
                        Text(erro)
                            .font(Tema.fonte(13))
                            .foregroundStyle(Tema.tintaSuave)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    BotaoLume(titulo: "Desbloquear", simbolo: "faceid") { autenticar() }
                        .padding(.horizontal, 48)
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.fundo)
    }
}

#Preview("À espera") {
    BloqueioView(aAutenticar: false, erro: nil, mostrarTeclado: false, autenticar: {}, verificarCodigo: { _ in false })
}

#Preview("A confirmar") {
    BloqueioView(aAutenticar: true, erro: nil, mostrarTeclado: false, autenticar: {}, verificarCodigo: { _ in false })
}

#Preview("Com erro") {
    BloqueioView(aAutenticar: false, erro: "Não foi possível confirmar quem és.", mostrarTeclado: false, autenticar: {}, verificarCodigo: { _ in false })
}

#Preview("Código") {
    BloqueioView(aAutenticar: false, erro: nil, mostrarTeclado: true, autenticar: {}, verificarCodigo: { $0 == "1234" })
}
