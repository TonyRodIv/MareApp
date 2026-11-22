# Diretrizes de Design e UI — maré

Este documento consolida os padrões visuais, estruturais e de performance do app **maré** (Flutter / Cupertino), servindo como referência única para novas telas, widgets e revisões.

---

## 1. Superfícies, Cores e Paleta (OKLCH)

- **Superfícies neutras:** fundos (`c.bg`), cartões (`c.card`, `c.cardAlt`), bordas (`c.border`, `c.borderStrong`) e textos (`c.text`, `c.textSecondary`, `c.textTertiary`) usam escala de cinza pura — sem tingimento da cor de destaque.
- **Cor do tema (`c.palette` / `c.primary` / `c.accentWarm`):** reservada para ações principais, estados ativos, badges, anéis de progresso, gráficos e o brilho suave do topo (`GlowBackground`).
- **Motor OKLCH (`lib/core/color_engine.dart`):** toda cor de gráfico ou destaque deve vir de `c.palette` (`c.palette.primary`, `c.palette.companion`) ou ser adaptada com `c.tone(base, min: ...)` e `onColor(bg)` para garantir contraste WCAG em tema claro e escuro. **Nunca** usar tons fixos hardcoded como `Palette.teal*` em gráficos ou legendas.
- **Gráfico de categorias (`CategoryWaffle`, card na Carteira e tela `Por categoria`):** usa escala **monocromática na cor do tema** (`categoryMonochromeColors` em OKLCH, com passos bem espaçados em luminosidade do maior gasto para o menor). Na Carteira destaca as 3 maiores + `Outros` (`c.emptyCell`); ao entrar em `Por categoria`, mantém a mesma escala monocromática no gráfico, nos badges circulares e nas barras de proporção.
- **Ação destrutiva (`BtnKind.danger`):** tom suave e contido — fundo `c.negativeSoft` com borda sutil (`c.negative` a 18–24%) e texto `c.negative`, sem roubar foco da tela.

---

## 1.5. Escala Tipográfica (`T` em `lib/core/theme.dart`)

Fonte única **Poppins**, com numerais tabulares nos tokens numéricos. **Não** sobrescrever `fontSize` avulso nas telas — usar sempre o token semântico:

| Token | Tamanho | Peso | Uso |
|---|---|---|---|
| `T.hero` | `56px` | `w600` | Saldo principal da Carteira (encolhe com `FittedBox`) |
| `T.displayLg` | `40px` | `w600` | Hero monetário (Extrato, Caixinhas, Assinaturas, Detalhe do Gasto, Onboarding) |
| `T.display` | `32px` | `w600` | Destaque numérico médio e títulos heroicos (Ritmo, Editar gasto, Boas-vindas) |
| `T.pageTitle` | `28px` | `w600` | Títulos principais de tela (abas, páginas de detalhe, perguntas de fluxo) |
| `T.title` | `24px` | `w600` | Títulos de sheets e modais |
| `T.cardValue` | `22px` | `w600` | Valores principais dentro de cards e KPIs |
| `T.headline` | `18px` | `w600` | Saudação da Carteira, cabeçalhos internos de sheets (`Detalhes`) |
| `T.body` | `16px` | `w400` | Corpo padrão e `ListRow` com ícone |
| `T.bodyMedium` | `16px` | `w500` | `ListRow` sem ícone (Histórico), valores à direita em listas, `SectionHeader` |
| `T.bodyStrong` | `16px` | `w600` | Ênfase, totais em resumo, texto de `PillButton`, título da barra fixa |
| `T.label` | `14px` | `w400` | Títulos de `AppCard`, rótulos de campo (`FieldLabel`), subtítulos de página |
| `T.labelStrong` | `14px` | `w600` | Abas segmentadas ativas (`Segmented`), chips e ações secundárias |
| `T.small` | `12px` | `w400` | Subtítulos de linha (`ListRow`), datas, legendas de gráfico |
| `T.smallStrong` | `12px` | `w600` | Badges (`Tag`), porcentagens, valores em bolhas, trailing de `SectionHeader` |
| `T.micro` | `11px` | `w500` | Rótulos da navbar flutuante, nomes em `CardChip` e bolhas menores |
| `T.tiny` | `11px` | `w400` | Eixos de gráficos e micro-legendas |

---

## 2. Bordas, Arredondamento e Espaçamento

- **Suavização iOS (Squircle):** todos os cartões, widgets, botões, chips, seletores e modais usam `RoundedSuperellipseBorder` / `ClipRSuperellipse` (exceto quando o widget do framework exige `BoxDecoration`, como `CupertinoTextField`).
- **Padding de 16px em cards e widgets:** todo `AppCard`, `ListGroup` e widget do dashboard usa `EdgeInsets.all(16)` (`Space.base`) em todas as bordas.
- **Grade da Carteira (`DashboardGrid`):** cada linha ocupa 100% da largura disponível sem buracos, respeitando `minHeight` por tipo de card e agrupando na mesma linha apenas cards da mesma classe de altura.

---

## 3. Ícones e Logos

- **Biblioteca única:** `lucide_icons_flutter` em todo o app.
- **Sem quadrados arredondados em ícones:** containers de ícone devem ser sempre **circulares** (`BoxShape.circle`).
- **Três modos conforme o contexto:**
  1. **Itens financeiros / categorias / marcas (`BrandLogo`, `IconBadge`, `_ProgressRing`):** círculo de `40px` com fundo saturado e glifo em branco ou preto (`onColor`), ou logo da marca em círculo branco (`lib/data/brands.dart`) com fallback automático para `IconBadge`.
  2. **Menus e configurações (`ProfileScreen`, `_editGrid`):** ícone Lucide puro **sem fundo** (área de `40px` / `32px`, glifo centralizado).
  3. **Listas analíticas sem ícone (`HistoryScreen`, `Resumo` do Ritmo):** `leading: null` no `ListRow`, exibindo título + subtítulo à esquerda e valor único à direita.

