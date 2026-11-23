# maré

Aplicativo Flutter de **controle financeiro pessoal por ciclos de salário**, com estética Cupertino minimalista, tema dinâmico no espaço perceptivo OKLCH, sincronização privada no Google Drive e otimização adaptativa para diferentes dispositivos e economia de bateria.

---

## Principais funcionalidades

- **Ciclos de salário configuráveis:** em vez de meses rígidos, o app calcula saldo livre, metas diárias e projeções com base no dia de virada escolhido por você.
- **Carteira modular (`HomeScreen`):** grade personalizável (1x ou 2x, reordenável e ocultável) com cards de resumo:
  - *Seus Gastos* (com curva de tendência translúcida verde/vermelha)
  - *Caixinhas*, *Por categoria* (anel segmentado), *Para hoje*, *Fim de semana*, *Assinaturas*, *Histórico visual*, *Projeção do ciclo* e faixa opcional *Contas*.
- **Extrato e busca instantânea:** visualização por ciclo com gráfico acumulado interativo, filtros por categoria e conta/cartão, busca textual com `Hero` e listas *lazy* (`SliverListGroup`).
- **Caixinhas:** reservas mensais com valor fixo ou percentual do salário, meta opcional com estimativa de prazo, depósitos, gastos diretos da reserva, resgates para o saldo livre e encerramento seguro.
- **Insights dedicados:**
  - *Por categoria* (barra segmentada proporcional + detalhamento por categoria)
  - *Assinaturas* (arco aberto segmentado interativo + atalho **Gerenciar** para principais marcas)
  - *Histórico* (gráfico de linha/área interativo `3M / 6M / 12M` ou barras empilhadas)
  - *Ritmo* (*Hoje* e *Fim de semana* com barra de uso diário, gastos do dia e calendário do ciclo)
- **Importação com IA & Backups:** geração de prompt estruturado para importar gastos em lote ou dados completos a partir de texto/JSON, além de exportação e restauração JSON (incluindo formato legado `finapp_v3`).
- **Google Drive Sync:** backup automático ou manual na pasta oculta `appDataFolder` do Google Drive, com detecção e resolução assistida de conflitos.
- **Personalização completa:** tema Claro/Escuro/Automático, cor de destaque gerada via OKLCH com contraste WCAG garantido, barra de navegação inferior personalizável (2 a 5 abas) e recorte circular de avatar.

---

## Arquitetura do projeto

