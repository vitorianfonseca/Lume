import SwiftUI
import SwiftData

/// O Planear do Figma (ecrãs 03 e 04): dois segmentos — Orçamentos,
/// com o total do mês e os limites por categoria; e Objetivos, com o
/// total reservado e os planos de poupança.
struct OrcamentoView: View {
    private enum Segmento: String, CaseIterable {
        case orcamentos = "Orçamentos"
        case objetivos = "Objetivos"
    }

    @Environment(\.modelContext) private var contexto
    @Query private var definicoes: [DefinicoesDoMes]
    @Query(sort: \Categoria.ordem) private var categorias: [Categoria]
    @Query private var transacoes: [Transacao]
    @Query(sort: \Meta.nome) private var metas: [Meta]

    @State private var segmento = Segmento.orcamentos
    @State private var mostrarEditarLimites = false
    @State private var mostrarNovoObjetivo = false
    @State private var metaEmEdicao: Meta?
    @State private var metaAReforcar: Meta?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: segmento == .orcamentos
                        ? "MAIS TRANQUILIDADE, TODOS OS DIAS"
                        : "PEQUENOS PASSOS, PLANOS MAIORES",
                    titulo: segmento == .orcamentos ? "Planear" : "Os teus objetivos"
                )
                .animation(.snappy, value: segmento)

                seletorDeSegmento

                switch segmento {
                case .orcamentos: orcamentos
                case .objetivos: objetivos
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .sheet(isPresented: $mostrarEditarLimites) {
            EditarLimitesView(categorias: categorias)
        }
        .sheet(isPresented: $mostrarNovoObjetivo) {
            FormularioDeObjetivo(meta: nil)
        }
        .sheet(item: $metaEmEdicao) { meta in
            FormularioDeObjetivo(meta: meta)
        }
        .sheet(item: $metaAReforcar) { meta in
            ReforcoDeObjetivo(meta: meta)
        }
    }

    private var seletorDeSegmento: some View {
        HStack(spacing: 8) {
            ForEach(Segmento.allCases, id: \.self) { opcao in
                Button {
                    withAnimation(.snappy) { segmento = opcao }
                } label: {
                    Text(opcao.rawValue)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(segmento == opcao ? Tema.tinta : Tema.tintaSuave)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            segmento == opcao ? AnyShapeStyle(Tema.areia) : AnyShapeStyle(.clear),
                            in: Capsule()
                        )
                }
                .accessibilityAddTraits(segmento == opcao ? [.isSelected] : [])
            }
            Spacer()
        }
    }

    // MARK: - Orçamentos (ecrã 03)

    private var rendimentoDoMes: Decimal {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: .now)
        let mes = calendario.component(.month, from: .now)
        return definicoes.first { $0.ano == ano && $0.mes == mes }?.rendimentoEsperado ?? .zero
    }

    private var gastoDoMesTotal: Decimal {
        let calendario = Calendar.current
        return transacoes
            .filter { $0.tipo == .despesa && calendario.isDate($0.data, equalTo: .now, toGranularity: .month) }
            .reduce(.zero) { $0 + $1.valor }
    }

    private var comOrcamento: [Categoria] { categorias.filter { $0.orcamentoMensal != nil } }

    @ViewBuilder
    private var orcamentos: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Date.now.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Button("Editar limites") { mostrarEditarLimites = true }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Tema.douradoEscuro)
            }

            Text(FormatadorDeMoeda.texto(rendimentoDoMes))
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)

            Text(resumoDeUtilizacao)
                .font(.footnote)
                .foregroundStyle(Tema.tintaSuave)
        }

        if comOrcamento.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sem limites definidos")
                    .font(.headline)
                    .foregroundStyle(Tema.tinta)
                Text("Toca em \"Editar limites\" para distribuir o orçamento pelas categorias.")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
            }
            .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(comOrcamento) { categoria in
                    LinhaDeOrcamento(categoria: categoria, gasto: gastoDoMes(em: categoria))
                }
            }
            .padding(.top, 8)
        }
    }

    private var resumoDeUtilizacao: String {
        guard rendimentoDoMes > .zero else {
            return "Define o orçamento do mês em \"Editar limites\"."
        }
        let fracao = (gastoDoMesTotal as NSDecimalNumber).doubleValue
            / (rendimentoDoMes as NSDecimalNumber).doubleValue
        let percentagem = Int((fracao * 100).rounded())
        let disponivel = rendimentoDoMes - gastoDoMesTotal
        return "\(percentagem)% utilizado · \(FormatadorDeMoeda.texto(disponivel)) ainda disponíveis"
    }

    private func gastoDoMes(em categoria: Categoria) -> Decimal {
        let calendario = Calendar.current
        return transacoes
            .filter { transacao in
                transacao.tipo == .despesa
                    && transacao.categoria?.persistentModelID == categoria.persistentModelID
                    && calendario.isDate(transacao.data, equalTo: .now, toGranularity: .month)
            }
            .reduce(.zero) { $0 + $1.valor }
    }

    // MARK: - Objetivos (ecrã 04)

    private var totalReservado: Decimal {
        metas.reduce(.zero) { $0 + $1.valorPoupado }
    }

    @ViewBuilder
    private var objetivos: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JÁ RESERVASTE")
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(Tema.douradoEscuro)
            Text(FormatadorDeMoeda.texto(totalReservado))
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
            Text("reservado para os teus planos · continua assim")
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))

        VStack(alignment: .leading, spacing: 22) {
            ForEach(metas) { meta in
                linhaDeObjetivo(meta)
            }
        }
        .padding(.top, 4)

        Button {
            mostrarNovoObjetivo = true
        } label: {
            Text("Criar novo objetivo")
                .font(.headline)
                .foregroundStyle(Color(hex: "302B24"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
        }
        .padding(.top, 4)
    }

    private func fracao(de meta: Meta) -> Double {
        guard meta.valorAlvo > .zero else { return 0 }
        return (meta.valorPoupado as NSDecimalNumber).doubleValue
            / (meta.valorAlvo as NSDecimalNumber).doubleValue
    }

    private func linhaDeObjetivo(_ meta: Meta) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.nome)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Tema.tinta)
                    if let descricao = meta.descricao, !descricao.isEmpty {
                        Text(descricao)
                            .font(.caption)
                            .foregroundStyle(Tema.tintaSuave)
                    }
                }
                Spacer()
                Image(systemName: meta.simbolo)
                    .font(.footnote)
                    .foregroundStyle(Tema.douradoEscuro)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(FormatadorDeMoeda.texto(meta.valorPoupado))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Text("de \(FormatadorDeMoeda.textoEmEurosInteiros(meta.valorAlvo)) €")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
            }

            BarraDeProgresso(fracao: fracao(de: meta), dourada: true, altura: 4)

            HStack {
                Text("\(Int((fracao(de: meta) * 100).rounded()))% concluído")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                Button("Reforçar objetivo →") { metaAReforcar = meta }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Tema.douradoEscuro)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { metaEmEdicao = meta }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Linha de limite do ecrã 03: nome, "441 / 450 €", barra dourada
