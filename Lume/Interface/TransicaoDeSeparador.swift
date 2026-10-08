import SwiftUI

/// Estrela de quatro pontas com lados côncavos: o brilho das ilustrações.
///
/// Este ficheiro tinha a animação de chegada aos separadores. Foi retirada
/// porque atrasava o conteúdo: agora a troca de separador é instantânea,
/// como nas apps do sistema.
struct Estrela: Shape {
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