```text
lib/
├── main.dart                  # Boot paralelo, scopes (PerfScope, StoreScope, SyncScope), launch reveal
├── core/
│   ├── color_engine.dart      # Conversão OKLCH, harmonias, escalas tonais e contraste WCAG
│   ├── cycle.dart             # Lógica de ciclos financeiros (início, fim, virada, labels)
│   ├── money.dart             # Centavos inteiros, formatação pt_BR e parser seguro (MoneyLimits)
│   ├── perf.dart              # DevicePerf: tiers adaptativos (high/balanced/economy) e RAM
│   └── theme.dart             # AppColors memoizado por (seed, brightness, harmony) e tipografia T
├── data/
│   ├── brands.dart            # Reconhecimento de marcas, cores oficiais, ícones Lucide e links Gerenciar
│   ├── drive_sync.dart        # SyncService + Google Drive appDataFolder REST API + resolução de conflitos
│   ├── finance.dart           # Cálculos puros (saldo livre, metas diárias, categorias, assinaturas, caixinhas)
│   ├── models.dart            # Entidades imutáveis/serializáveis (AppData, Expense, Caixinha, PayCard, etc.)
│   ├── store.dart             # Persistência local (SharedPreferences) + mutações atômicas
│   └── validation.dart        # Regras de integridade (limites, datas, saldo de caixinhas e divisões)
└── ui/
    ├── screens/
    │   ├── shell.dart         # Shell principal, abas lazy, FloatingNavBar, FAB acima do blur e predictive back
    │   ├── home.dart          # Carteira modular e editor da grade
    │   ├── extrato.dart       # Extrato do ciclo, gráfico acumulado, filtros e ExtratoSearchScreen
    │   ├── add_expense.dart   # Fluxo guiado de 4 etapas (AddExpenseFlow) + edição direta (ExpenseForm)
    │   ├── expense_sheet.dart # Detalhe do gasto/assinatura com ações rápidas e progresso/custo anual
    │   ├── caixinhas.dart     # Lista de caixinhas, BoxDetail e movimentações
    │   ├── box_form.dart      # Fluxo guiado de criação e edição de caixinha
    │   ├── cards.dart         # Faixa de contas/cartões, CardDetailScreen e formulário com cor do banco
    │   ├── insights.dart      # CategoriesScreen, CategoryDetailScreen, RhythmScreen, SubscriptionsScreen, HistoryScreen
    │   ├── profile.dart       # Seu Perfil, Configurações, Personalização da NavBar e Sobre
    │   ├── sync.dart          # Painel do Google Drive e resolução de conflitos
    │   ├── backup.dart        # Exportação e importação de backups JSON
    │   ├── ai_import.dart     # Assistente de importação via JSON gerado por IA
    │   └── onboarding.dart    # Fluxo inicial de configuração em 8 etapas
    └── widgets/
        ├── avatar_cropper.dart # Recorte circular interativo de foto de perfil
        ├── charts.dart         # Gráficos customizados (HistoryLineChart, CycleExpenseLineChart, MiniDonutRing, etc.)
        ├── dashboard.dart      # Grid responsivo de cards redimensionáveis (1x / 2x)
        ├── kit.dart            # Design system (AppCard, ListGroup, SliverListGroup, ProgressiveBlur, sheets iOS)
        ├── motion.dart         # Molas físicas (SpringBuilder, CountingMoney, SpringSwitch, FluidModalRoute)
        └── nav_keypad.dart     # FloatingNavBar com blur isolado e teclado numérico monetário (Keypad)

shaders/
└── progressive_blur.frag      # Shader GLSL em disco de Vogel + IGN com contagem adaptativa de amostras

android/app/src/main/kotlin/com/mare/mare/
└── MainActivity.kt            # Channels nativos: links externos, capacidades de hardware e Economy Mode ao vivo
```

Para detalhes internos de modelagem, regras financeiras, shader e protocolo de sincronização, consulte [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

---

## Otimização adaptativa e Economia de Bateria

O **maré** monitora em tempo real o estado do dispositivo Android via `MainActivity.kt` + `DevicePerf` (`lib/core/perf.dart`):

| Modo (`PerfTier`) | Condição | Comportamento visual e memória |
|---|---|---|
| **Alto** (`high`) | Hardware moderno com Economia desligada | Shader completo (32 amostras), `BackdropFilter` total e todas as animações |
| **Balanceado** (`balanced`) | RAM ≤ 5,5 GB, ≤ 4 núcleos ou Android < 10 | Shader leve (14 amostras, >2× menos carga na GPU), blur glass a 55% e cache de imagem de 48 MB |
| **Economia** (`economy`) | **Economia de Bateria ativa** (ao vivo), `isLowRamDevice` ou RAM ≤ 3,2 GB | Zero passes de blur na GPU (gradientes limpos), animações decorativas desativadas e cache de imagem de 28 MB |

---

## Desenvolvimento e testes

### Pré-requisitos
- Flutter SDK (`Dart ^3.11.5`)
- Android SDK (para builds Android)

### Comandos úteis

```bash
# Instalar dependências
flutter pub get

# Análise estática
flutter analyze

# Executar todos os testes unitários e de widget (212 testes)
flutter test

# Gerar APK release para Android arm64
flutter build apk --release --target-platform android-arm64
```

> **Instalação preservando dados locais (ADB):**
> ```bash
> adb install -r build/app/outputs/flutter-apk/app-release.apk
> ```

---

## Créditos

Desenvolvido por **Antony Rodrigues**.
