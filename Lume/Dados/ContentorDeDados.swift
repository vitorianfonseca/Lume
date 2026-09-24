import Foundation
import SwiftData

enum ContentorDeDados {
    static let esquema = Schema([
        Transacao.self,
        Categoria.self,
        Conta.self,
        Meta.self,
        Recorrente.self,
        DefinicoesDoMes.self,
    ])

    /// Contentor de produção. Com `.automatic`, a sincronização iCloud liga-se
    /// assim que a capability de CloudKit for adicionada ao target; até lá,
    /// os dados ficam apenas locais e a app funciona na mesma.
    static func producao() -> ModelContainer {
        do {
            let configuracao = ModelConfiguration(schema: esquema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: esquema, configurations: [configuracao])
        } catch {
            fatalError("Não foi possível criar o contentor de dados: \(error)")
        }
    }

    /// Contentor em memória para Previews e testes, opcionalmente com dados de exemplo.
    @MainActor
    static func emMemoria(comDadosDeExemplo: Bool = true) -> ModelContainer {
        do {
            let configuracao = ModelConfiguration(
                schema: esquema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let contentor = try ModelContainer(for: esquema, configurations: [configuracao])
            if comDadosDeExemplo {
                DadosDeExemplo.semear(em: contentor.mainContext)
            }
            return contentor
        } catch {
            fatalError("Não foi possível criar o contentor em memória: \(error)")
        }
    }
}