/// e "9 € disponíveis" por baixo.
private struct LinhaDeOrcamento: View {
    let categoria: Categoria
    let gasto: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(categoria.nome)
                    .font(.subheadline)
                    .foregroundStyle(Tema.tinta)
                Spacer()
                Text("\(FormatadorDeMoeda.textoEmEurosInteiros(gasto)) / \(FormatadorDeMoeda.textoEmEurosInteiros(orcamento)) €")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Tema.tintaSuave)
            }

            BarraDeProgresso(fracao: fracao, dourada: true, altura: 4)

            Text(legendaDisponivel)
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(categoria.nome): \(FormatadorDeMoeda.texto(gasto)) de \(FormatadorDeMoeda.texto(orcamento))")
    }

    private var orcamento: Decimal { categoria.orcamentoMensal ?? .zero }

    private var fracao: Double {
        guard orcamento > .zero else { return 0 }
        return (gasto as NSDecimalNumber).doubleValue / (orcamento as NSDecimalNumber).doubleValue
    }

    private var legendaDisponivel: String {
        let restante = orcamento - gasto
        guard restante >= .zero else {
            return "\(FormatadorDeMoeda.textoEmEurosInteiros(-restante)) € acima do limite"
        }
        return "\(FormatadorDeMoeda.textoEmEurosInteiros(restante)) € disponíveis"
    }
}

