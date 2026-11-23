# Arquitetura e Guia Técnico — maré

Este documento detalha os principais módulos, contratos de dados e decisões de engenharia do aplicativo **maré**.

---

## 1. Domínio financeiro e ciclos (`lib/core/`, `lib/data/`)

### Dinheiro em centavos (`money.dart`)
- Todo valor monetário é armazenado e calculado como `int` (`typedef Cents = int`), eliminando erros de ponto flutuante.
- Limite máximo padronizado por `MoneyLimits.maxCents` (`999.999.999` centavos).
- `parseMoney` normaliza espaços (incluindo `\u00A0`), separadores decimais `,` / `.` e formata no padrão `pt_BR` via `fmtMoney`.

### Ciclos salariais (`cycle.dart`)
- Um `Cycle` é identificado por `key = year * 12 + (month - 1)` e definido pelo `cycleStartDay` (1..31, ajustado ao último dia do mês em meses curtos como fevereiro).
- A função `Cycle.of(date, startDay)` garante cobertura contínua sem lacunas nem sobreposições entre ciclos consecutivos.
- Ao alterar o dia de virada (`Store.setCycleStartDay`), `Store` realinha chaves históricas (`SalaryEntry.fromKey`, `Caixinha.createdKey` e `ContributionPlan.fromKey`) para evitar perda de vigência.

### Cálculos puros (`finance.dart`)
- `Finance` é instanciado sob demanda sobre um `AppData` imutável durante o frame (`Store.f`), evitando caches defasados.
- Principais métricas:
  - `salaryFor(cycle)`: último `SalaryEntry` com `fromKey <= cycle.key`.
  - `expensesTotal(cycle)`: soma de gastos únicos do ciclo + recorrentes vigentes (`date` no ciclo ou anterior e `endDate == null || endCycle >= cycle`).
  - `contributionsTotal(cycle)`: soma das contribuições planejadas das caixinhas abertas (`fixed` ou `percent` do salário).
  - `freeBalance(cycle)`: `salaryFor - expensesTotal - contributionsTotal - movimentos manuais impactando saldo livre`.
  - `todayAllowance` / `weekendAllowance`: saldo livre dividido pelos dias restantes do ciclo (incluindo hoje).

### Regras de integridade (`validation.dart` e `store.dart`)
- **Edição de recorrentes:** `Store.updateExpense` só divide um gasto recorrente (encerrando a série antiga no dia anterior ao ciclo atual e criando uma nova a partir do ciclo atual) quando o gasto já estava ativo no ciclo atual e a nova data final é válida; caso contrário, edita no lugar.
- **Movimentações em caixinhas:** `validateMovement` valida saldo negativo tanto em saídas (`sign < 0`) quanto ao reduzir o valor de um depósito existente, verificando o saldo no ciclo da movimentação e no ciclo atual. Caixinhas encerradas (`!box.isOpen`) bloqueiam novas edições/movimentações.

---

## 2. Sincronização e Backup (`drive_sync.dart`, `backup.dart`, `ai_import.dart`)

- **Google Drive (`appDataFolder`):** `SyncService` autentica via `google_sign_in` com escopo `drive.appdata` e lê/grava um único arquivo privado `mare_backup.json`.
- **Segurança de sessão:** `_sessionGen` é incrementado em `disconnect()`, invalidando automaticamente qualquer upload/download em andamento de sessões anteriores.
- **Timestamp e conflitos:** antes do upload é capturado um snapshot de `updatedAt`; em downloads, `_lastSyncedAt` usa o maior timestamp entre relógio local e `remoteUpdatedAt`. Divergências relevantes entre nuvem e aparelho abrem `_ConflictCard` na `SyncScreen` para escolha explícita (*Manter celular* vs. *Usar da nuvem*).
- **Backups e IA:** suporta exportação/importação JSON completa e migração automática do formato legado `finapp_v3`, além de importação via JSON estruturado por IA (`AiImportScreen`).

---

## 3. Tema OKLCH e Design System (`color_engine.dart`, `theme.dart`, `kit.dart`)

- **Motor OKLCH:** `PaletteSet.build(seed, harmony)` gera escalas de 50 a 900 para a cor primária e sua companheira harmônica (evitando colisão com verde/vermelho reservados para positivo/negativo).
- **Contraste WCAG automático:** `ensureContrast` ajusta luminosidade em OKLCH até atingir contraste mínimo (`4.5:1` / `7:1` / `12:1` dependendo do papel do texto) contra todas as superfícies (`bg`, `card`, `cardAlt`).
- **Memoização:** `AppColors.fromSeed` faz cache por `(seed, brightness, harmony)` evitando recálculo a cada notificação do `Store`.
- **Hierarquia visual e Sheets:**
  - `PinnedCupertinoBar` + `CollapsingTitleScope` fazem transição contínua pixel a pixel (0px → 36px de rolagem) tanto do blur quanto do título compacto centralizado.
  - `showIosSheet` (`_IosSheetRoute`) suporta empilhamento com recuo em escala (`1.0 → 0.945`), deslocamento vertical e escurecimento proporcional do sheet inferior, mantendo ícones claros na status bar em modo claro e escuro via `AnnotatedRegion<SystemUiOverlayStyle>`.

---

## 4. Gráficos, Shaders e Performance Adaptativa (`shaders/`, `perf.dart`, `MainActivity.kt`)

### Shader progressivo (`shaders/progressive_blur.frag`)
- Executado em uma única passagem na GPU via `ui.ImageFilter.shader` com amostragem em disco de Vogel rotacionada por *Interleaved Gradient Noise (IGN)*.
- Uniformes passados pelo Dart após `u_size`:
  - `[2]` `u_max_radius` (raio em pixels físicos, crescendo suavemente a partir de `0`)
  - `[3]` `u_direction` (`0.0` topo→baixo, `1.0` baixo→topo)
  - `[4]` `u_band_px` (altura física da faixa)
  - `[5]` `u_samples` (`32.0` no tier `high`, `14.0` no tier `balanced`)
- Em ambientes sem suporte a shader filter, degrada para 8 faixas suaves; no tier `economy`, elimina o `BackdropFilter` completamente e usa gradiente limpo.

### Bridge nativo Android (`MainActivity.kt`)
- `com.mare.mare/links`: abre URLs externas (como LinkedIn na tela *Sobre* e links *Gerenciar* de assinaturas) via `Intent.ACTION_VIEW`.
- `com.mare.mare/device`: expõe `isPowerSaveMode`, `isLowRamDevice`, `totalRamMb`, `cpuCores` e `sdkInt`.
- `com.mare.mare/power_save` (`EventChannel`): escuta `PowerManager.ACTION_POWER_SAVE_MODE_CHANGED` em tempo real para alternar o `DevicePerf` instantaneamente quando a Economia de Bateria é ligada ou desligada.
- `AndroidManifest.xml`: habilita gestos preditivos nativos do Android (`android:enableOnBackInvokedCallback="true"`), integrados às rotas em `shell.dart` (`PredictiveBackPageTransitionsBuilder`) e `PopScope` nos fluxos multi-etapas.

### Logos de marcas (`brands.dart`, `kit.dart`)
- `BrandLogo` resolve domínios e ícones inteligentes em `brands.dart` e carrega favicons 256×256 via Google S2 (`https://www.google.com/s2/favicons?domain=$domain&sz=256`), decodificados no tamanho físico. Exibe a imagem inteira com `BoxFit.contain`, recortada em círculo, usando somente a cor de fundo definida para a marca; se a imagem falhar, mostra o ícone de categoria/nome.
