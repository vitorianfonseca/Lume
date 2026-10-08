import Foundation

/// Formatação monetária em EUR com convenções portuguesas ("1 092,90 €").
nonisolated enum FormatadorDeMoeda {
    static let localidade = Locale(identifier: "pt_PT")

    /// "1 092,90 €" e "−44,05 €": espaço nos milhares e o sinal de menos
    /// tipográfico (nunca o hífen).
    static func texto(_ valor: Decimal) -> String {
        comMenos(agrupado(valor.formatted(.currency(code: "EUR").locale(localidade))))
    }

    /// Troca o hífen do formatador pelo sinal de menos "−".
    static func comMenos(_ texto: String) -> String {
        texto.replacingOccurrences(of: "-", with: "\u{2212}")
    }

    /// Para o VoiceOver: "quinze euros e setenta cêntimos".
    static func falado(_ valor: Decimal) -> String {
        let absoluto = valor < .zero ? -valor : valor
        let euros = (absoluto as NSDecimalNumber).intValue
        let centimos = (((absoluto - Decimal(euros)) * 100) as NSDecimalNumber).intValue
        let extenso = NumberFormatter()
        extenso.numberStyle = .spellOut
        extenso.locale = localidade
        let nomeDosEuros = extenso.string(from: euros as NSNumber) ?? "\(euros)"
        var frase = "\(nomeDosEuros) \(euros == 1 ? "euro" : "euros")"
        if centimos > 0 {
            let nomeDosCentimos = extenso.string(from: centimos as NSNumber) ?? "\(centimos)"
            frase += " e \(nomeDosCentimos) \(centimos == 1 ? "cêntimo" : "cêntimos")"
        }
        return valor < .zero ? "menos \(frase)" : frase
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

    /// Inteiros com milhares agrupados e sem decimais: "2 100".
    static func textoInteiroAgrupado(_ valor: Decimal) -> String {
        let digitos = Array(textoEmEurosInteiros(valor))
        guard digitos.count > 3, digitos.first != "-" else { return comMenos(String(digitos)) }
        var resultado = ""
        for (indice, digito) in digitos.enumerated() {
            if indice > 0, (digitos.count - indice) % 3 == 0 {
                resultado.append("\u{00A0}")
            }
            resultado.append(digito)
        }
        return resultado
    }

    /// Sem símbolo: inteiro quando não há cêntimos ("441"), senão "142,80".
    static func textoSimples(_ valor: Decimal) -> String {
        let inteiro = Decimal((valor as NSDecimalNumber).intValue)
        guard valor != inteiro else { return textoEmEurosInteiros(valor) }
        return valor.formatted(.number.precision(.fractionLength(2)).locale(localidade))
    }
}

/// O formato dos campos de valor: escreve como o resto da app ("1 450,00 €")
/// e aceita o que a pessoa escrever ("1450", "1 450,5", "12.50 €").
nonisolated struct FormatoDeEuros: ParseableFormatStyle {
    var parseStrategy: Estrategia { Estrategia() }

    func format(_ valor: Decimal) -> String {
        FormatadorDeMoeda.texto(valor)
    }

    struct Estrategia: ParseStrategy {
        func parse(_ texto: String) throws -> Decimal {
            let limpo = texto
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{2212}", with: "-")
                .replacingOccurrences(of: ",", with: ".")
            guard !limpo.isEmpty else { return .zero }
            guard let valor = Decimal(string: limpo, locale: Locale(identifier: "en_US_POSIX")) else {
                throw CocoaError(.formatting)
            }
            return valor
        }
    }
}

nonisolated extension FormatStyle where Self == FormatoDeEuros {
    /// `TextField(value:format: .euros)`.
    static var euros: FormatoDeEuros { FormatoDeEuros() }
}