/// O ecrã 12: orçamento mensal em destaque e um campo por categoria.
private struct EditarLimitesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Query private var definicoes: [DefinicoesDoMes]

    let categorias: [Categoria]

    /// 0 = mês atual; recuar 1 para corrigir, avançar até 6 para planear.
    @State private var deslocacaoDeMes = 0

    private var moeda: Decimal.FormatStyle.Currency {
        .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
    }

    private var dataSelecionada: Date {
        Calendar.current.date(byAdding: .month, value: deslocacaoDeMes, to: .now) ?? .now
    }

    private var definicoesDoMes: DefinicoesDoMes? {
        let calendario = Calendar.current
        let ano = calendario.component(.year, from: dataSelecionada)
        let mes = calendario.component(.month, from: dataSelecionada)
        return definicoes.first { $0.ano == ano && $0.mes == mes }
    }

    /// Sem `@Attribute(.unique)` (CloudKit), a unicidade é garantida aqui:
    /// procurar antes de inserir.
    private func garantirDefinicoes() {
        guard definicoesDoMes == nil else { return }
        let calendario = Calendar.current
        contexto.insert(DefinicoesDoMes(
            ano: calendario.component(.year, from: dataSelecionada),
            mes: calendario.component(.month, from: dataSelecionada)
        ))
        try? contexto.save()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: dataSelecionada.formatted(.dateTime.month(.wide).year().locale(FormatadorDeMoeda.localidade)).uppercased(),
                    titulo: "Editar limites"
                )

                // Setas para corrigir o mês anterior ou planear os próximos.
                HStack {
                    Button { deslocacaoDeMes -= 1 } label: { Image(systemName: "chevron.left") }
                        .disabled(deslocacaoDeMes <= -1)
                    Spacer()
                    Text(deslocacaoDeMes == 0 ? "Este mês" : dataSelecionada.formatted(.dateTime.month(.wide).locale(FormatadorDeMoeda.localidade)).capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Tema.tinta)
                    Spacer()
                    Button { deslocacaoDeMes += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(deslocacaoDeMes >= 6)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Tema.douradoEscuro)

                if let selecionadas = definicoesDoMes {
                    cartaoDoOrcamento(selecionadas)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(categorias) { categoria in
                        linhaDeCategoria(categoria)
                        if categoria.persistentModelID != categorias.last?.persistentModelID {
                            Divider().overlay(Tema.separador)
                        }
                    }
                }

                Button {
                    try? contexto.save()
                    dismiss()
                } label: {
                    Text("Guardar limites")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "302B24"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                }

                Text("Os movimentos existentes mantêm-se no teu histórico.")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .onAppear { garantirDefinicoes() }
        .onChange(of: deslocacaoDeMes) { garantirDefinicoes() }
    }

    private func cartaoDoOrcamento(_ selecionadas: DefinicoesDoMes) -> some View {
        @Bindable var selecionadas = selecionadas
        return VStack(alignment: .leading, spacing: 8) {
            Text("ORÇAMENTO MENSAL")
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(Tema.douradoEscuro)
            TextField("0 €", value: $selecionadas.rendimentoEsperado, format: moeda)
                .keyboardType(.decimalPad)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)
            HStack {
                Text("Poupança planeada")
                    .font(.footnote)
                    .foregroundStyle(Tema.tintaSuave)
                Spacer()
                TextField("0 €", value: $selecionadas.poupancaPlaneada, format: moeda)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Tema.tinta)
                    .frame(width: 110)
            }
            Text("Distribui o valor pelas tuas categorias.")
                .font(.caption)
                .foregroundStyle(Tema.tintaSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
    }

    private func linhaDeCategoria(_ categoria: Categoria) -> some View {
        @Bindable var categoria = categoria
        return HStack {
            Text(categoria.nome)
                .font(.subheadline)
                .foregroundStyle(Tema.tinta)
            Spacer()
            TextField(
                "—",
                value: Binding(
                    get: { categoria.orcamentoMensal },
                    set: { categoria.orcamentoMensal = ($0 ?? .zero) > .zero ? $0 : nil }
                ),
                format: moeda
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Tema.tinta)
            .frame(width: 110)
        }
        .padding(.vertical, 10)
    }
}

