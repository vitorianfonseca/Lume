import SwiftUI

/// Boas-vindas na primeira abertura: três páginas curtas e um "Começar"
/// dourado. Não há login porque não há servidor — a conta é o iCloud.
struct BoasVindasView: View {
    let aoComecar: () -> Void

    @State private var pagina = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pagina) {
                paginaDaMarca.tag(0)
                paginaDoRegisto.tag(1)
                paginaDoNumero.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if pagina < 2 {
                    withAnimation(.snappy) { pagina += 1 }
                } else {
                    aoComecar()
                }
            } label: {
                Text(pagina < 2 ? "Continuar" : "Começar")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "38342E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Tema.douradoPolido, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.bottom, 24)
            .animation(.snappy, value: pagina)
        }
        .background(Tema.fundo)
    }

    private var paginaDaMarca: some View {
        pagina(
            titulo: "Lume",
            texto: "Diz o que gastaste. O resto é connosco."
        ) {
            VStack(spacing: 28) {
                SolDeLume()
                Image("MarcaLume")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 34)
            }
        }
    }

    private var paginaDoRegisto: some View {
        pagina(
            titulo: "Regista como falas",
            texto: "Por texto, voz ou uma foto do talão. A IA só interpreta — as contas são sempre da app."
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Text("Gastei 12,50 no almoço…")
                        .font(.subheadline)
                        .foregroundStyle(Tema.tintaSuave)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "38342E"))
                        .frame(width: 30, height: 30)
                        .background(Tema.douradoPolido, in: Circle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raio.campo)
                        .strokeBorder(Tema.separador, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 14, y: 4)

                HStack(spacing: 24) {
                    Image(systemName: "keyboard")
                    Image(systemName: "mic")
                    Image(systemName: "doc.viewfinder")
                }
                .font(.title3)
                .foregroundStyle(Tema.dourado)
            }
            .padding(.horizontal, 24)
        }
    }

    private var paginaDoNumero: some View {
        pagina(
            titulo: "Um número por dia",
            texto: "Rendimento, menos poupança e contas fixas, dividido pelos dias que faltam. Hoje sabes sempre quanto podes gastar."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hoje podes gastar")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("27")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Tema.tinta)
                    Text(",18 €")
                        .font(.title3)
                        .foregroundStyle(Tema.tintaSuave)
                }
                BarraDeProgresso(fracao: 0.45)
            }
            .padding(24)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Raio.cartao)
                    .strokeBorder(Tema.separador, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
            .padding(.horizontal, 36)
        }
    }

    private func pagina(titulo: String, texto: String, @ViewBuilder ilustracao: () -> some View) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ilustracao()
            VStack(spacing: 10) {
                Text(titulo)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Tema.tinta)
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(Tema.tintaSuave)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    BoasVindasView(aoComecar: {})
}
