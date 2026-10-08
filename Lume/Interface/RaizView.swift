import SwiftData
import SwiftUI
import UIKit

/// Navegação do novo design: Resumo · Movimentos · Registar (+ dourado)
/// · Planear · Perfil. Ícones nunca em preto puro.
struct RaizView: View {
    enum Separador: Hashable {
        case resumo, movimentos, registar, planear, perfil
    }

    // A app abre logo no Registar — é a ação mais provável ao abrir a app.
    @State private var separador = Separador.registar
    @State private var modoDeRegisto = ModoDeRegisto.texto
    @State private var pedidoDeEscuta = 0
    @State private var tecladoVisivel = false
    @State private var abrirRendimento = false
    @AppStorage("viuBoasVindas") private var viuBoasVindas = false
    @Query(sort: \Recorrente.diaDoMes) private var recorrentes: [Recorrente]
    @Query private var garantias: [Garantia]

    // MARK: - Bloqueio com Face ID (Perfil → Privacidade)
    @AppStorage("bloqueioAtivo") private var bloqueioAtivo = false
    @AppStorage("bloqueioApos") private var bloqueioAposRaw = AtrasoDoBloqueio.imediato.rawValue
    /// Guardado (não só em memória) para sobreviver à app ser fechada de
    /// vez em segundo plano: ao reabrir, conta a partir desta hora, não de
    /// "agora", senão nunca voltaria a pedir Face ID depois de reiniciar.
    @AppStorage("ultimaVezAtivo") private var ultimaVezAtivoTimestamp: Double = 0
    @Environment(\.scenePhase) private var faseDeCena
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @AppStorage("codigoDeBloqueioAtivo") private var codigoAtivo = false
    @AppStorage("preferirCodigo") private var preferirCodigo = false
    @State private var autenticado: Bool
    @State private var aAutenticar = false
    @State private var erroDeAutenticacao: String?
    @State private var mostrarTeclado = false
    /// Só um `.background` a sério conta como "saiu da app". O ecrã do
    /// sistema do Face ID/código também passa a app por `.inactive`, e sem
    /// esta marca isso lia-se como "voltou da rua" e voltava a bloquear —
    /// um ciclo sem saída (ela ficou presa fora da própria app por isto).
    @State private var foiParaSegundoPlano = false

    private var atraso: AtrasoDoBloqueio { AtrasoDoBloqueio(rawValue: bloqueioAposRaw) ?? .imediato }

    /// Esconde todo o conteúdo: ou porque a app não está em primeiro plano
    /// (o seletor de apps nunca deve mostrar números), ou porque ainda não
    /// foi confirmada a identidade desde que voltou.
    private var mostrarBloqueio: Bool {
        bloqueioAtivo && (faseDeCena != .active || !autenticado)
    }

    init() {
        let definicoes = UserDefaults.standard
        let ativo = definicoes.bool(forKey: "bloqueioAtivo")
        let atrasoGuardado = AtrasoDoBloqueio(rawValue: definicoes.integer(forKey: "bloqueioApos")) ?? .imediato
        let ultima = Date(timeIntervalSinceReferenceDate: definicoes.double(forKey: "ultimaVezAtivo"))
        let precisaDeAutenticar = ativo
            && TemporizadorDeBloqueio.deveBloquear(desde: ultima, agora: .now, atraso: atrasoGuardado)
        self.autenticado = !precisaDeAutenticar
    }

    /// Muda quando as recorrentes mudam — reagenda as notificações.
    private var assinaturaDasRecorrentes: String {
        recorrentes
            .map { "\($0.nome)|\($0.diaDoMes)|\($0.ativa)|\($0.valor)" }
            .joined(separator: ";")
    }

    /// Muda quando as garantias mudam — reagenda as notificações.
    private var assinaturaDasGarantias: String {
        garantias
            .map { "\($0.id)|\($0.duracaoEmMeses)|\($0.prazoDeDevolucao?.timeIntervalSince1970 ?? 0)" }
            .joined(separator: ";")
    }

    @MainActor
    private func autenticar() async {
        // Preferência por código: nem tenta o Face ID.
        guard !(codigoAtivo && preferirCodigo) else {
            mostrarTeclado = true
            return
        }
        aAutenticar = true
        erroDeAutenticacao = nil
        mostrarTeclado = false
        let resultado = await AutenticadorLocal.autenticar()
        switch resultado {
        case .sucesso:
            // `aAutenticar` muda aqui dentro, na mesma vez que `autenticado`
            // — mudar os dois em separado foi o que deixava a transição de
            // desbloqueio aos solavancos (um corte seguido de um desvanecer).
            desbloquear()
        case .falhou(let mensagem):
            aAutenticar = false
            // Com um código definido, a reserva é o próprio código da Lume,
            // não só tentar o Face ID outra vez.
            guard !codigoAtivo else {
                mostrarTeclado = true
                return
            }
            erroDeAutenticacao = mensagem.isEmpty ? nil : mensagem
        }
    }