/// O ecrã 10: criar (ou editar) um objetivo de poupança.
private struct FormularioDeObjetivo: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let meta: Meta?

    @State private var nome: String
    @State private var descricao: String
    @State private var valorAlvo: Decimal
    @State private var valorInicial: Decimal
    @State private var temPrazo: Bool
    @State private var prazo: Date

    init(meta: Meta?) {
        self.meta = meta
        self.nome = meta?.nome ?? ""
        self.descricao = meta?.descricao ?? ""
        self.valorAlvo = meta?.valorAlvo ?? .zero
        self.valorInicial = meta?.valorPoupado ?? .zero
        self.temPrazo = meta?.dataLimite != nil
        self.prazo = meta?.dataLimite
            ?? Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    }

    private var moeda: Decimal.FormatStyle.Currency {
        .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CabecalhoDeEcra(
                    legenda: "DÁ UM DESTINO À TUA POUPANÇA",
                    titulo: meta == nil ? "Um novo objetivo" : "Editar objetivo"
                )

                if meta == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text("O próximo passo começa aqui.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Tema.tinta)
                        } icon: {
                            Image(systemName: "target")
                                .font(.footnote)
                                .foregroundStyle(Tema.douradoEscuro)
                        }
                        Text("Define um valor e uma data. O Lume ajuda-te a acompanhar o caminho.")
                            .font(.caption)
                            .foregroundStyle(Tema.tintaSuave)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Tema.areia, in: RoundedRectangle(cornerRadius: Tema.Raio.cartao))
                }

                campo("NOME DO OBJETIVO") {
                    TextField("Próxima viagem", text: $nome)
                }
                campo("PARA QUE SERVE? (OPCIONAL)") {
                    TextField("Um plano para dezembro", text: $descricao)
                }
                campo("QUANTO QUERES JUNTAR?") {
                    TextField("1 500,00 €", value: $valorAlvo, format: moeda)
                        .keyboardType(.decimalPad)
                }
                campo("ATÉ QUANDO?") {
                    HStack {
                        Toggle("", isOn: $temPrazo)
                            .labelsHidden()
                            .tint(Tema.dourado)
                        if temPrazo {
                            DatePicker("", selection: $prazo, displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, FormatadorDeMoeda.localidade)
                        } else {
                            Text("Sem data definida")
                                .font(.subheadline)
                                .foregroundStyle(Tema.tintaSuave)
                        }
                        Spacer()
                    }
                }
                campo("VALOR INICIAL") {
                    TextField("0,00 €", value: $valorInicial, format: moeda)
                        .keyboardType(.decimalPad)
                }

                Button {
                    guardar()
                } label: {
                    Text(meta == nil ? "Criar objetivo" : "Guardar alterações")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "302B24"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
                }
                .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty || valorAlvo <= .zero)

                Text("Podes alterar o valor ou a data a qualquer momento.")
                    .font(.caption)
                    .foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity)

                if let meta {
                    Button("Eliminar objetivo", role: .destructive) {
                        contexto.delete(meta)
                        try? contexto.save()
                        dismiss()
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Tema.margemDoEcra)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
    }

    private func campo(_ legenda: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(legenda)
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(Tema.tintaSuave)
            conteudo()
                .font(.subheadline)
                .foregroundStyle(Tema.tinta)
            Divider().overlay(Tema.separador)
        }
    }

    private func guardar() {
        if let meta {
            meta.nome = nome
            meta.descricao = descricao.isEmpty ? nil : descricao
            meta.valorAlvo = valorAlvo
            meta.valorPoupado = valorInicial
            meta.dataLimite = temPrazo ? prazo : nil
        } else {
            contexto.insert(Meta(
                nome: nome,
                descricao: descricao.isEmpty ? nil : descricao,
                valorAlvo: valorAlvo,
                valorPoupado: valorInicial,
                dataLimite: temPrazo ? prazo : nil
            ))
        }
        try? contexto.save()
        dismiss()
    }
}

/// Folha pequena para reforçar um objetivo com um valor.
private struct ReforcoDeObjetivo: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss

    let meta: Meta

    @State private var valor = Decimal.zero

    private var moeda: Decimal.FormatStyle.Currency {
        .currency(code: "EUR").locale(FormatadorDeMoeda.localidade)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REFORÇAR OBJETIVO")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(Tema.douradoEscuro)
                Text(meta.nome)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Tema.tinta)
            }

            TextField("0,00 €", value: $valor, format: moeda)
                .keyboardType(.decimalPad)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Tema.tinta)

            Button {
                meta.valorPoupado += valor
                try? contexto.save()
                dismiss()
            } label: {
                Text("Adicionar ao objetivo")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "302B24"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Tema.douradoBotao, in: RoundedRectangle(cornerRadius: Tema.Raio.campo))
            }
            .disabled(valor <= .zero)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tema.margemDoEcra)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.fundo)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    OrcamentoView()
        .modelContainer(ContentorDeDados.emMemoria())
}
