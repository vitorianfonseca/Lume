import SwiftUI

/// Linhas partilhadas entre o ecrã Hoje e o separador Movimentos.
/// Planas, como no Figma: texto sobre o fundo, sem ícones nem cartões.

struct LinhaDeTransacao: View {
    let transacao: Transacao

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(transacao.descricao)
                    .font(.subheadline)
                    .foregroundStyle(Tema.tinta)
                if let detalhe {
                    Text(detalhe)
                        .font(.footnote)
                        .foregroundStyle(Tema.tintaSuave)
                }
            }

            Spacer()

            Text(valorFormatado)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(transacao.tipo == .receita ? Tema.positivo : Tema.tinta)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// "Supermercado · texto", como no Figma; a loja entra quando não há categoria.
    private var detalhe: String? {
        let partes = [transacao.categoria?.nome ?? transacao.loja, nomeDaOrigem]
            .compactMap { $0 }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    /// Registos manuais não anunciam a origem — é o caso normal.
    private var nomeDaOrigem: String? {
        switch transacao.origem {
        case .manual: nil
        case .texto: "texto"
        case .voz: "voz"
        case .talao: "talão"
        }
    }

    private var valorFormatado: String {
        let texto = FormatadorDeMoeda.texto(transacao.valor)
        return transacao.tipo == .receita ? "+\(texto)" : "−\(texto)"
    }
}

struct LinhaDeRecorrente: View {
    let recorrente: Recorrente
    let data: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(recorrente.nome)
                    .font(.subheadline)
                    .foregroundStyle(Tema.tinta)
                Text(data.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(FormatadorDeMoeda.localidade)))
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }

            Spacer()

            Text(FormatadorDeMoeda.texto(recorrente.valor))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Tema.tintaSuave)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Edição de movimentos

extension PropostaDeTransacao {
    /// Proposta pré-preenchida a partir de um movimento existente,
    /// para o cartão de confirmação servir também de editor.
    init(de transacao: Transacao) {
        self.init(
            valor: transacao.valor,
            tipo: transacao.tipo,
            descricao: transacao.descricao,
            loja: transacao.loja,
            nomeDaCategoria: transacao.categoria?.nome,
            data: transacao.data
        )
    }
}

extension Transacao {
    /// Aplica os campos editados; a categoria é resolvida pelo nome,
    /// como na confirmação original.
    func aplicar(_ proposta: PropostaDeTransacao, categorias: [Categoria]) {
        valor = proposta.valor
        tipo = proposta.tipo
        descricao = proposta.descricao
        loja = proposta.loja
        data = proposta.data
        categoria = categorias.first { $0.nome == proposta.nomeDaCategoria }
    }
}

/// Barra fina do sistema visual: trilho discreto, preenchimento dourado
/// metálico (o único gradiente permitido) ou cinzento quando ainda há folga.
struct BarraDeProgresso: View {
    let fracao: Double
    var dourada = true
    var altura: CGFloat = 6

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.separador)
                Capsule()
                    .fill(dourada ? AnyShapeStyle(Tema.douradoMetalico) : AnyShapeStyle(Tema.tintaSuave.opacity(0.55)))
                    .frame(width: geometria.size.width * min(max(fracao, 0), 1))
            }
        }
        .frame(height: altura)
        .accessibilityHidden(true)
    }
}
