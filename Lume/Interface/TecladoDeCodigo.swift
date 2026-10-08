import SwiftUI

/// O teclado numérico de 4 dígitos — para definir e para confirmar o
/// código de bloqueio. Ao chegar a 4 dígitos, verifica sozinho; se estiver
/// errado, treme e limpa (ou só limpa, com "Reduzir movimento").
struct TecladoDeCodigo: View {
    var titulo: String
    /// Devolve verdadeiro se o código está certo.
    var aoCompletar: (String) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var digitos = ""
    @State private var deslocamento: CGFloat = 0
    @State private var erros = 0

    var body: some View {
        VStack(spacing: 28) {
            Text(titulo)
                .font(Tema.fonte(15, .medium))
                .foregroundStyle(Tema.tintaSuave)

            HStack(spacing: 18) {
                ForEach(0..<CodigoDeBloqueio.comprimento, id: \.self) { indice in
                    Circle()
                        .fill(indice < digitos.count ? AnyShapeStyle(Tema.dourado) : AnyShapeStyle(Tema.separador))
                        .frame(width: 14, height: 14)
                }
            }
            .offset(x: deslocamento)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(digitos.count) de \(CodigoDeBloqueio.comprimento) dígitos")

            teclado
        }
        .sensoryFeedback(.error, trigger: erros)
    }

    private var teclado: some View {
        let linhas = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "apagar"]]
        return VStack(spacing: 18) {
            ForEach(linhas, id: \.self) { linha in
                HStack(spacing: 28) {
                    ForEach(linha, id: \.self) { tecla in botao(tecla) }
                }
            }
        }
    }

    @ViewBuilder
    private func botao(_ tecla: String) -> some View {
        if tecla.isEmpty {
            Color.clear.frame(width: 64, height: 64)
        } else if tecla == "apagar" {
            Button {
                guard !digitos.isEmpty else { return }
                digitos.removeLast()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 20))
                    .foregroundStyle(Tema.tinta)
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        } else {
            Button { tocar(tecla) } label: {
                Text(tecla)
                    .font(Tema.fonte(26, .medium))
                    .foregroundStyle(Tema.tinta)
                    .frame(width: 64, height: 64)
                    .background(Tema.bege, in: Circle())
            }
            .buttonStyle(EscalaAoTocar())
        }
    }

    private func tocar(_ tecla: String) {
        guard digitos.count < CodigoDeBloqueio.comprimento else { return }
        digitos.append(tecla)
        guard digitos.count == CodigoDeBloqueio.comprimento else { return }
        guard aoCompletar(digitos) else {
            erros += 1
            guard !reduzirMovimento else {
                digitos = ""
                return
            }
            // 4 repetições × (ida + volta) × 0.05 s = 0,4 s — a mesma conta
            // do atraso a seguir; estavam dessincronizados e a trepidação
            // cortava a meio, com um salto seco em vez de assentar.
            withAnimation(.linear(duration: 0.05).repeatCount(4, autoreverses: true)) {
                deslocamento = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                deslocamento = 0
                digitos = ""
            }
            return
        }
    }
}

#Preview {
    TecladoDeCodigo(titulo: "Introduz o código") { $0 == "1234" }
        .padding()
        .background(Tema.fundo)
}