    /// Chamado pelo Face ID e pelo código — sempre a mesma saída, com uma
    /// transição suave: a esta altura já está tudo confirmado, não há nada
    /// a esconder, por isso o desvanecer não arrisca mostrar números indevidamente.
    @MainActor
    private func desbloquear() {
        // As três mudanças de estado na mesma transação — era misturar uma
        // instantânea (`aAutenticar`) com uma animada (`autenticado`) que
        // dava o solavanco (um corte seco seguido de um desvanecer a destempo).
        // Só esta direção anima (entrar nunca, para não deixar passar um
        // fotograma do conteúdo por baixo ao bloquear).
        withAnimation(reduzirMovimento ? nil : .easeOut(duration: 0.2)) {
            aAutenticar = false
            mostrarTeclado = false
            autenticado = true
        }
        ultimaVezAtivoTimestamp = Date.now.timeIntervalSinceReferenceDate
    }

    @MainActor
    private func verificarCodigo(_ codigo: String) -> Bool {
        guard let guardado = CofreDeChaves.ler(CofreDeChaves.contaCodigoDeBloqueio), codigo == guardado else {
            return false
        }
        desbloquear()
        return true
    }

    var body: some View {
        // O TabView guarda o estado de cada ecrã; a barra do sistema fica
        // escondida e é substituída pela BarraDeSeparadores. A barra nativa
        // de Liquid Glass ignora a cor do indicador e dá a cada item a
        // largura do texto, o que tirava o "+" do centro.
        TabView(selection: selecao) {
            Tab(value: .resumo) {
                HojeView(
                    aoVerTudo: { irPara(.movimentos) },
                    aoDefinirRendimento: {
                        // O rendimento vive nas definições do Perfil.
                        irPara(.perfil)
                        abrirRendimento = true
                    },
                    aoRegistar: { modo in
                        modoDeRegisto = modo
                        irPara(.registar)
                    },
                    aoPlanear: { irPara(.planear) }
                )
                .modifier(ConteudoDeSeparador())
            }
            Tab(value: .movimentos) {
                MovimentosView()
                    .modifier(ConteudoDeSeparador())
            }
            Tab(value: .registar) {
                RegistarView(modo: $modoDeRegisto, pedidoDeEscuta: pedidoDeEscuta, ativo: separador == .registar)
                    .modifier(ConteudoDeSeparador())
            }
            Tab(value: .planear) {
                OrcamentoView()
                    .modifier(ConteudoDeSeparador())
            }
            Tab(value: .perfil) {
                DefinicoesView(abrirRendimento: $abrirRendimento)
                    .modifier(ConteudoDeSeparador())
            }
        }
        .overlay(alignment: .bottom) {
            // Com o teclado aberto a barra sai de cena, como a nativa, em
            // vez de subir e ficar colada por cima do teclado.
            if !tecladoVisivel {
                BarraDeSeparadores(ativo: separador) { irPara($0) }
                    .ignoresSafeArea(.keyboard)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: tecladoVisivel)
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) {
                tecladoVisivel = true
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) {
                tecladoVisivel = false
            }
        }
        .tint(Tema.dourado)
        .sensoryFeedback(.selection, trigger: separador)
        .task(id: assinaturaDasRecorrentes) {
            await NotificadorDeRecorrentes.agendar(recorrentes)
        }
        .task {
            await NotificadorDoFecho.agendar()
        }
        .task(id: assinaturaDasGarantias) {
            await NotificadorDeGarantias.agendarTodas(garantias)
        }
        .fullScreenCover(isPresented: mostrarBoasVindas) {
            BoasVindasView { viuBoasVindas = true }
        }
        .onOpenURL { abrir($0) }
        // Sem transição: o objetivo é esconder de imediato, uma animação
        // podia deixar passar um fotograma do conteúdo por baixo.
        .overlay {
            if mostrarBloqueio {
                BloqueioView(
                    aAutenticar: aAutenticar,
                    erro: erroDeAutenticacao,
                    mostrarTeclado: mostrarTeclado,
                    autenticar: { Task { await autenticar() } },
                    verificarCodigo: verificarCodigo
                )
                // Só a saída anima (ver `desbloquear()`) — a entrada nunca,
                // para nunca deixar passar um fotograma do conteúdo por baixo.
                .transition(.opacity)
            }
        }
        // No arranque a frio, "mostrarBloqueio" já nasce verdadeiro — sem
        // nenhuma transição de `faseDeCena` para o disparar, por isso pede-se
        // logo aqui, uma vez.
        .task {
            guard bloqueioAtivo, !autenticado, faseDeCena == .active else { return }
            await autenticar()
        }
        .onChange(of: faseDeCena) { _, nova in
            switch nova {
            case .background:
                foiParaSegundoPlano = true
                ultimaVezAtivoTimestamp = Date.now.timeIntervalSinceReferenceDate
            case .active:
                // Sem ter passado por `.background` a sério, ou a meio de um
                // pedido já em curso (o ecrã do sistema a aparecer/desaparecer
                // também passa por aqui) — nunca é motivo para bloquear outra vez.
                guard bloqueioAtivo, foiParaSegundoPlano, !aAutenticar else { break }
                foiParaSegundoPlano = false
                guard TemporizadorDeBloqueio.deveBloquear(
                    desde: Date(timeIntervalSinceReferenceDate: ultimaVezAtivoTimestamp),
                    agora: .now,
                    atraso: atraso
                ) else { break }
                autenticado = false
                Task { await autenticar() }
            default: break
            }
        }
    }

    /// As ligações do widget e do Centro de Controlo: lume://registar/voz,
    /// lume://movimentos, lume://planear, lume://resumo.
    private func abrir(_ url: URL) {
        guard url.scheme == "lume" else { return }
        let destino = url.host() ?? ""
        let detalhe = url.pathComponents.last

        withAnimation(.snappy) {
            switch destino {
            case "registar":
                modoDeRegisto = switch detalhe {
                case "voz": .voz
                case "talao": .talao
                default: .texto
                }
                // "Já a ouvir": chegar por aqui em voz começa a gravar sozinho.
                if detalhe == "voz" { pedidoDeEscuta += 1 }
                irPara(.registar)
            case "movimentos": irPara(.movimentos)
            case "planear": irPara(.planear)
            default: irPara(.resumo)
            }
        }
    }

    private var selecao: Binding<Separador> {
        Binding(
            get: { separador },
            set: { novo in
                irPara(novo)
            }
        )
    }

    private func irPara(_ novo: Separador) {
        separador = novo
    }

    private var mostrarBoasVindas: Binding<Bool> {
        Binding(
            get: { !viuBoasVindas },
            set: { if !$0 { viuBoasVindas = true } }
        )
    }
}