---

## 4. Padrão de Listas (`ListGroup` + `ListRow`)

Componente central em `lib/ui/widgets/kit.dart` (Figma `460:2951`, `460:2995`, `464:3159`):

- **Container único (`ListGroup`):** título acima via `SectionHeader` (opcional), cartão único com fundo `c.card`, cantos `RoundedSuperellipseBorder(28)`, `padding: EdgeInsets.all(16)` e **sem linhas divisórias** — a separação entre itens é feita apenas pelo espaçamento vertical (`gap`, padrão `20px`; `16px–18px` em listas mais densas).
- **Linhas (`ListRow`):**
  - Altura mínima `40px`, largura total.
  - `leading` opcional (circular `40px`, ícone solto ou `null`).
  - `title` + `subtitle` opcional à esquerda (em listas sem ícone, o título ganha destaque `16px` `w500` com `2px` de respiro para o subtítulo).
  - `value` e/ou `trailing` + seta `LucideIcons.arrowUpRight` (`arrow: true`) à direita.
- **Onde se aplica:** Extrato, Caixinhas (lista principal e movimentações), Perfil, Assinaturas, Categorias, Histórico, Resumo do Ritmo, Contas e cartões, Editar grade.

---

## 5. Bottom Sheets e Modais

Todo sheet e modal do app vai **de borda a borda nas laterais e na base** (máximo `640px` centralizado em telas largas), com cantos arredondados apenas no topo (`28px` com `ClipRSuperellipse`) e superfície neutra (`c.card`).

- **Bottom Sheets principais (`showIosSheet` + `SheetBody`):**
  - Usados para detalhes e formulários completos: detalhe do gasto (`ExpenseSheet`), movimentação de caixinha (`editMovement`), conta/cartão (`editCard`, `manageCards`), salário (`editSalary`), perfil (`editProfile`) e editar grade (`_editGrid`).
  - Sobem até logo abaixo da barra de status, recuam e escurecem a tela de trás (`SheetScaler`) no estilo iOS.
  - Botões de ação principais/destrutivos ficam **fixos no rodapé** via `SheetBody(bottom: ...)`.
  - Botão de fechar (`RoundIconButton(LucideIcons.x)`) alinhado no topo direito.
- **Modais compactos (`confirm`, `actionSheet`, `showSheet`):**
  - Usados para confirmações, menus de ação e seletores curtos (cor de destaque, dia de virada, data, categoria).
  - Encostam nas bordas laterais e inferiores com `SafeArea(top: false)` interno e handle de arraste no topo.

---

## 6. Assinaturas (Widget + Tela)

Reconstruído em `lib/ui/widgets/charts.dart` (`SubscriptionBubbles`), `lib/ui/screens/home.dart` (`_subscriptionsCard`) e `lib/ui/screens/insights.dart` (`SubscriptionsScreen`):

- **Bolhas proporcionais (`SubscriptionBubbles`):**
  - Empacotamento circular sem sobreposição proporcional a `√valor`, centralizado automaticamente no container.
  - Cores derivadas da paleta OKLCH ativa (`c.primary`, `c.accentWarm`, `c.palette.primary`, `c.palette.companion`) com contraste garantido por `onColor`.
  - Cada bolha exibe o **logo da marca** em círculo branco (quando reconhecida em `brands.dart`) ou um **ícone contextual do serviço** (música, nuvem, IA, jogos, academia, streaming, criação) — evitando ícones repetidos.
  - Tipografia tabular (`FontFeature.tabularFigures()`) envolvida em `FittedBox(fit: BoxFit.scaleDown)` para nunca cortar valores; bolhas maiores exibem também o nome do serviço.
  - Na tela de detalhe, tocar numa bolha abre direto o `ExpenseSheet` daquela assinatura.
- **Widget na Carteira:** padding `16px`, total mensal animado (`CountingMoney`), subtítulo com quantidade de serviços e custo anual, e bolhas responsivas para largura `1x` (empilhado) ou `2x` (lado a lado).
- **Página de Assinaturas:** botão `+` na barra superior, hero centralizado (custo mensal + anual), card interativo de distribuição, par de KPIs (`Maior serviço` e `Peso no ciclo`) e lista `ListGroup` (`Serviços ativos`) com `ExpenseRow`.

---

## 7. Performance e Animações (Web / Mobile)

- **`SheetScaler` sem travamento:** mantém a estrutura da árvore de widgets constante (sem desmontar/remontar o filho quando `sheetProgress` sai de `0`), cacheia a tela de trás em um `RepaintBoundary` fixo e usa uma única transformação matricial `Matrix4` + recorte de raio constante ativado apenas durante o sheet.
- **Aninhamento seguro:** `_iosSheetStack` acompanha múltiplos `showIosSheet` empilhados (ex.: Contas → Editar conta) sem resetar o recuo de fundo antes do fechamento final.
- **Modais na Web (`kIsWeb`):** evita recompilação por frame de `BackdropFilter` animado no CanvasKit, usando véu escuro suave em 60fps constantes (mantendo blur progressivo no mobile nativo).
