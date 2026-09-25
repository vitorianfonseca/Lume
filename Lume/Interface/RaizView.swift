import SwiftData
import SwiftUI
import UIKit

/// Navegação do novo design: Resumo · Movimentos · Registar (+ dourado)
/// · Planear · Perfil. Ícones nunca em preto puro.
struct RaizView: View {
    enum Separador: Hashable {
        case resumo, movimentos, registar, planear, perfil
    }

    @State private var separador = Separador.resumo
    @State private var modoDeRegisto = ModoDeRegisto.texto
    @Environment(\.colorScheme) private var esquema
    @AppStorage("viuBoasVindas") private var viuBoasVindas = false
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]

    /// Muda quando as recorrentes mudam — reagenda as notificações.
    private var assinaturaDasRecorrentes: String {
        recorrentes
            .map { "\($0.nome)|\($0.diaDoMes)|\($0.ativa)|\($0.valor)" }
            .joined(separator: ";")
    }

    init() {
        // O SwiftUI não expõe a cor dos itens não selecionados nem o tamanho
        // dos símbolos na tab bar — configura-se por UIKit.
        let cinza = UIColor { tracos in
            tracos.userInterfaceStyle == .dark
                ? UIColor(red: 0xA9 / 255, green: 0xA4 / 255, blue: 0x9A / 255, alpha: 1)
                : UIColor(red: 0x71 / 255, green: 0x6D / 255, blue: 0x65 / 255, alpha: 1)
        }
        let ouro = UIColor(red: 0xC9 / 255, green: 0xA4 / 255, blue: 0x5A / 255, alpha: 1)

        let aparencia = UITabBarAppearance()
        for disposicao in [
            aparencia.stackedLayoutAppearance,
            aparencia.inlineLayoutAppearance,
            aparencia.compactInlineLayoutAppearance,
        ] {
            disposicao.normal.iconColor = cinza
            disposicao.normal.titleTextAttributes = [.foregroundColor: cinza]
            disposicao.selected.iconColor = ouro
            disposicao.selected.titleTextAttributes = [.foregroundColor: ouro]
        }
        UITabBar.appearance().standardAppearance = aparencia
        UITabBar.appearance().scrollEdgeAppearance = aparencia
    }

    var body: some View {
        TabView(selection: $separador) {
            Tab(value: .resumo) {
                HojeView(
                    aoVerTudo: { separador = .movimentos },
                    aoDefinirRendimento: { separador = .planear },
                    aoRegistar: { modo in
                        modoDeRegisto = modo
                        separador = .registar
                    },
                    aoPlanear: { separador = .planear }
                )
            } label: {
                Label { Text("Resumo") } icon: { simbolo("house", ativo: separador == .resumo) }
            }
            Tab(value: .movimentos) {
                MovimentosView()
            } label: {
                Label { Text("Movimentos") } icon: { simbolo("list.bullet", ativo: separador == .movimentos) }
            }
            Tab(value: .registar) {
                RegistarView(modo: $modoDeRegisto)
            } label: {
                Label { Text("Registar") } icon: { simboloDeRegistar }
            }
            Tab(value: .planear) {
                OrcamentoView()
            } label: {
                Label { Text("Planear") } icon: { simbolo("creditcard", ativo: separador == .planear) }
            }
            Tab(value: .perfil) {
                DefinicoesView()
            } label: {
                Label { Text("Perfil") } icon: { simbolo("person", ativo: separador == .perfil) }
            }
        }
        .tint(Tema.dourado)
        .task(id: assinaturaDasRecorrentes) {
            await NotificadorDeRecorrentes.agendar(recorrentes)
        }
        .fullScreenCover(isPresented: mostrarBoasVindas) {
            BoasVindasView { viuBoasVindas = true }
        }
    }

    private var mostrarBoasVindas: Binding<Bool> {
        Binding(
            get: { !viuBoasVindas },
            set: { if !$0 { viuBoasVindas = true } }
        )
    }

    /// Símbolo mais pequeno com a cor "cozinhada" na imagem — a tab bar
    /// não recolore imagens `.alwaysOriginal`, por isso nunca fica preto.
    private func simbolo(_ nome: String, ativo: Bool) -> Image {
        let configuracao = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let cinza = esquema == .dark
            ? UIColor(red: 0xA9 / 255, green: 0xA4 / 255, blue: 0x9A / 255, alpha: 1)
            : UIColor(red: 0x71 / 255, green: 0x6D / 255, blue: 0x65 / 255, alpha: 1)
        let ouro = UIColor(red: 0xC9 / 255, green: 0xA4 / 255, blue: 0x5A / 255, alpha: 1)
        let imagem = (UIImage(systemName: nome, withConfiguration: configuracao) ?? UIImage())
            .withTintColor(ativo ? ouro : cinza, renderingMode: .alwaysOriginal)
        return Image(uiImage: imagem)
    }

    /// O "+" central do novo design: quadrado dourado claro (#E8CD91),
    /// a cor medida no frame — sempre em destaque.
    private var simboloDeRegistar: Image {
        let configuracao = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let ouro = UIColor(red: 0xE8 / 255, green: 0xCD / 255, blue: 0x91 / 255, alpha: 1)
        let imagem = (UIImage(systemName: "plus.square.fill", withConfiguration: configuracao) ?? UIImage())
            .withTintColor(ouro, renderingMode: .alwaysOriginal)
        return Image(uiImage: imagem)
    }
}

#Preview {
    RaizView()
        .modelContainer(ContentorDeDados.emMemoria())
}
