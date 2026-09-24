import Foundation
import Security

/// Segredos no Keychain do aparelho — a chave da API nunca passa
/// por UserDefaults nem aparece em cópias de segurança legíveis.
nonisolated enum CofreDeChaves {
    private static let servico = "com.aurea.lume"

    static let contaClaude = "chave-api-claude"

    /// Guardar texto vazio equivale a apagar.
    static func guardar(_ valor: String, para conta: String) {
        apagar(conta)
        guard !valor.isEmpty, let dados = valor.data(using: .utf8) else { return }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
            kSecValueData as String: dados,
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func ler(_ conta: String) -> String? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let dados = resultado as? Data else { return nil }
        return String(data: dados, encoding: .utf8)
    }

    static func apagar(_ conta: String) {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }
}
