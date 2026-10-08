import SwiftUI
import SwiftData
import UserNotifications

@main
struct LumeApp: App {
    let contentor: ModelContainer
    /// O tema escolhido no Perfil. Trocar de tema reconstrói a interface
    /// (pelo `.id`), porque as cores do `Tema` não são observáveis.
    @AppStorage(Paleta.chave) private var paletaEscolhida = Paleta.padrao.id
    @AppStorage(ModoDeAparencia.chave) private var modo = ModoDeAparencia.automatico

    /// Os temas escuros são sempre escuros; os outros seguem o modo escolhido.
    private var esquema: ColorScheme? {
        Paleta.com(id: paletaEscolhida).sempreEscura ? .dark : modo.esquema
    }

    init() {
        contentor = ContentorDeDados.producao()
        // O widget corre noutro processo: deixa-lhe a fonte da marca.
        PartilhaComWidget.partilharFonte()
        UNUserNotificationCenter.current().delegate = GestorDeNotificacoes.partilhado
        NotificadorDePagamentos.registarCategorias()
        #if DEBUG
        // No simulador em desenvolvimento, semeia dados de exemplo na primeira
        // execução para a app não abrir vazia. Nunca corre em Release.
        DadosDeExemplo.semearSeVazio(em: contentor.mainContext)
        // Arrancar com "-dadosDeTeste" troca tudo por dados de teste frescos.
        if CommandLine.arguments.contains("-dadosDeTeste") {
            DadosDeExemplo.recarregar(em: contentor.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .id(paletaEscolhida)
                .preferredColorScheme(esquema)
        }
        .modelContainer(contentor)
    }
}
