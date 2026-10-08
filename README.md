# Lume

**Diz o que gastaste. O resto é connosco.**

Lume é uma app iOS de finanças pessoais. Registas uma despesa numa frase, por voz ou com uma fotografia do talão, e a app mostra-te quanto podes gastar hoje e como vai o mês.

> **A app faz as contas, a IA só interpreta.** O modelo de linguagem nunca calcula totais, saldos nem o número diário. Só transforma texto livre em dados estruturados. Todas as contas são feitas em Swift determinístico e testado, e nada é gravado sem confirmação.

Feita com Swift 6, SwiftUI, SwiftData e Foundation Models, para iOS 27. Sem dependências externas.

---

## Funcionalidades

### Registar
- **Texto:** "gastei 12,50 no almoço", "uber 8€ ontem", "café 80 cêntimos". Valor, loja, categoria e data saem de uma frase.
- **Voz:** reconhecimento de fala em pt-PT, no dispositivo sempre que possível, com transcrição ao vivo.
- **Talão:** a câmara ou a galeria leem a loja, o total e a data com o Vision.
- **Confirmação "Percebido":** um cartão editável mostra o que foi interpretado antes de gravar.
- **Siri e Atalhos:** registar uma despesa sem abrir a app.

### Perceber o mês
- **Resumo:** total gasto face ao orçamento, quanto ainda está disponível e quanto dá por dia.
- **Ritmo do mês:** gráfico do gasto acumulado face a uma referência linear.
- **Limites por categoria:** barras finas, que ficam douradas a partir de 90% do limite.
- **Movimentos:** lista agrupada por dia, com pesquisa, filtros, edição, apagar por swipe e exportação CSV.
- **Tendências:** comparação com o mês passado até ao mesmo dia, a categoria que mais cresce e a média diária dos últimos 7 dias.

### Planear
- **Orçamentos:** rendimento esperado, poupança planeada e limites por categoria, mês a mês.
- **Objetivos:** metas de poupança com progresso e data limite.
- **Contas fixas e subscrições:** descontadas ao mês inteiro e nunca contadas duas vezes, com lembrete na véspera.
- **Segunda opinião:** antes de uma compra, a Lume diz se o preço é razoável e quantos dias do teu ritmo essa compra consome.

### Em todo o lado
- **Widget** em três tamanhos e no ecrã bloqueado, com ações rápidas.
- **Contas e carteiras** como cartões, com saldo calculado a partir dos movimentos.
- **iCloud** para sincronizar entre dispositivos através do CloudKit.
- **Primeiros passos:** um onboarding opcional em oito ecrãs.
- **Acessibilidade:** Dynamic Type, VoiceOver com frases completas e modo escuro.
- **Movimento:** animação na mudança de separador, ilustrações animadas nos estados vazios, e respeito por "Reduzir movimento".

---

## Fases

| Fase | Estado | O que entrou |
| --- | --- | --- |
| **1. Base** | Concluída | Modelos SwiftData preparados para CloudKit, calculadora do dia pura e testada, registo por texto com Foundation Models e alternativa por regras, ecrã Hoje, quatro separadores |
| **2. Captura** | Concluída | Voz, leitura de talão, Claude como interpretador Premium com a chave no Keychain, iCloud |
| **3. Organização** | Concluída | Contas em cartão, objetivos, exportação CSV, lembretes de contas fixas, widget, Siri e Atalhos |
| **4. Design** | Concluída | Os 12 ecrãs e o onboarding do Figma ao pixel, Instrument Sans, tokens medidos, animações e ilustrações |
| **5. Decidir melhor** | Em curso | Segunda opinião antes de comprar, com impacto calculado no ritmo do mês |
| **6. Premium** | Planeada | Plano pago, vigilância de preços, sincronização com o Notion |

---

## Arquitetura

```
Lume/
├── Modelos/        @Model SwiftData, compatíveis com CloudKit
├── Dominio/        lógica pura e nonisolated: calculadora do dia, impacto de compra, formatação
├── Interpretacao/  texto, voz e talão para dados estruturados, atrás de um protocolo
├── Dados/          contentor, dados de exemplo, Keychain, notificações, partilha com o widget
├── Interface/      SwiftUI, um separador por pasta, com o tema e os componentes partilhados
└── Intents/        App Intents para a Siri e os Atalhos
LumeWidget/         WidgetKit
LumeTests/          Swift Testing
```

- **Domínio puro.** A `CalculadoraDoDia` recebe valores e devolve valores, sem SwiftUI nem SwiftData. É por isso que se testa facilmente.
- **Interpretação atrás de um protocolo.** O `InterpretadorDeDespesas` tem implementações com Foundation Models, com regras e com o Claude. A fábrica escolhe conforme a disponibilidade, e se uma falhar entra a seguinte. A interface nunca sabe qual está a usar.
- **Nada de estado derivado guardado.** Saldos e totais são sempre calculados a partir dos movimentos.
- **Dinheiro em `Decimal`**, criado sempre a partir de texto e formatado em pt-PT: `1 092,90 €`.

## Testes

Os testes usam Swift Testing e um calendário fixo em `Europe/Lisbon`. Cobrem o início e o fim do mês, meses de 28, 30 e 31 dias, dias sem gastos, gastos acima do limite, meses sem rendimento, recorrentes que não podem contar duas vezes, a interpretação de frases, a leitura de talões e o mapeamento das respostas dos modelos.

```
⌘U no Xcode
```

## Correr

Abre `Lume.xcodeproj` no Xcode 27 e corre no simulador do iPhone 18 Pro. Em DEBUG, uma base vazia é preenchida com dados de exemplo portugueses. No simulador não há Apple Intelligence, por isso a interpretação usa a alternativa por regras.
