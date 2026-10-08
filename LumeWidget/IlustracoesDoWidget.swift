import SwiftUI
import UIKit

// MARK: - Cores do widget

extension Color {
    /// Cor clara/escura: o widget segue o modo do iPhone.
    init(widgetClaro claro: UInt32, escuro: UInt32) {
        self.init(uiColor: UIColor { tracos in
            let hex = tracos.userInterfaceStyle == .dark ? escuro : claro
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// O "Ouro no branco" da app, com o escuro em preto fosco, e as cores
/// pastel das ilustrações.
enum CoresDoWidget {
    static let fundo = Color(widgetClaro: 0xFFFFFF, escuro: 0x1C1C1E)
    static let cartao = Color(widgetClaro: 0xF6F6F4, escuro: 0x2A2A2D)
    static let tinta = Color(widgetClaro: 0x1C1C1E, escuro: 0xF4F4F2)
    static let suave = Color(widgetClaro: 0x76767A, escuro: 0xA6A6AB)
    static let dourado = Color(widgetClaro: 0x8E641F, escuro: 0xE0BF74)
    static let douradoClaro = Color(widgetClaro: 0xE3C47E, escuro: 0xD8B86F)
    static let trilho = Color(widgetClaro: 0xEDEDEB, escuro: 0x3A3A3E)
    static let positivo = Color(widgetClaro: 0x3F7A55, escuro: 0x8FD0A5)
    static let separador = Color(widgetClaro: 0xE8E8E6, escuro: 0x3C3C40)

    // "menta" = no ritmo (verde, celebra o bom comportamento), "céu" = um
    // azul claro de apoio, "pêssego" = acima do ritmo. Tinha unificado estas
    // com o oliva da app na auditoria, mas ela quer o widget com o verde de
    // volta — o widget tem cores próprias, não segue o tema escolhido.
    // De volta ao verde-oliva (não o menta) — a mesma cor do cartão da app.
    static let menta = Color(widgetClaro: 0xE9E7D3, escuro: 0x34352A)
    static let mentaFill = Color(widgetClaro: 0xD9D6BC, escuro: 0x4A4B3A)
    static let ceu = Color(widgetClaro: 0xDFECF8, escuro: 0x2C4058)
    static let ceuFill = Color(widgetClaro: 0xC3DEF5, escuro: 0x3C5C7C)
    static let pessego = Color(widgetClaro: 0xFCE7DA, escuro: 0x4E3A30)
    static let pessegoFill = Color(widgetClaro: 0xF6CFB6, escuro: 0x7A5040)
    static let lavandaFill = Color(widgetClaro: 0xD3CAF3, escuro: 0x564C85)
    static let coral = Color(widgetClaro: 0xEE9E86, escuro: 0xD08670)

    /// O texto de destaque: castanho-bege, como na app (bege claro no escuro).
    static let castanho = Color(widgetClaro: 0x8A6A4C, escuro: 0xD9C2A3)

    /// O dourado das moedas (mais claro no escuro).
    static let ouro = LinearGradient(
        stops: [
            .init(color: Color(widgetClaro: 0x8F4F0F, escuro: 0xD9A450), location: 0.00),
            .init(color: Color(widgetClaro: 0xC78F44, escuro: 0xEDC27A), location: 0.31),
            .init(color: Color(widgetClaro: 0xF9CC81, escuro: 0xFFDDA0), location: 0.44),
            .init(color: Color(widgetClaro: 0xFFF1C2, escuro: 0xFFF4D2), location: 0.51),
            .init(color: Color(widgetClaro: 0xE5AE5D, escuro: 0xF2C57E), location: 0.61),
            .init(color: Color(widgetClaro: 0xA45D14, escuro: 0xD99F4E), location: 0.78),
            .init(color: Color(widgetClaro: 0xF5C873, escuro: 0xFBDB94), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// As barras em bege, como na app.
    /// As barras e a linha do ritmo — creme puxado para o branco, a mesma
    /// cor do centro dos ícones dourados.
    static let ouroDaBarra = LinearGradient(
        colors: [Color(widgetClaro: 0xE9DFCC, escuro: 0xE9DFCC), Color(widgetClaro: 0xF5EFE4, escuro: 0xF5EFE4)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let sombraDoOuro = Color(widgetClaro: 0x6F3906, escuro: 0x000000)
}

// MARK: - Ilustrações

/// As ilustrações do widget: os mesmos renders 3D da app (Assets do
/// widget, "Ilustracao3D-…", sem fundo).
struct IlustracaoDoWidget: View {
    enum Tipo {
        /// Bom ritmo: o frasco de moedas.
        case frasco
        /// Acima do ritmo: as barras.
        case graficos
        /// Sem dados: a carteira.
        case carteira
    }

    let tipo: Tipo

    var body: some View {
        Image(nomeDaImagem)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(3)
            .accessibilityHidden(true)
    }

    private var nomeDaImagem: String {
        switch tipo {
        case .frasco: "Ilustracao3D-frasco"
        case .graficos: "Ilustracao3D-graficos"
        case .carteira: "Ilustracao3D-carteira"
        }
    }
}

/// A moeda dourada das ilustrações.
struct MoedaDoWidget: View {
    let diametro: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [Color(widgetClaro: 0xA97F35, escuro: 0xA97F35), Color(widgetClaro: 0xEAD59B, escuro: 0xEAD59B)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            ))
            Text("€")
                .font(.system(size: diametro * 0.46, weight: .semibold))
                .foregroundStyle(Color(widgetClaro: 0x7A5A22, escuro: 0x7A5A22))
        }
        .frame(width: diametro, height: diametro)
        .overlay(Circle().strokeBorder(Color(widgetClaro: 0x8E641F, escuro: 0x8E641F), lineWidth: 1))
    }
}

/// Estrela de quatro pontas: o brilho das ilustrações.
struct BrilhoDoWidget: View {
    let cor: Color

    var body: some View {
        EstrelaDoWidget().fill(cor)
    }
}

struct EstrelaDoWidget: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var caminho = Path()
        caminho.move(to: CGPoint(x: c.x, y: rect.minY))
        caminho.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y), control: c)
        caminho.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY), control: c)
        caminho.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y), control: c)
        caminho.addQuadCurve(to: CGPoint(x: c.x, y: rect.minY), control: c)
        return caminho
    }
}
