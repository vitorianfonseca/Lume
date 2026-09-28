import SwiftUI
import SwiftData

@main
struct LumeApp: App {
    let contentor: ModelContainer

    init() {
        contentor = ContentorDeDados.producao()
        // O widget corre noutro processo: deixa-lhe a fonte da marca.
        PartilhaComWidget.partilharFonte()
        #if DEBUG
        // No simulador em desenvolvimento, semeia dados de exemplo na primeira
        // execução para a app não abrir vazia. Nunca corre em Release.
        DadosDeExemplo.semearSeVazio(em: contentor.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
        }
        .modelContainer(contentor)
    }
}
