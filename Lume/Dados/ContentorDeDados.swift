import Foundation
import SwiftData

enum ContentorDeDados {
    static let esquema = Schema([
        Transacao.self,
        Categoria.self,
        Conta.self,
        Meta.self,
        ReforcoDaMeta.self,
        Recorrente.self,
        DefinicoesDoMes.self,
        ConsultaDeCompra.self,
        CartaoDaCarteira.self,
        SugestaoDeRecorrenteIgnorada.self,
        Garantia.self,
    ])

    /// Contentor de produção, com três degraus. Numa app de dinheiro, não
    /// abrir é o pior que pode acontecer: se o iCloud recusar o esquema,
    /// abrimos local (os dados continuam lá, só não sincronizam) e, em último
    /// caso, em memória, para a pessoa poder usar a app e nós percebermos
    /// o que falhou em vez de vermos só um crash.
    static func producao() -> ModelContainer {
        do {
            return try ModelContainer(
                for: esquema,
                configurations: [ModelConfiguration(schema: esquema, cloudKitDatabase: .automatic)]
            )
        } catch {
            print("Lume: iCloud indisponível para este esquema (\(error)). A usar armazenamento local.")
        }

        do {
            return try ModelContainer(
                for: esquema,
                configurations: [ModelConfiguration(schema: esquema, cloudKitDatabase: .none)]
            )
        } catch {
            print("Lume: não foi possível abrir o armazenamento local (\(error)). A usar memória.")
        }

        do {
            return try ModelContainer(
                for: esquema,
                configurations: [ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
            )
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