/// O que cada ecrã de separador precisa: esconder a barra do sistema,
/// reservar espaço para a barra própria. A troca é instantânea, como nas
/// apps do sistema: animar a chegada do ecrã inteiro só atrasava o conteúdo.
private struct ConteudoDeSeparador: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarVisibility(.hidden, for: .tabBar)
            // O conteúdo com scroll acaba acima da barra, e não por baixo.
            .safeAreaPadding(.bottom, BarraDeSeparadores.altura)
    }
}

/// A barra de separadores da Lume, opaca, com a sombra dos cartões. Os cinco itens têm
/// a mesma largura, por isso o "+" fica sempre no centro. O separador
/// ativo tem um fundo areia com texto dourado, como os chips selecionados.
private struct BarraDeSeparadores: View {
    /// Altura da cápsula de vidro, sem contar a margem inferior.
    static let altura: CGFloat = 62

    let ativo: RaizView.Separador
    let aoEscolher: (RaizView.Separador) -> Void

    @Namespace private var espacoDoIndicador

    private struct Item {
        let separador: RaizView.Separador
        let titulo: String
        let simbolo: String
    }

    private let itens: [Item] = [
        Item(separador: .resumo, titulo: "Resumo", simbolo: "house"),
        Item(separador: .movimentos, titulo: "Movimentos", simbolo: "list.bullet"),
        Item(separador: .registar, titulo: "Registar", simbolo: "plus.square.fill"),
        Item(separador: .planear, titulo: "Planear", simbolo: "creditcard"),
        Item(separador: .perfil, titulo: "Perfil", simbolo: "person"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(itens, id: \.separador) { item in
                botao(item)
            }
        }
        .padding(5)
        .frame(height: Self.altura)
        // Fundo sólido (sem vidro): o conteúdo não se vê por baixo. Mesmo
        // contorno e sombra dos cartões, para parecer uma peça da app.
        .cartao(raio: Self.altura / 2)
        .padding(.horizontal, 20)
        .animation(.snappy(duration: 0.25), value: ativo)
    }

    private func botao(_ item: Item) -> some View {
        let selecionado = item.separador == ativo
        let eRegistar = item.separador == .registar
        return Button {
            aoEscolher(item.separador)
        } label: {
            // Só o ícone, sem o nome por baixo — ela quis a barra mais limpa.
            Group {
                if eRegistar {
                    // O "+" em ouro polido, render 3D como as ilustrações.
                    Image("BotaoRegistar")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 32, height: 30)
                        .shadow(color: Tema.sombraDoOuro.opacity(0.25), radius: 2, y: 1)
                } else {
                    // O ativo com o dourado do texto; os outros em cinzento.
                    Image(systemName: item.simbolo)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selecionado ? Tema.ouro : AnyShapeStyle(Tema.tintaSuave))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // O indicador areia desliza entre os separadores.
                // Com margem por dentro, para nunca encostar ao rebordo da barra.
                if selecionado {
                    Capsule()
                        .fill(Tema.areia)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 2)
                        .matchedGeometryEffect(id: "indicador", in: espacoDoIndicador)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.titulo)
        .accessibilityAddTraits(selecionado ? [.isSelected] : [])
    }
}

#Preview {
    RaizView()
        .modelContainer(ContentorDeDados.emMemoria())
}

#Preview("Barra de separadores") {
    VStack {
        Spacer()
        BarraDeSeparadores(ativo: .resumo) { _ in }
    }
    .background(Tema.fundo)
}
