import Foundation

/// Formatação monetária em EUR com convenções portuguesas ("1 092,90 €").
nonisolated enum FormatadorDeMoeda {
    static let localidade = Locale(identifier: "pt_PT")

    static func texto(_ valor: Decimal) -> String {
        agrupado(valor.formatted(.currency(code: "EUR").locale(localidade)))
    }

    /// O CLDR do pt-PT só agrupa a partir de 10 000 — mas o design escreve
    /// "1 092,90 €". Insere o espaço fino a cada 3 dígitos da parte inteira.
    private static func agrupado(_ original: String) -> String {
        guard let fim = original.firstIndex(of: ",") else { return original }
        var inicio = fim
        while inicio > original.startIndex,
              original[original.index(before: inicio)].isNumber {
            inicio = original.index(before: inicio)
        }
        let digitos = Array(original[inicio..<fim])
        guard digitos.count > 3 else { return original }
        var resultado = ""
        for (indice, digito) in digitos.enumerated() {
            if indice > 0, (digitos.count - indice) % 3 == 0 {
                resultado.append("\u{00A0}")
            }
            resultado.append(digito)
        }
        return original.replacingCharacters(in: inicio..<fim, with: resultado)
    }

    /// Valor sempre positivo, para frases como "Hoje já passaste 6,20 €".
    static func textoAbsoluto(_ valor: Decimal) -> String {
        texto(valor < .zero ? -valor : valor)
    }

    /// Euros inteiros para pares "121 / 160 €" — o € escreve-se uma vez, no fim.
    static func textoEmEurosInteiros(_ valor: Decimal) -> String {
        "\((valor as NSDecimalNumber).intValue)"
    }

    /// Sem símbolo: inteiro quando não há cêntimos ("441"), senão "142,80".
    static func textoSimples(_ valor: Decimal) -> String {
        let inteiro = Decimal((valor as NSDecimalNumber).intValue)
        guard valor != inteiro else { return textoEmEurosInteiros(valor) }
        return valor.formatted(.number.precision(.fractionLength(2)).locale(localidade))
    }
}
