import SwiftUI
import SwiftData
import UIKit

/// Navegação principal: quatro separadores, sem cerimónia.
/// Ícones nunca em preto puro: dourado na seleção, cinzento quente no resto.
struct RaizView: View {
    enum Separador: Hashable {
        case hoje, movimentos, orcamento, definicoes
    }

    @State private var separador = Separador.hoje
    @Environment(\.colorScheme) private var esquema

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
            Tab(value: .hoje) {
                HojeView(
                    aoVerTudo: { separador = .movimentos },
                    aoDefinirRendimento: { separador = .definicoes }
                )
            } label: {
                Label { Text("Hoje") } icon: { simbolo("sun.max", ativo: separador == .hoje) }
            }
            Tab(value: .movimentos) {
                MovimentosView()
            } label: {
                Label { Text("Movimentos") } icon: { simbolo("list.bullet", ativo: separador == .movimentos) }
            }
            Tab(value: .orcamento) {
                OrcamentoView()
            } label: {
                Label { Text("Orçamento") } icon: { simbolo("chart.bar", ativo: separador == .orcamento) }
            }
            Tab(value: .definicoes) {
                DefinicoesView()
            } label: {
                Label { Text("Definições") } icon: { simbolo("gearshape", ativo: separador == .definicoes) }
            }
        }
        .tint(Tema.dourado)
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
}

#Preview {
    RaizView()
        .modelContainer(ContentorDeDados.emMemoria())
}
